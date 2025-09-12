#!/bin/bash

# Argo CD Installation Script
# This script downloads and installs the latest stable Argo CD manifest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="${SCRIPT_DIR}/argocd-install.yaml"

echo "🚀 Installing Argo CD..."

# Download the latest stable Argo CD installation manifest
echo "📥 Downloading Argo CD installation manifest..."
curl -sSL -o "${MANIFEST_FILE}" \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify the download
if [[ ! -f "${MANIFEST_FILE}" ]] || [[ ! -s "${MANIFEST_FILE}" ]]; then
  echo "❌ Failed to download Argo CD manifest"
  exit 1
fi

echo "✅ Manifest downloaded successfully"

# Install Argo CD
echo "🔧 Installing Argo CD to cluster..."
kubectl apply -f "${MANIFEST_FILE}"

# Wait for Argo CD to be ready
echo "⏳ Waiting for Argo CD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "🎉 Argo CD installation completed!"
echo ""
echo "Next steps:"
echo "1. Get the admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "2. Port forward to access the UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "3. Access Argo CD UI at: https://localhost:8080"
echo "   Username: admin"
echo "   Password: <from step 1>"
