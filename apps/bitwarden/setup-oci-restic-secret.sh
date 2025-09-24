#!/usr/bin/env bash

set -euo pipefail

# Simple helper to create/update the Secret used by the Vaultwarden backup CronJob.
# - Targets Oracle Object Storage (OCI S3-compatible)
# - Parses bucket/region defaults from infra/longhorn/helm/values.yaml if available
# - Prompts for RESTIC_PASSWORD and OCI Customer Secret Key ID/Secret
# - Creates/updates Secret: bitwarden-backup (namespace: bitwarden)

# Requirements: kubectl, OCI CLI (for namespace discovery)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
error() { echo -e "${RED}$*${NC}"; }

command -v kubectl >/dev/null 2>&1 || { error "kubectl not found in PATH"; exit 1; }
command -v oci >/dev/null 2>&1 || { error "OCI CLI not found in PATH"; exit 1; }

info "🔧 Creating/Updating Secret: bitwarden-backup (namespace: bitwarden)"

# Try parse defaults from Longhorn values
DEFAULT_BUCKET=""
DEFAULT_REGION=""
VFILE="$(git rev-parse --show-toplevel 2>/dev/null)/infra/longhorn/helm/values.yaml"
if [ -f "$VFILE" ]; then
  # Expect line like: backupTarget: s3://homelab-ganam@il-jerusalem-1/
  LINE=$(grep -E "backupTarget:\s*s3://" "$VFILE" || true)
  if [ -n "$LINE" ]; then
    # Extract bucket@region
    # shellcheck disable=SC2001
    BR=$(echo "$LINE" | sed -E 's/.*s3:\/\/([^@]+)@([^\/]+)\/.*/\1 \2/') || true
    DEFAULT_BUCKET=$(echo "$BR" | awk '{print $1}')
    DEFAULT_REGION=$(echo "$BR" | awk '{print $2}')
  fi
fi

# Fallbacks
DEFAULT_BUCKET=${DEFAULT_BUCKET:-homelab-ganam}
DEFAULT_REGION=${DEFAULT_REGION:-il-jerusalem-1}
DEFAULT_PREFIX="vaultwarden"

# Discover OCI namespace
NAMESPACE=$(oci os ns get --query 'data' --raw-output)

read -rp "Bucket name [${DEFAULT_BUCKET}]: " BUCKET
BUCKET=${BUCKET:-$DEFAULT_BUCKET}

read -rp "Region [${DEFAULT_REGION}]: " REGION
REGION=${REGION:-$DEFAULT_REGION}

read -rp "Repository path prefix (under bucket) [${DEFAULT_PREFIX}]: " PREFIX
PREFIX=${PREFIX:-$DEFAULT_PREFIX}

# Prompt for credentials
warn "Enter OCI Customer Secret Key credentials (ID and Secret)."
warn "If you need to create one, see infra/longhorn/setup-oci-backup.sh or OCI Console."
read -rp "AWS_ACCESS_KEY_ID (Customer Secret Key ID): " ACCESS_KEY_ID
read -rsp "AWS_SECRET_ACCESS_KEY (Customer Secret Key Secret): " SECRET_ACCESS_KEY
echo ""

# RESTIC password
read -rsp "RESTIC_PASSWORD (for repository encryption): " RESTIC_PASSWORD
echo ""

REPO="s3:https://${NAMESPACE}.compat.objectstorage.${REGION}.oraclecloud.com/${BUCKET}/${PREFIX}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: bitwarden-backup
  namespace: bitwarden
stringData:
  RESTIC_REPOSITORY: "${REPO}"
  RESTIC_PASSWORD: "${RESTIC_PASSWORD}"
  AWS_ACCESS_KEY_ID: "${ACCESS_KEY_ID}"
  AWS_SECRET_ACCESS_KEY: "${SECRET_ACCESS_KEY}"
  AWS_REGION: "${REGION}"
  AWS_DEFAULT_REGION: "${REGION}"
  AWS_S3_FORCE_PATH_STYLE: "true"
EOF

success "✅ Secret 'bitwarden-backup' created/updated in namespace 'bitwarden'"
info "Repository: ${REPO}"
info "Hint: Trigger a manual backup job:"
info "  kubectl -n bitwarden create job --from=cronjob/bitwarden-backup bitwarden-backup-manual"

