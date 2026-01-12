#!/bin/bash
kubectl create namespace infisical --dry-run=client -o yaml | kubectl apply -f -

# Generate core secrets only
ENCRYPTION_KEY=$(openssl rand -hex 16)
AUTH_SECRET=$(openssl rand -base64 32)
SITE_URL="https://infisical.buildin.group"

kubectl create secret generic infisical-secrets \
  --from-literal=ENCRYPTION_KEY=${ENCRYPTION_KEY} \
  --from-literal=AUTH_SECRET=${AUTH_SECRET} \
  --from-literal=SITE_URL=${SITE_URL} \
  --namespace infisical \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret infisical-secrets created in namespace infisical with core keys."
