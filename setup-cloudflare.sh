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

# Create namespace and secret
echo "🔐 Creating Kubernetes secret..."
kubectl create namespace cloudflare-tunnel --dry-run=client -o yaml | kubectl apply -f -

# Delete existing secret to avoid annotation warnings
kubectl delete secret cloudflare-tunnel-credentials -n cloudflare-tunnel --ignore-not-found=true

# Create the secret with credentials file
kubectl create secret generic cloudflare-tunnel-credentials \
  --namespace=cloudflare-tunnel \
  --from-file=credentials.json="$CREDENTIALS_FILE"

echo "✅ Kubernetes secret created"

# Deploy the tunnel and controller (excluding the secret we just created)
echo "🚀 Deploying Cloudflare tunnel and controller..."
kubectl apply -f infra/cloudflare-tunnel/namespace.yaml
kubectl apply -f infra/cloudflare-tunnel/cloudflare-tunnel.yaml
kubectl apply -f infra/cloudflare-tunnel/tunnel-controller.yaml

echo ""
echo "🎉 Setup complete!"
echo ""
echo "What was configured:"
echo "✅ Cloudflare Tunnel created and configured"
echo "✅ Tunnel controller deployed (watches for annotations)"
echo "✅ Ready to expose services with annotations"
echo ""
echo "📝 To expose a service to the internet, add this annotation to your Service:"
echo "   cloudflare.com/tunnel-hostname: \"service.$DOMAIN\""
echo ""
echo "🔒 To keep a service internal-only, don't add the annotation"
echo ""
echo "🔧 To check status:"
echo "   kubectl get pods -n cloudflare-tunnel"
echo "   kubectl logs -n cloudflare-tunnel deployment/cloudflared"
echo "   kubectl logs -n cloudflare-tunnel deployment/tunnel-controller"
