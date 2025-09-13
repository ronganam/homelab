#!/bin/bash

# Simple Cloudflare Setup Script for External-DNS
# This script creates the necessary Kubernetes resources for External-DNS

set -e

echo "🚀 Cloudflare Setup for External-DNS"
echo "===================================="
echo ""

# Get domain from user
read -p "Enter your domain (e.g., buildin.group): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain is required"
    exit 1
fi

# Get Cloudflare Zone ID
echo "🔍 Please enter your Cloudflare Zone ID for $DOMAIN:"
echo "You can find it in your Cloudflare dashboard under the domain overview"
read -p "Zone ID: " ZONE_ID

if [ -z "$ZONE_ID" ]; then
    echo "❌ Zone ID is required"
    exit 1
fi

# Get Cloudflare API Token
echo "🔑 Please create a Cloudflare API Token:"
echo "1. Go to https://dash.cloudflare.com/profile/api-tokens"
echo "2. Create a custom token with:"
echo "   - Zone:Zone:Read permissions"
echo "   - Zone:DNS:Edit permissions"
echo "   - Include: All zones (or just $DOMAIN)"
echo ""
read -p "Enter your Cloudflare API Token: " API_TOKEN

if [ -z "$API_TOKEN" ]; then
    echo "❌ API Token is required"
    exit 1
fi

# Create the secret
echo "🔐 Creating Kubernetes secret..."
kubectl create secret generic cloudflare-api-token \
  --namespace=external-dns \
  --from-literal=api-token="$API_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create the configmap
echo "📋 Creating Kubernetes configmap..."
kubectl create configmap cloudflare-config \
  --namespace=external-dns \
  --from-literal=zone-id="$ZONE_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

# Update domain filter in external-dns deployment
echo "🌐 Updating domain filter..."
EXTERNAL_DNS_FILE="infra/external-dns/external-dns-deployment.yaml"
if [ -f "$EXTERNAL_DNS_FILE" ]; then
    sed -i.bak "s/buildin.group/$DOMAIN/g" "$EXTERNAL_DNS_FILE"
    echo "✅ Updated External-DNS domain filter to $DOMAIN"
    rm -f "$EXTERNAL_DNS_FILE.bak"
fi

echo ""
echo "🎉 Cloudflare setup complete!"
echo ""
echo "What was configured:"
echo "✅ Kubernetes secret: cloudflare-api-token"
echo "✅ Kubernetes configmap: cloudflare-config"
echo "✅ External-DNS domain filter: $DOMAIN"
echo ""
echo "Next steps:"
echo "1. Deploy External-DNS:"
echo "   kubectl apply -k infra/external-dns/"
echo ""
echo "2. Check deployment status:"
echo "   kubectl get pods -n external-dns"
echo "   kubectl logs -n external-dns deployment/external-dns"
echo ""
echo "3. Add annotations to your services:"
echo "   external-dns.alpha.kubernetes.io/hostname: service.$DOMAIN"
echo ""
echo "🔒 External-DNS is ready to manage DNS records for $DOMAIN!"