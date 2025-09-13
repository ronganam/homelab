#!/bin/bash

# Cloudflare Setup Script for Homelab
# This script sets up Cloudflare Tunnel with External-DNS for automatic DNS management

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
echo "🔍 Getting Cloudflare Zone ID for $DOMAIN..."
ZONE_ID=$(cloudflared tunnel route dns homelab-tunnel test.$DOMAIN 2>/dev/null | grep -o 'Zone ID: [a-f0-9-]*' | cut -d' ' -f3 || echo "")
if [ -z "$ZONE_ID" ]; then
    echo "Please enter your Cloudflare Zone ID for $DOMAIN:"
    echo "You can find it in your Cloudflare dashboard under the domain overview"
    read -p "Zone ID: " ZONE_ID
fi

# Get Cloudflare API Token
echo "🔑 Please create a Cloudflare API Token:"
echo "1. Go to https://dash.cloudflare.com/profile/api-tokens"
echo "2. Create a custom token with:"
echo "   - Zone:Zone:Read permissions"
echo "   - Zone:DNS:Edit permissions"
echo "   - Include:All zones (or just $DOMAIN)"
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

# Update the tunnel secret file
TUNNEL_SECRET_FILE="infra/cloudflare-tunnel/cloudflared-secret.yaml"
if [ -f "$TUNNEL_SECRET_FILE" ]; then
    sed -i.bak "s/credentials.json: e30K/credentials.json: $CREDENTIALS_B64/" "$TUNNEL_SECRET_FILE"
    echo "✅ Updated tunnel secret file"
    rm -f "$TUNNEL_SECRET_FILE.bak"
fi

# Update External-DNS configuration
echo "🌐 Configuring External-DNS..."

# Update zone ID in external-dns deployment
EXTERNAL_DNS_FILE="infra/external-dns/external-dns-deployment.yaml"
if [ -f "$EXTERNAL_DNS_FILE" ]; then
    sed -i.bak "s/CHANGE_ME/$ZONE_ID/g" "$EXTERNAL_DNS_FILE"
    echo "✅ Updated External-DNS zone ID"
    rm -f "$EXTERNAL_DNS_FILE.bak"
fi

# Update domain filter in external-dns deployment
if [ -f "$EXTERNAL_DNS_FILE" ]; then
    sed -i.bak "s/buildin.group/$DOMAIN/g" "$EXTERNAL_DNS_FILE"
    echo "✅ Updated External-DNS domain filter"
    rm -f "$EXTERNAL_DNS_FILE.bak"
fi

# Update API token in external-dns secret
API_TOKEN_B64=$(echo -n "$API_TOKEN" | base64)
EXTERNAL_DNS_SECRET_FILE="infra/external-dns/external-dns-secret.yaml"
if [ -f "$EXTERNAL_DNS_SECRET_FILE" ]; then
    sed -i.bak "s/Q0hBTkdFX01F/$API_TOKEN_B64/" "$EXTERNAL_DNS_SECRET_FILE"
    echo "✅ Updated External-DNS API token"
    rm -f "$EXTERNAL_DNS_SECRET_FILE.bak"
fi

# Update service annotations with the correct domain
echo "📝 Updating service annotations..."

# Update homepage service
HOMEPAGE_SERVICE="apps/homepage/service.yaml"
if [ -f "$HOMEPAGE_SERVICE" ]; then
    sed -i.bak "s/homepage.buildin.group/homepage.$DOMAIN/g" "$HOMEPAGE_SERVICE"
    echo "✅ Updated homepage service annotation"
    rm -f "$HOMEPAGE_SERVICE.bak"
fi

# Update n8n service
N8N_SERVICE="apps/n8n/service.yaml"
if [ -f "$N8N_SERVICE" ]; then
    sed -i.bak "s/n8n.buildin.group/n9n.$DOMAIN/g" "$N8N_SERVICE"
    echo "✅ Updated n8n service annotation to use n9n domain"
    rm -f "$N8N_SERVICE.bak"
fi

# Update tunnel config with the correct domain
TUNNEL_CONFIG_FILE="infra/cloudflare-tunnel/cloudflared-config.yaml"
if [ -f "$TUNNEL_CONFIG_FILE" ]; then
    sed -i.bak "s/buildin.group/$DOMAIN/g" "$TUNNEL_CONFIG_FILE"
    echo "✅ Updated tunnel configuration"
    rm -f "$TUNNEL_CONFIG_FILE.bak"
fi

# Update homepage config with the correct domain
HOMEPAGE_CONFIG_FILE="apps/homepage/deployment.yaml"
if [ -f "$HOMEPAGE_CONFIG_FILE" ]; then
    sed -i.bak "s/buildin.group/$DOMAIN/g" "$HOMEPAGE_CONFIG_FILE"
    echo "✅ Updated homepage configuration"
    rm -f "$HOMEPAGE_CONFIG_FILE.bak"
fi

# Update n8n config with the correct domain
N8N_CONFIG_FILE="apps/n8n/deployment.yaml"
if [ -f "$N8N_CONFIG_FILE" ]; then
    sed -i.bak "s/n8n.buildin.group/n9n.$DOMAIN/g" "$N8N_CONFIG_FILE"
    echo "✅ Updated n8n configuration to use n9n domain"
    rm -f "$N8N_CONFIG_FILE.bak"
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
echo "1. Commit and push your changes:"
echo "   git add ."
echo "   git commit -m 'Add Cloudflare setup'"
echo "   git push"
echo ""
echo "2. Argo CD will automatically deploy:"
echo "   - Cloudflare Tunnel"
echo "   - External-DNS"
echo "   - All your applications"
echo ""
echo "3. External-DNS will automatically create DNS records for:"
echo "   - https://homepage.$DOMAIN"
echo "   - https://n9n.$DOMAIN"
echo "   - https://argocd.$DOMAIN"
echo "   - https://longhorn.$DOMAIN"
echo ""
echo "4. Check deployment status:"
echo "   kubectl get pods -n cloudflare-tunnel"
echo "   kubectl get pods -n external-dns"
echo ""
echo "🔒 Your homelab will be automatically accessible via $DOMAIN!"
