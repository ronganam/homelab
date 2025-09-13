#!/bin/bash

# Cloudflare Setup Script for Homelab
# This script sets up both External-DNS and Cloudflare Tunnel

set -e

echo "🚀 Cloudflare Setup for Homelab"
echo "==============================="
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
    
    # Verify authentication again
    if ! cloudflared tunnel list &> /dev/null; then
        echo "❌ Still not authenticated. Please run 'cloudflared tunnel login' and try again."
        exit 1
    fi
fi

echo "✅ Cloudflare authentication verified"

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

# Create tunnel (check if it already exists)
echo "🔧 Creating tunnel 'homelab-tunnel'..."
if cloudflared tunnel list | grep -q "homelab-tunnel"; then
    echo "✅ Tunnel 'homelab-tunnel' already exists"
    TUNNEL_ID=$(cloudflared tunnel list --output json | jq -r '.[] | select(.name=="homelab-tunnel") | .id')
else
    TUNNEL_ID=$(cloudflared tunnel create --output json homelab-tunnel | jq -r '.id')
    echo "✅ Tunnel created with ID: $TUNNEL_ID"
fi

# Get tunnel credentials
echo "📋 Getting tunnel credentials..."
cloudflared tunnel token homelab-tunnel > /tmp/tunnel-credentials.json
if [ $? -eq 0 ]; then
    echo "✅ Tunnel credentials saved"
else
    echo "❌ Failed to get tunnel credentials. Please check if the tunnel exists and you have proper permissions."
    exit 1
fi

# Convert credentials to base64 for Kubernetes secret
echo "🔐 Converting credentials for Kubernetes secret..."
if [ -f "/tmp/tunnel-credentials.json" ]; then
    CREDENTIALS_B64=$(base64 -w 0 /tmp/tunnel-credentials.json)
    if [ $? -eq 0 ]; then
        echo "✅ Credentials converted to base64"
    else
        echo "❌ Failed to convert credentials to base64"
        exit 1
    fi
else
    echo "❌ Tunnel credentials file not found"
    exit 1
fi

# Create namespaces first
echo "📦 Creating namespaces..."
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cloudflare-tunnel --dry-run=client -o yaml | kubectl apply -f -

# Delete existing secrets/configmaps to ensure clean creation
echo "🧹 Cleaning up existing resources..."
kubectl delete secret cloudflare-api-token -n external-dns --ignore-not-found=true
kubectl delete configmap cloudflare-config -n external-dns --ignore-not-found=true
kubectl delete secret cloudflared-tunnel-credentials -n cloudflare-tunnel --ignore-not-found=true

# Create External-DNS secret
echo "🔐 Creating External-DNS secret..."
kubectl create secret generic cloudflare-api-token \
  --namespace=external-dns \
  --from-literal=api-token="$API_TOKEN"

# Create External-DNS configmap
echo "📋 Creating External-DNS configmap..."
kubectl create configmap cloudflare-config \
  --namespace=external-dns \
  --from-literal=zone-id="$ZONE_ID"

# Create Cloudflare Tunnel secret
echo "🔐 Creating Cloudflare Tunnel secret..."
kubectl create secret generic cloudflared-tunnel-credentials \
  --namespace=cloudflare-tunnel \
  --from-file=credentials.json=/tmp/tunnel-credentials.json

# Verify resources were created
echo "✅ Verifying created resources..."
kubectl get secret cloudflare-api-token -n external-dns > /dev/null && echo "✅ External-DNS secret created" || echo "❌ External-DNS secret failed"
kubectl get configmap cloudflare-config -n external-dns > /dev/null && echo "✅ External-DNS configmap created" || echo "❌ External-DNS configmap failed"
kubectl get secret cloudflared-tunnel-credentials -n cloudflare-tunnel > /dev/null && echo "✅ Cloudflare Tunnel secret created" || echo "❌ Cloudflare Tunnel secret failed"

# Update domain filter in external-dns deployment
echo "🌐 Updating domain filter..."
EXTERNAL_DNS_FILE="infra/external-dns/external-dns-deployment.yaml"
if [ -f "$EXTERNAL_DNS_FILE" ]; then
    sed -i.bak "s/buildin.group/$DOMAIN/g" "$EXTERNAL_DNS_FILE"
    echo "✅ Updated External-DNS domain filter to $DOMAIN"
    rm -f "$EXTERNAL_DNS_FILE.bak"
fi

# Update tunnel config with the correct domain
TUNNEL_CONFIG_FILE="infra/cloudflare-tunnel/cloudflared-config.yaml"
if [ -f "$TUNNEL_CONFIG_FILE" ]; then
    sed -i.bak "s/buildin.group/$DOMAIN/g" "$TUNNEL_CONFIG_FILE"
    echo "✅ Updated tunnel configuration"
    rm -f "$TUNNEL_CONFIG_FILE.bak"
fi

# Clean up temporary file
rm -f /tmp/tunnel-credentials.json

echo ""
echo "🎉 Cloudflare setup complete!"
echo ""
echo "What was configured:"
echo "✅ Cloudflare Tunnel created and configured"
echo "✅ External-DNS configured for automatic DNS management"
echo "✅ All services updated with $DOMAIN"
echo ""
echo "Next steps:"
echo "1. Deploy the infrastructure:"
echo "   kubectl apply -k infra/external-dns/"
echo "   kubectl apply -k infra/cloudflare-tunnel/"
echo ""
echo "2. Check deployment status:"
echo "   kubectl get pods -n external-dns"
echo "   kubectl get pods -n cloudflare-tunnel"
echo ""
echo "3. Add annotations to your services:"
echo "   external-dns.alpha.kubernetes.io/hostname: service.$DOMAIN"
echo ""
echo "🔒 Your homelab will be automatically accessible via $DOMAIN!"