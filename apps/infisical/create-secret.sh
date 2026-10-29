#!/bin/bash
# Creates/refreshes the Infisical runtime secret.
#
# Existing keys are preserved so re-running this never rotates ENCRYPTION_KEY
# (which would make previously stored secrets undecryptable).
set -euo pipefail

NAMESPACE="infisical"
SECRET="infisical-secrets"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Read an existing key, empty string if absent.
get_key() {
  kubectl -n "$NAMESPACE" get secret "$SECRET" -o jsonpath="{.data.$1}" 2>/dev/null \
    | base64 -d 2>/dev/null || true
}

ENCRYPTION_KEY=$(get_key ENCRYPTION_KEY)
[ -n "$ENCRYPTION_KEY" ] || ENCRYPTION_KEY=$(openssl rand -hex 16)

AUTH_SECRET=$(get_key AUTH_SECRET)
[ -n "$AUTH_SECRET" ] || AUTH_SECRET=$(openssl rand -base64 32)

DB_PASSWORD=$(get_key postgres-password)
[ -n "$DB_PASSWORD" ] || DB_PASSWORD=$(openssl rand -base64 16)

REDIS_PASSWORD=$(get_key redis-password)
[ -n "$REDIS_PASSWORD" ] || REDIS_PASSWORD=$(openssl rand -base64 16)

# CloudNativePG exposes the read-write Service as <cluster>-rw.
DB_HOST="infisical-db-rw.${NAMESPACE}.svc.cluster.local"
DB_URI="postgresql://infisical:${DB_PASSWORD}@${DB_HOST}:5432/infisicalDB"

# Valkey cache, rendered by the app-blueprint `cache` block.
REDIS_HOST="infisical-cache.${NAMESPACE}.svc.cluster.local"
REDIS_URL="redis://:${REDIS_PASSWORD}@${REDIS_HOST}:6379"

SITE_URL="https://infisical.ganam.app"

kubectl create secret generic "$SECRET" \
  --from-literal=ENCRYPTION_KEY="${ENCRYPTION_KEY}" \
  --from-literal=AUTH_SECRET="${AUTH_SECRET}" \
  --from-literal=DB_CONNECTION_URI="${DB_URI}" \
  --from-literal=REDIS_URL="${REDIS_URL}" \
  --from-literal=SITE_URL="${SITE_URL}" \
  --from-literal=postgres-password="${DB_PASSWORD}" \
  --from-literal=redis-password="${REDIS_PASSWORD}" \
  --from-literal=username="infisical" \
  --from-literal=password="${DB_PASSWORD}" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret ${NAMESPACE}/${SECRET} applied (existing keys preserved)."
