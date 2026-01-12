#!/bin/bash
kubectl create namespace infisical --dry-run=client -o yaml | kubectl apply -f -

# Generate random secrets
ENCRYPTION_KEY=$(openssl rand -hex 16)
AUTH_SECRET=$(openssl rand -base64 32)
DB_PASSWORD=$(openssl rand -base64 16)
REDIS_PASSWORD=$(openssl rand -base64 16)

# Service names for top-level dependencies (release-name-chart-name)
# Assuming release name is 'infisical' (based on folder name usually, or Chart name)
# But standard Bitnami charts usually use fullnameOverride if set, or release-name-chart.
# We didn't set fullnameOverride for subcharts in values.yaml.
# Let's verify service names.
# PostgreSQL: infisical-postgresql
# Redis: infisical-redis-master

# Bitnami Postgres 18.x service name: <release>-postgresql
DB_HOST="infisical-postgresql.infisical.svc.cluster.local"
DB_URI="postgresql://infisical:${DB_PASSWORD}@${DB_HOST}:5432/infisicalDB"

# Bitnami Redis 19.x service name: <release>-redis-master
REDIS_HOST="infisical-redis-master.infisical.svc.cluster.local"
REDIS_URL="redis://:${REDIS_PASSWORD}@${REDIS_HOST}:6379"

SITE_URL="https://infisical.buildin.group"

kubectl create secret generic infisical-secrets \
  --from-literal=ENCRYPTION_KEY=${ENCRYPTION_KEY} \
  --from-literal=AUTH_SECRET=${AUTH_SECRET} \
  --from-literal=DB_CONNECTION_URI=${DB_URI} \
  --from-literal=REDIS_URL=${REDIS_URL} \
  --from-literal=SITE_URL=${SITE_URL} \
  --from-literal=postgres-password=${DB_PASSWORD} \
  --from-literal=redis-password=${REDIS_PASSWORD} \
  --namespace infisical \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret infisical-secrets updated with secure passwords and connection strings."