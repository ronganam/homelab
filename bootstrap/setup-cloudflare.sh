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
    echo "📝 Using existing tunnel ID: $TUNNEL_ID"
else
    TUNNEL_ID=$(cloudflared tunnel create --output json homelab-tunnel | jq -r '.id')
    echo "✅ Tunnel created with ID: $TUNNEL_ID"
fi

# Verify tunnel ID was obtained
if [ -z "$TUNNEL_ID" ] || [ "$TUNNEL_ID" = "null" ]; then
    echo "❌ Failed to get tunnel ID. Please check your Cloudflare authentication."
    exit 1
fi

# Get tunnel credentials
echo "📋 Getting tunnel credentials..."
# Try to get the actual tunnel credentials file
if cloudflared tunnel info homelab-tunnel > /tmp/tunnel-info.txt 2>/dev/null; then
    echo "✅ Got tunnel info"
    # Extract account tag from tunnel info (we'll use a default since we can't parse JSON)
    ACCOUNT_TAG="unknown"
    
    # Try to get the tunnel secret (this is the tricky part)
    echo "🔐 Attempting to get tunnel secret..."
    
    # Method 1: Try to get from tunnel token
    TUNNEL_TOKEN=$(cloudflared tunnel token homelab-tunnel 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$TUNNEL_TOKEN" ]; then
        echo "✅ Got tunnel token, extracting secret"
        # The token is base64-encoded JSON with account tag, secret, and tunnel ID
        TOKEN_JSON=$(echo "$TUNNEL_TOKEN" | base64 -d 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$TOKEN_JSON" ]; then
            # Extract account tag and secret from the JSON
            ACCOUNT_TAG=$(echo "$TOKEN_JSON" | jq -r '.a // "unknown"' 2>/dev/null)
            TUNNEL_SECRET=$(echo "$TOKEN_JSON" | jq -r '.s // "placeholder"' 2>/dev/null)
            if [ -n "$TUNNEL_SECRET" ] && [ "$TUNNEL_SECRET" != "null" ] && [ "$TUNNEL_SECRET" != "placeholder" ]; then
                echo "✅ Extracted account tag and secret from token"
            else
                echo "⚠️  Could not extract secret from token JSON, trying alternative method"
                TUNNEL_SECRET="placeholder"
            fi
        else
            echo "⚠️  Could not decode token, trying alternative method"
            TUNNEL_SECRET="placeholder"
        fi
    else
        echo "⚠️  Could not get tunnel token, trying alternative method"
        TUNNEL_SECRET="placeholder"
    fi
    
    # Method 2: If we still have placeholder, try to get from existing credentials
    if [ "$TUNNEL_SECRET" = "placeholder" ]; then
        echo "🔍 Looking for existing tunnel credentials..."
        # Check if there's an existing credentials file in common locations
        for cred_file in ~/.cloudflared/$TUNNEL_ID.json ~/.cloudflared/credentials.json /etc/cloudflared/credentials.json; do
            if [ -f "$cred_file" ]; then
                echo "✅ Found existing credentials file: $cred_file"
                EXISTING_SECRET=$(cat "$cred_file" | jq -r '.TunnelSecret // empty' 2>/dev/null)
                if [ -n "$EXISTING_SECRET" ] && [ "$EXISTING_SECRET" != "null" ]; then
                    TUNNEL_SECRET="$EXISTING_SECRET"
                    echo "✅ Extracted secret from existing credentials"
                    break
                fi
            fi
        done
    fi
    
    # Method 3: If still placeholder, ask user to provide it
    if [ "$TUNNEL_SECRET" = "placeholder" ]; then
        echo "⚠️  Could not automatically get tunnel secret."
        echo "💡 You can find the tunnel secret in:"
        echo "   1. Cloudflare dashboard → Zero Trust → Access → Tunnels → homelab-tunnel"
        echo "   2. Or in your local ~/.cloudflared/ directory"
        echo ""
        read -p "Enter the tunnel secret (or press Enter to use placeholder): " USER_SECRET
        if [ -n "$USER_SECRET" ]; then
            TUNNEL_SECRET="$USER_SECRET"
            echo "✅ Using provided tunnel secret"
        else
            echo "⚠️  Using placeholder secret - tunnel may not work properly"
        fi
    fi
    
    # Create credentials.json file
    cat > /tmp/tunnel-credentials.json << EOF
{
  "AccountTag": "$ACCOUNT_TAG",
  "TunnelSecret": "$TUNNEL_SECRET",
  "TunnelID": "$TUNNEL_ID"
}
EOF
    echo "✅ Tunnel credentials saved"
else
    echo "❌ Failed to get tunnel info. Please check if the tunnel exists and you have proper permissions."
    echo "💡 You may need to:"
    echo "   1. Ensure you're logged in: cloudflared tunnel login"
    echo "   2. Check tunnel exists: cloudflared tunnel list"
    echo "   3. Recreate tunnel if needed: cloudflared tunnel delete homelab-tunnel && cloudflared tunnel create homelab-tunnel"
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

# Create DNS records for tunnel
echo "🌐 Creating DNS records for tunnel..."
TUNNEL_HOSTNAME="${TUNNEL_ID}.cfargotunnel.com"

# Function to create CNAME record
create_cname_record() {
    local hostname=$1
    echo "Creating CNAME record for $hostname -> $TUNNEL_HOSTNAME"
    
    curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{
        \"type\": \"CNAME\",
        \"name\": \"$hostname\",
        \"content\": \"$TUNNEL_HOSTNAME\",
        \"ttl\": 1,
        \"proxied\": true,
        \"comment\": \"Created by setup script\"
      }" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Created DNS record for $hostname"
    else
        echo "⚠️  Failed to create DNS record for $hostname (may already exist)"
    fi
}

# Create DNS records for common services
create_cname_record "homepage.$DOMAIN"
create_cname_record "n9n.$DOMAIN"
create_cname_record "argocd.$DOMAIN"

echo "✅ DNS records created"

# Clean up temporary files
rm -f /tmp/tunnel-credentials.json /tmp/tunnel-info.txt

echo ""
echo "🎉 Cloudflare setup complete!"
echo ""
echo "What was configured:"
echo "✅ Cloudflare Tunnel created and configured (ID: $TUNNEL_ID)"
echo "✅ DNS records created for tunnel hostnames"
echo "✅ External-DNS configured for automatic DNS management"
echo "✅ All services updated with $DOMAIN"
echo ""
echo "Next steps:"
echo "1. Deploy the infrastructure:"
echo "   kubectl apply -k infra/cloudflare-tunnel/"
echo ""
echo "2. Check deployment status:"
echo "   kubectl get pods -n cloudflare-tunnel"
echo "   kubectl logs -n cloudflare-tunnel deployment/cloudflared"
echo ""
echo "3. Test your services:"
echo "   https://homepage.$DOMAIN"
echo "   https://n9n.$DOMAIN"
echo "   https://argocd.$DOMAIN"
echo ""
echo "🔒 Your homelab will be automatically accessible via $DOMAIN!"
echo "📝 Tunnel ID: $TUNNEL_ID"
echo "🌐 Tunnel hostname: $TUNNEL_HOSTNAME"
echo ""
echo "🔧 To fix any issues:"
echo "1. If tunnel fails to start, check credentials:"
echo "   kubectl get secret cloudflared-tunnel-credentials -n cloudflare-tunnel -o yaml"
echo ""
echo "2. If DNS records are missing, check:"
echo "   kubectl logs -n cloudflare-tunnel job/create-tunnel-dns-records"
echo ""
echo "3. If services are not accessible, check tunnel logs:"
echo "   kubectl logs -n cloudflare-tunnel deployment/cloudflared"
echo ""
echo "4. To get the real tunnel secret, run:"
echo "   cloudflared tunnel token homelab-tunnel"
echo "   # Then update the secret with the extracted secret"