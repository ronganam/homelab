#!/bin/bash

# Simple Cloudflare Tunnel Setup for Homelab
# This script creates a tunnel and sets up the controller

set -e

echo "🚀 Simple Cloudflare Tunnel Setup"
echo "================================="
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared is not installed. Please install it first:"
    echo "   macOS: brew install cloudflared"
    echo "   Linux: Download from https://github.com/cloudflare/cloudflared/releases"
    exit 1
fi

echo "✅ cloudflared is installed"

# Check if user is logged in to Cloudflare
echo "🔐 Checking Cloudflare authentication..."
if ! cloudflared tunnel list &> /dev/null; then
    echo "❌ Not authenticated with Cloudflare. Please log in first:"
    echo "   cloudflared tunnel login"
    echo ""
    read -p "Press Enter after you've logged in..."
    
    if ! cloudflared tunnel list &> /dev/null; then
        echo "❌ Still not authenticated. Please run 'cloudflared tunnel login' and try again."
        exit 1
    fi
fi

echo "✅ Cloudflare authentication verified"

# Get domain from user
read -p "Enter your domain (e.g., example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain is required"
    exit 1
fi

# Get Cloudflare API token for internal DNS management
echo ""
echo "🔑 For internal DNS management, you'll need a Cloudflare API token."
echo "   Create one at: https://dash.cloudflare.com/profile/api-tokens"
echo "   Required permissions: Zone:Read, DNS:Edit"
echo ""
read -p "Enter your Cloudflare API token (or press Enter to skip): " API_TOKEN

# Create tunnel (check if it already exists)
echo "🔧 Creating tunnel 'homelab-tunnel'..."
if cloudflared tunnel list | grep -q "homelab-tunnel"; then
    echo "✅ Tunnel 'homelab-tunnel' already exists"
else
    cloudflared tunnel create homelab-tunnel
    echo "✅ Tunnel 'homelab-tunnel' created"
fi

# Get tunnel credentials
echo "🔑 Getting tunnel credentials..."
TUNNEL_ID=$(cloudflared tunnel list --output json | jq -r '.[] | select(.name=="homelab-tunnel") | .id')
if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
    echo "❌ Failed to get tunnel ID"
    exit 1
fi

echo "✅ Got tunnel ID: $TUNNEL_ID"

# Check if credentials file exists
CREDENTIALS_FILE="$HOME/.cloudflared/$TUNNEL_ID.json"
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ Credentials file not found at $CREDENTIALS_FILE"
    echo "Please ensure the tunnel was created properly with: cloudflared tunnel create homelab-tunnel"
    exit 1
fi

echo "✅ Found credentials file"

# Check if origin certificate exists
ORIGIN_CERT_FILE="$HOME/.cloudflared/cert.pem"
if [ ! -f "$ORIGIN_CERT_FILE" ]; then
    echo "❌ Origin certificate not found at $ORIGIN_CERT_FILE"
    echo "Please ensure you've logged in with: cloudflared tunnel login"
    exit 1
fi

echo "✅ Found origin certificate"

# Create namespace and secret
echo "🔐 Creating Kubernetes secret..."
kubectl create namespace cloudflare-tunnel --dry-run=client -o yaml | kubectl apply -f -

# Delete existing secret to avoid annotation warnings
kubectl delete secret cloudflare-tunnel-credentials -n cloudflare-tunnel --ignore-not-found=true

# Create the secret with credentials file and origin certificate
kubectl create secret generic cloudflare-tunnel-credentials \
  --namespace=cloudflare-tunnel \
  --from-file=credentials.json="$CREDENTIALS_FILE" \
  --from-file=cert.pem="$ORIGIN_CERT_FILE"

echo "✅ Kubernetes secret created"

# Create Cloudflare API token secret if provided
if [ -n "$API_TOKEN" ]; then
    echo "🔑 Creating Cloudflare API token secret..."
    kubectl create secret generic cloudflare-api-token \
        --from-literal=token="$API_TOKEN" \
        --namespace=cloudflare-tunnel \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "✅ Cloudflare API token secret created"
else
    echo "⚠️  No API token provided - internal DNS management will be disabled"
fi

# Store tunnel ID in a ConfigMap so the service controller can reference it
echo "🔧 Storing tunnel ID in ConfigMap..."
kubectl create configmap cloudflare-tunnel-info \
    --from-literal=tunnel-id="$TUNNEL_ID" \
    --namespace=cloudflare-tunnel \
    --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Tunnel ID stored in ConfigMap"

# Deploy the tunnel and service controller (excluding the secrets we just created)
echo "🚀 Deploying Cloudflare tunnel and service controller..."
kubectl apply -k infra/cloudflare-tunnel/

echo ""
echo "🎉 Setup complete!"
echo ""
echo "What was configured:"
echo "✅ Cloudflare Tunnel created and configured"
echo "✅ Service controller deployed (manages both public and internal services)"
echo "✅ Ready to manage services with labels"
echo ""
echo "📝 To expose a service to the internet (public), add these labels to your Service:"
echo "   dns.service-controller.io/enabled: \"true\""
echo "   dns.service-controller.io/hostname: \"service.$DOMAIN\""
echo "   exposure.service-controller.io/type: \"public\""
echo ""
echo "🏠 To expose a service internally (MetalLB), add these labels to your Service:"
echo "   dns.service-controller.io/enabled: \"true\""
echo "   dns.service-controller.io/hostname: \"service.internal.$DOMAIN\""
echo "   exposure.service-controller.io/type: \"internal\""
echo "   (and set spec.type: LoadBalancer)"
echo "   Note: Internal services will create DNS A records pointing to MetalLB IPs"
echo ""
echo "🔒 To keep a service cluster-only, don't add DNS management labels"
echo ""
echo "🔧 To check status:"
echo "   kubectl get pods -n cloudflare-tunnel"
echo "   kubectl logs -n cloudflare-tunnel deployment/cloudflared"
echo "   kubectl logs -n cloudflare-tunnel deployment/service-controller"
