#!/bin/bash

# Argo CD Installation Script (Kustomize-based, pinned version)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Installing Argo CD via kustomize (infra/argocd)..."

# Apply kustomization (includes namespace, pinned Argo CD version, ingress, and patches)
kubectl apply --server-side --force-conflicts -k "${REPO_ROOT}/infra/argocd"

echo "⏳ Waiting for Argo CD to be ready..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "📦 Applying root ApplicationSets (project + apps/infra) ..."
kubectl apply -f "${REPO_ROOT}/bootstrap/root-applicationsets.yaml"

echo "🎉 Argo CD installation completed and ApplicationSets applied!"
echo ""
echo "Next steps:"
echo "1. Get the admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"
echo ""
echo "2. Access Argo CD UI via ingress:"
echo "   https://argo.ganam.app/ (or https://argocd.ganam.app/)"
echo "   Username: admin"
echo "   Password: <from step 1>"
echo ""
echo "Note: Auto-Sync can be toggled per app in the UI/CLI and will persist."
