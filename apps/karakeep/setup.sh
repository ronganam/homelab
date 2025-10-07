#!/bin/bash

# Karakeep Setup Script
# This script generates random secrets, prompts for OpenAI API key, and deploys the application

set -e

echo "🚀 Karakeep Setup Script"
echo "========================"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo "❌ openssl is not installed or not in PATH"
    exit 1
fi

# Generate random secrets
echo "🔐 Generating random secrets..."
NEXTAUTH_SECRET=$(openssl rand -base64 36)
MEILI_MASTER_KEY=$(openssl rand -base64 36)

echo "✅ Generated NEXTAUTH_SECRET and MEILI_MASTER_KEY"

# Prompt for OpenAI API key
echo ""
echo "🤖 OpenAI API Key (optional but recommended for AI tagging)"
echo "   Leave empty to skip OpenAI configuration"
read -p "   Enter your OpenAI API key: " OPENAI_API_KEY

# Create temporary configmap file
TEMP_CONFIGMAP="/tmp/karakeep-configmap.yaml"

cat > "$TEMP_CONFIGMAP" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: karakeep-config
  namespace: karakeep
data:
  KARAKEEP_VERSION: "release"
  NEXTAUTH_URL: "http://karakeep.buildin.group"
  MEILI_ADDR: "http://meilisearch:7700"
  BROWSER_WEB_URL: "http://chrome:9222"
  DATA_DIR: "/data"
  MEILI_NO_ANALYTICS: "true"
---
apiVersion: v1
kind: Secret
metadata:
  name: karakeep-secrets
  namespace: karakeep
type: Opaque
stringData:
  NEXTAUTH_SECRET: "$NEXTAUTH_SECRET"
  MEILI_MASTER_KEY: "$MEILI_MASTER_KEY"
EOF

# Add OpenAI API key if provided
if [ ! -z "$OPENAI_API_KEY" ]; then
    cat >> "$TEMP_CONFIGMAP" << EOF
  OPENAI_API_KEY: "$OPENAI_API_KEY"
EOF
    echo "✅ OpenAI API key will be configured"
else
    echo "⚠️  OpenAI API key not provided - AI tagging will be disabled"
fi

# Deploy the application
echo ""
echo "🚀 Deploying Karakeep..."
echo "   This will create the namespace, configmap, secrets, deployments, services, and ingress"

# Apply the temporary configmap first
kubectl apply -f "$TEMP_CONFIGMAP"

# Apply the rest of the resources
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Clean up temporary file
rm -f "$TEMP_CONFIGMAP"

echo ""
echo "✅ Karakeep deployment completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Wait for pods to be ready: kubectl get pods -n karakeep"
echo "   2. Access the application at: http://karakeep.buildin.group"
echo "   3. Check the Homepage dashboard for automatic service discovery"
echo ""
echo "🔍 Useful commands:"
echo "   - Check pod status: kubectl get pods -n karakeep"
echo "   - View logs: kubectl logs -n karakeep -l app=karakeep-web"
echo "   - Delete deployment: kubectl delete -k ."
echo ""
echo "🎉 Setup complete! Happy bookmarking!"
