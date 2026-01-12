#!/bin/bash
kubectl create namespace infisical --dry-run=client -o yaml | kubectl apply -f -

# Generate secrets
ENCRYPTION_KEY=$(openssl rand -hex 16)
AUTH_SECRET=$(openssl rand -base64 32)

# Default passwords from values.yaml (change if you changed them there)
DB_PASSWORD="root"
REDIS_PASSWORD="mysecretpassword"

# Service names based on fullnameOverride in values.yaml
# PostgreSQL: fullnameOverride="postgresql" -> Service: postgresql
# Redis: fullnameOverride="redis" -> Service: redis-master (standard Bitnami standalone)

DB_URI="postgresql://infisical:${DB_PASSWORD}@postgresql.infisical.svc.cluster.local:5432/infisicalDB"
REDIS_URL="redis://:${REDIS_PASSWORD}@redis-master.infisical.svc.cluster.local:6379"
SITE_URL="https://infisical.buildin.group"

kubectl create secret generic infisical-secrets \
  --from-literal=ENCRYPTION_KEY=${ENCRYPTION_KEY} \
  --from-literal=AUTH_SECRET=${AUTH_SECRET} \
  --from-literal=DB_CONNECTION_URI=${DB_URI} \
  --from-literal=REDIS_URL=${REDIS_URL} \
  --from-literal=SITE_URL=${SITE_URL} \
  --namespace infisical \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret infisical-secrets created in namespace infisical"
