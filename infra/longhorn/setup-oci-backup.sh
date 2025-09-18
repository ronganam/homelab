#!/bin/bash

# Longhorn OCI Object Storage Backup Setup Script
# This script automatically extracts OCI values and creates the Kubernetes Secret
# for Longhorn backup target configuration.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Longhorn OCI Object Storage Backup Setup${NC}"
echo "=============================================="

# Check if OCI CLI is installed and configured
if ! command -v oci &> /dev/null; then
    echo -e "${RED}❌ OCI CLI is not installed. Please install it first.${NC}"
    echo "   See: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed or not in PATH.${NC}"
    exit 1
fi

# Get current user OCID
echo -e "${YELLOW}📋 Getting current user information...${NC}"
USER_OCID=$(oci iam user get --user-id $(oci iam user list --query 'data[0].id' --raw-output) --query 'data.id' --raw-output)
echo "   User OCID: $USER_OCID"

# Get tenancy namespace
echo -e "${YELLOW}📋 Getting tenancy namespace...${NC}"
NAMESPACE=$(oci os ns get-metadata --query 'data.namespace' --raw-output)
echo "   Namespace: $NAMESPACE"

# Get default region
echo -e "${YELLOW}📋 Getting default region...${NC}"
REGION=$(oci iam region-subscription list --query 'data[?is-home-region==`true`].region-name' --raw-output)
echo "   Region: $REGION"

# Get S3 compartment OCID
echo -e "${YELLOW}📋 Getting S3 compartment...${NC}"
S3_COMPARTMENT=$(oci os ns get-metadata --query 'data."default-s3-compartment-id"' --raw-output)
echo "   S3 Compartment: $S3_COMPARTMENT"

# List available buckets
echo -e "${YELLOW}📋 Available buckets in S3 compartment:${NC}"
oci os bucket list --compartment-id "$S3_COMPARTMENT" --query 'data[].name' --raw-output | while read -r bucket; do
    echo "   - $bucket"
done

# Prompt for bucket selection
echo ""
read -p "Enter bucket name for Longhorn backups: " BUCKET_NAME

# Verify bucket exists
if ! oci os bucket get --bucket-name "$BUCKET_NAME" --namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}❌ Bucket '$BUCKET_NAME' not found in namespace '$NAMESPACE'${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Bucket '$BUCKET_NAME' found${NC}"

# Check for existing customer secret keys
echo -e "${YELLOW}📋 Checking for existing customer secret keys...${NC}"
EXISTING_KEYS=$(oci iam customer-secret-key list --user-id "$USER_OCID" --query 'data[].id' --raw-output)

if [ -n "$EXISTING_KEYS" ]; then
    echo "   Found existing keys:"
    echo "$EXISTING_KEYS" | while read -r key_id; do
        echo "   - $key_id"
    done
    echo ""
    read -p "Use existing key? (y/n): " USE_EXISTING
    
    if [[ $USE_EXISTING =~ ^[Yy]$ ]]; then
        echo "   Please select a key ID from above:"
        read -p "Key ID: " SELECTED_KEY_ID
        
        # Get the secret key (this requires the key to be recreated as we can't retrieve the secret)
        echo -e "${YELLOW}⚠️  Note: Customer Secret Keys cannot be retrieved after creation.${NC}"
        echo "   You'll need to create a new key to get the secret value."
        read -p "Create new key? (y/n): " CREATE_NEW
        
        if [[ ! $CREATE_NEW =~ ^[Yy]$ ]]; then
            echo -e "${RED}❌ Cannot proceed without a valid secret key.${NC}"
            exit 1
        fi
    fi
fi

# Create new customer secret key
echo -e "${YELLOW}🔑 Creating new customer secret key...${NC}"
SECRET_KEY_OUTPUT=$(oci iam customer-secret-key create \
    --display-name "longhorn-backup-$(date +%Y%m%d-%H%M%S)" \
    --user-id "$USER_OCID" \
    --query 'data' --raw-output)

ACCESS_KEY_ID=$(echo "$SECRET_KEY_OUTPUT" | jq -r '.id')
SECRET_ACCESS_KEY=$(echo "$SECRET_KEY_OUTPUT" | jq -r '.key')

echo -e "${GREEN}✅ Created customer secret key: $ACCESS_KEY_ID${NC}"

# Create the Kubernetes Secret
echo -e "${YELLOW}🔧 Creating Kubernetes Secret...${NC}"
kubectl -n longhorn-system create secret generic longhorn-oci-s3-secret \
    --from-literal=AWS_ACCESS_KEY_ID="$ACCESS_KEY_ID" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$SECRET_ACCESS_KEY" \
    --from-literal=AWS_ENDPOINTS="https://$NAMESPACE.compat.objectstorage.$REGION.oraclecloud.com" \
    --from-literal=AWS_S3_FORCE_PATH_STYLE="true" \
    --from-literal=VIRTUAL_HOSTED_STYLE="false" \
    --from-literal=AWS_REGION="$REGION" \
    --from-literal=AWS_DEFAULT_REGION="$REGION" \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✅ Kubernetes Secret created/updated${NC}"

# Restart Longhorn manager
echo -e "${YELLOW}🔄 Restarting Longhorn manager...${NC}"
kubectl -n longhorn-system rollout restart deploy/longhorn-manager

echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo "=============================================="
echo -e "${BLUE}Next steps:${NC}"
echo "1. Update your values.yaml with:"
echo "   backupTarget: s3://$BUCKET_NAME@$REGION/"
echo "2. Sync via ArgoCD"
echo "3. Check Longhorn UI → Settings → Backup Target"
echo "4. Test a backup from a volume"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "- Save the secret key securely: $SECRET_ACCESS_KEY"
echo "- The secret key cannot be retrieved again"
echo "- Customer Secret Key ID: $ACCESS_KEY_ID"
