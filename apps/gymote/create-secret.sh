#!/bin/bash
# Creates/refreshes the GYMote secrets. Run BEFORE the first Argo CD sync.
#
# Existing values are preserved, so re-running never rotates DB passwords or VAPID keys
# (rotating VAPID keys would silently break every existing push subscription).
#
#   gymote-db-credentials  basic-auth  owner role used by CloudNativePG bootstrap
#   gymote-db-superuser    basic-auth  `postgres` superuser (migrations only)
#   gymote-secrets         opaque      runtime env for the api / worker / migrate containers
#
# Optional env when running: SMTP_URL (smtps://user:pass@host), MAIL_FROM, VAPID_SUBJECT.
set -euo pipefail

NAMESPACE="gymote"
IMAGE="${GYMOTE_API_IMAGE:-registry.ganam.app/gymote-api:1.0.0}"   # only used to generate VAPID keys

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

get_key() {  # <secret> <key>  -> value or empty
  kubectl -n "$NAMESPACE" get secret "$1" -o jsonpath="{.data.$2}" 2>/dev/null | base64 -d 2>/dev/null || true
}

OWNER_PW=$(get_key gymote-db-credentials password);   [ -n "$OWNER_PW" ] || OWNER_PW=$(openssl rand -hex 24)
SUPER_PW=$(get_key gymote-db-superuser password);     [ -n "$SUPER_PW" ] || SUPER_PW=$(openssl rand -hex 24)
APP_PW=$(get_key gymote-secrets APP_DB_PASSWORD);     [ -n "$APP_PW" ]   || APP_PW=$(openssl rand -hex 24)

VAPID_PUBLIC_KEY=$(get_key gymote-secrets VAPID_PUBLIC_KEY)
VAPID_PRIVATE_KEY=$(get_key gymote-secrets VAPID_PRIVATE_KEY)
if [ -z "$VAPID_PUBLIC_KEY" ] || [ -z "$VAPID_PRIVATE_KEY" ]; then
  echo "Generating VAPID keys (web push)..."
  KEYS=$(docker run --rm "$IMAGE" node dist/db/vapid.js)
  VAPID_PUBLIC_KEY=$(echo "$KEYS" | sed -n 's/^VAPID_PUBLIC_KEY=//p')
  VAPID_PRIVATE_KEY=$(echo "$KEYS" | sed -n 's/^VAPID_PRIVATE_KEY=//p')
fi
VAPID_SUBJECT="${VAPID_SUBJECT:-$(get_key gymote-secrets VAPID_SUBJECT)}"; VAPID_SUBJECT="${VAPID_SUBJECT:-mailto:admin@ganam.app}"
SMTP_URL="${SMTP_URL:-$(get_key gymote-secrets SMTP_URL)}"
MAIL_FROM="${MAIL_FROM:-$(get_key gymote-secrets MAIL_FROM)}"; MAIL_FROM="${MAIL_FROM:-no-reply@gymote.ganam.app}"

DB_HOST="gymote-db-rw.${NAMESPACE}.svc.cluster.local"   # CloudNativePG read-write Service

kubectl -n "$NAMESPACE" create secret generic gymote-db-credentials --type=kubernetes.io/basic-auth \
  --from-literal=username=gymote --from-literal=password="$OWNER_PW" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NAMESPACE" create secret generic gymote-db-superuser --type=kubernetes.io/basic-auth \
  --from-literal=username=postgres --from-literal=password="$SUPER_PW" --dry-run=client -o yaml | kubectl apply -f -

ARGS=(
  --from-literal=DATABASE_URL="postgres://gymote_app:${APP_PW}@${DB_HOST}:5432/gymote"
  --from-literal=MIGRATE_DATABASE_URL="postgres://postgres:${SUPER_PW}@${DB_HOST}:5432/gymote"
  --from-literal=APP_DB_PASSWORD="$APP_PW"
  --from-literal=VAPID_PUBLIC_KEY="$VAPID_PUBLIC_KEY"
  --from-literal=VAPID_PRIVATE_KEY="$VAPID_PRIVATE_KEY"
  --from-literal=VAPID_SUBJECT="$VAPID_SUBJECT"
  --from-literal=MAIL_FROM="$MAIL_FROM"
)
[ -z "$SMTP_URL" ] || ARGS+=(--from-literal=SMTP_URL="$SMTP_URL")     # unset => emails stay queued in email_outbox
kubectl -n "$NAMESPACE" create secret generic gymote-secrets "${ARGS[@]}" --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets ready in namespace $NAMESPACE."
[ -n "$SMTP_URL" ] || echo "Note: SMTP_URL is not set, so no email is sent (password resets/welcome mails queue up). Re-run with SMTP_URL=... to enable."
