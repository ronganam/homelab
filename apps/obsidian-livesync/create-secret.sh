#!/bin/bash

# Default values
DEFAULT_USER="admin"
NAMESPACE="obsidian-livesync"
SECRET_NAME="obsidian-livesync-secret"

echo "This script will create the '$SECRET_NAME' in the '$NAMESPACE' namespace."

# Prompt for Username
read -p "Enter CouchDB username [${DEFAULT_USER}]: " INPUT_USER
COUCHDB_USER=${INPUT_USER:-$DEFAULT_USER}

# Prompt for Password
while true; do
  read -s -p "Enter CouchDB password: " COUCHDB_PASSWORD
  echo ""
  if [ -n "$COUCHDB_PASSWORD" ]; then
    break
  else
    echo "Password cannot be empty. Please try again."
  fi
done

echo "Creating secret..."
kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-literal=couchdb-user="$COUCHDB_USER" \
  --from-literal=couchdb-password="$COUCHDB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
  echo "Secret '$SECRET_NAME' successfully created/updated in namespace '$NAMESPACE'."
else
  echo "Failed to create secret."
  exit 1
fi
