#!/bin/bash

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null;
then
    echo "kubectl could not be found. Please install it to use this script."
    exit 1
fi

NAMESPACE="kan"
SECRET_NAME="kan-secrets"

# Generate random secrets if not provided
PG_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9')
AUTH_SECRET=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
POSTGRES_URL="postgresql://kan:${PG_PASS}@kan-postgres:5432/kan_db"

echo "Generating secrets for Kan..."
echo "PG_PASS: ${PG_PASS}"
echo "AUTH_SECRET: ${AUTH_SECRET}"

# Prompt for other values if needed, or just use defaults/placeholders
# For now, we'll just create the secret with the generated values and empty placeholders for others
# Users can edit the secret later with `kubectl edit secret kan-secrets -n kan`

kubectl create secret generic ${SECRET_NAME} \
    --from-literal=POSTGRES_PASSWORD="${PG_PASS}" \
    --from-literal=BETTER_AUTH_SECRET="${AUTH_SECRET}" \
    --from-literal=POSTGRES_URL="${POSTGRES_URL}" \
    --from-literal=NEXT_PUBLIC_BASE_URL="https://kan.buildin.group" \
    --from-literal=SMTP_HOST="" \
    --from-literal=SMTP_PORT="465" \
    --from-literal=SMTP_USER="" \
    --from-literal=SMTP_PASSWORD="" \
    --from-literal=EMAIL_FROM="" \
    --from-literal=SMTP_SECURE="" \
    --from-literal=SMTP_REJECT_UNAUTHORIZED="" \
    --from-literal=NEXT_PUBLIC_DISABLE_EMAIL="" \
    --from-literal=S3_REGION="" \
    --from-literal=S3_ENDPOINT="" \
    --from-literal=S3_ACCESS_KEY_ID="" \
    --from-literal=S3_SECRET_ACCESS_KEY="" \
    --from-literal=S3_FORCE_PATH_STYLE="" \
    --from-literal=NEXT_PUBLIC_STORAGE_URL="" \
    --from-literal=NEXT_PUBLIC_AVATAR_BUCKET_NAME="" \
    --from-literal=NEXT_PUBLIC_ATTACHMENTS_BUCKET_NAME="" \
    --from-literal=NEXT_PUBLIC_STORAGE_DOMAIN="" \
    --from-literal=NEXT_PUBLIC_ALLOW_CREDENTIALS="" \
    --from-literal=NEXT_PUBLIC_DISABLE_SIGN_UP="" \
    --from-literal=KAN_ADMIN_API_KEY="" \
    --from-literal=TRELLO_APP_API_KEY="" \
    --from-literal=TRELLO_APP_SECRET="" \
    --from-literal=BETTER_AUTH_TRUSTED_ORIGINS="" \
    --from-literal=BETTER_AUTH_ALLOWED_DOMAINS="" \
    --from-literal=GOOGLE_CLIENT_ID="" \
    --from-literal=GOOGLE_CLIENT_SECRET="" \
    --from-literal=DISCORD_CLIENT_ID="" \
    --from-literal=DISCORD_CLIENT_SECRET="" \
    --from-literal=GITHUB_CLIENT_ID="" \
    --from-literal=GITHUB_CLIENT_SECRET="" \
    --namespace ${NAMESPACE} \
    --dry-run=client -o yaml > secret.yaml

echo "Created secret.yaml with generated values."
echo "Please review secret.yaml and add any optional configuration before applying."
