#!/usr/bin/env bash

set -euo pipefail

# Seeds the Velero OCI credentials into Infisical.
# The InfisicalSecret CR (templates/infisical-secret.yaml) will then
# automatically sync them into the 'velero-credentials' K8s secret in the
# velero namespace.
#
# Infisical path:  /velero
# Secret key:      cloud
# Secret value:    INI-format OCI S3-compatible credentials (see below)
#
# Requirements: infisical CLI (https://infisical.com/docs/cli/overview)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}$*${NC}"; }
success() { echo -e "${GREEN}$*${NC}"; }
warn()    { echo -e "${YELLOW}$*${NC}"; }
error()   { echo -e "${RED}$*${NC}"; }

command -v infisical >/dev/null 2>&1 || {
  error "infisical CLI not found in PATH."
  error "Install it from: https://infisical.com/docs/cli/overview"
  exit 1
}

DEFAULT_REGION="il-jerusalem-1"
PROJECT_SLUG="homelab-k8s"
ENV_SLUG="prod"
SECRET_PATH="/velero"

info "🔧 Seeding Velero OCI credentials into Infisical"
info "   Project: ${PROJECT_SLUG} | Env: ${ENV_SLUG} | Path: ${SECRET_PATH}"
echo ""

read -rp "Region [${DEFAULT_REGION}]: " REGION
REGION="${REGION:-$DEFAULT_REGION}"

warn "Enter OCI Customer Secret Key credentials."
warn "Create one in OCI Console → Identity → Users → User Details → Customer Secret Keys."
read -rp  "AWS_ACCESS_KEY_ID  (Customer Secret Key ID):     " ACCESS_KEY_ID
read -rsp "AWS_SECRET_ACCESS_KEY (Customer Secret Key Secret): " SECRET_ACCESS_KEY
echo ""

# Velero's AWS plugin requires an INI-format credentials file under the key 'cloud'
CLOUD_CREDS="[default]
aws_access_key_id=${ACCESS_KEY_ID}
aws_secret_access_key=${SECRET_ACCESS_KEY}"

infisical secrets set \
  --projectId="${PROJECT_SLUG}" \
  --env="${ENV_SLUG}" \
  --path="${SECRET_PATH}" \
  "cloud=${CLOUD_CREDS}"

success "✅ Secret 'cloud' stored in Infisical at ${SECRET_PATH}"
info ""
info "The InfisicalSecret CR will sync it to K8s secret 'velero-credentials' in namespace 'velero'."
info "Wait ~60s for the resync, then check:"
info "  kubectl -n velero get backupstoragelocation"
info "  kubectl -n velero get secret velero-credentials"
info ""
info "Trigger a manual test backup once Velero is running:"
info "  velero backup create test-backup --wait"
