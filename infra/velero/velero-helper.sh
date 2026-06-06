#!/usr/bin/env bash

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper output functions
info()    { echo -e "${BLUE}[INFO] $*${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $*${NC}"; }
warn()    { echo -e "${YELLOW}[WARN] $*${NC}"; }
error()   { echo -e "${RED}[ERROR] $*${NC}"; }
title()   { echo -e "\n${MAGENTA}=== $* ===${NC}\n"; }

# Check dependencies
check_dep() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "Required command '$cmd' is not installed."
    if [ "$cmd" = "infisical" ]; then
      info "Install Infisical: https://infisical.com/docs/cli/overview"
    elif [ "$cmd" = "docker" ]; then
      info "Install Docker: https://docs.docker.com/engine/install/"
    elif [ "$cmd" = "rclone" ]; then
      info "Install rclone: https://rclone.org/downloads/"
    fi
    exit 1
  fi
}

check_dep infisical
check_dep docker
check_dep rclone

# Global Variables
BUCKET="homelab-ganam"
REGION="il-jerusalem-1"
VELERO_PREFIX="velero"
KOPIA_PASSWORD="static-passw0rd"

# Fetch S3/OCI credentials from Infisical
fetch_credentials() {
  info "Fetching S3/OCI credentials from Infisical..."
  local creds
  creds=$(infisical run -e prod --path /velero -- bash -c 'echo "${CLOUD:-$cloud}"')
  
  export AWS_ACCESS_KEY_ID=$(echo "$creds" | grep aws_access_key_id | cut -d= -f2-)
  export AWS_SECRET_ACCESS_KEY=$(echo "$creds" | grep aws_secret_access_key | cut -d= -f2-)
  export AWS_REGION=$(echo "$creds" | grep aws_region | cut -d= -f2-)
  export AWS_ENDPOINT=$(echo "$creds" | grep aws_endpoint | cut -d= -f2-)
  
  if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_ENDPOINT" ]; then
    error "Failed to retrieve full OCI credentials from Infisical."
    exit 1
  fi
  
  # Remove protocol scheme from endpoint for Kopia compatibility
  export AWS_ENDPOINT_CLEAN=$(echo "$AWS_ENDPOINT" | sed -e 's|^https://||' -e 's|^http://||')
}

show_cheatsheet() {
  title "Velero Homelab Cheat Sheet"
  echo -e "${CYAN}📅 Scheduled Backups:${NC}"
  echo "  - Schedule name: velero-daily-full (Runs daily at 02:00 UTC)"
  echo "  - Retention: 48 hours (keeps today's and yesterday's backups)"
  echo ""
  echo -e "${CYAN}📦 Manual Commands:${NC}"
  echo "  - List backups:       velero backup get"
  echo "  - Create backup:      velero backup create manual-backup-\$(date +%Y%m%d) --from-schedule velero-daily-full"
  echo "  - Restore namespace:  velero restore create --from-backup <BACKUP_NAME> --include-namespaces <NAMESPACE>"
  echo "  - Check logs:         velero restore logs <RESTORE_NAME>"
  echo ""
  echo -e "${CYAN}🧪 Local Kind cluster testing requirements:${NC}"
  echo "  1. BSL requires config parameter: checksumAlgorithm: \"\""
  echo "  2. local-path StorageClass requires annotation: defaultVolumeType: local"
  echo ""
}

view_rclone_size() {
  title "Analyzing Remote Storage Size"
  fetch_credentials
  
  rclone size \
    --s3-provider Other \
    --s3-access-key-id "$AWS_ACCESS_KEY_ID" \
    --s3-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
    --s3-endpoint "$AWS_ENDPOINT" \
    --s3-region "$AWS_REGION" \
    ":s3:$BUCKET/$VELERO_PREFIX"
}

browse_rclone_ncdu() {
  title "Interactive Storage Directory Browser (ncdu)"
  fetch_credentials
  
  rclone ncdu \
    --s3-provider Other \
    --s3-access-key-id "$AWS_ACCESS_KEY_ID" \
    --s3-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
    --s3-endpoint "$AWS_ENDPOINT" \
    --s3-region "$AWS_REGION" \
    ":s3:$BUCKET/$VELERO_PREFIX"
}

restore_kopia_volume() {
  title "Direct Volume Restore via Kopia (No Cluster)"
  fetch_credentials
  
  info "Listing backed-up namespaces in Kopia repository..."
  local namespaces
  namespaces=$(rclone lsd \
    --s3-provider Other \
    --s3-access-key-id "$AWS_ACCESS_KEY_ID" \
    --s3-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
    --s3-endpoint "$AWS_ENDPOINT" \
    --s3-region "$AWS_REGION" \
    ":s3:$BUCKET/$VELERO_PREFIX/kopia/" 2>/dev/null | awk '{print $NF}' || true)
  
  if [ -z "$namespaces" ]; then
    warn "No Kopia namespaces found in the bucket."
    return
  fi
  
  echo -e "\nAvailable Namespaces:"
  local i=1
  local ns_arr=()
  for ns in $namespaces; do
    if [ "$ns" != "default" ]; then
      echo "  $i) $ns"
      ns_arr+=("$ns")
      i=$((i+1))
    fi
  done
  
  echo ""
  read -rp "Select a namespace number: " ns_choice
  if ! [[ "$ns_choice" =~ ^[0-9]+$ ]] || [ "$ns_choice" -lt 1 ] || [ "$ns_choice" -ge "$i" ]; then
    error "Invalid choice."
    return
  fi
  
  local target_ns="${ns_arr[$((ns_choice-1))]}"
  info "Selected namespace: $target_ns"
  
  # Connect to repository
  local config_dir
  config_dir=$(mktemp -d -t kopia-config-XXXXXX)
  
  info "Connecting to Kopia repository for namespace '$target_ns'..."
  if ! docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$config_dir:/app/.config" \
    -e KOPIA_CONFIG_PATH=/app/.config/repository.config \
    -e KOPIA_LOG_DIR=/tmp/logs \
    -e KOPIA_CACHE_DIRECTORY=/tmp/cache \
    -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    kopia/kopia:latest repository connect s3 \
      --bucket="$BUCKET" \
      --prefix="$VELERO_PREFIX/kopia/$target_ns/" \
      --endpoint="$AWS_ENDPOINT_CLEAN" \
      --region="$AWS_REGION" \
      --password="$KOPIA_PASSWORD" >/dev/null 2>&1; then
    error "Failed to connect to Kopia repository."
    rm -rf "$config_dir"
    return
  fi
  
  # List snapshots
  info "Fetching available snapshots..."
  echo ""
  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$config_dir:/app/.config" \
    -e KOPIA_CONFIG_PATH=/app/.config/repository.config \
    -e KOPIA_LOG_DIR=/tmp/logs \
    -e KOPIA_CACHE_DIRECTORY=/tmp/cache \
    -e KOPIA_PASSWORD="$KOPIA_PASSWORD" \
    kopia/kopia:latest snapshot list --all
  
  echo ""
  read -rp "Enter the Snapshot ID you wish to restore: " snapshot_id
  if [ -z "$snapshot_id" ]; then
    error "Snapshot ID cannot be empty."
    rm -rf "$config_dir"
    return
  fi
  
  # Destination Folder
  local default_dest="$HOME/Desktop/$target_ns-restored"
  read -rp "Destination folder [$default_dest]: " dest_path
  dest_path="${dest_path:-$default_dest}"
  
  info "Pre-creating host directory '$dest_path' to ensure ownership..."
  mkdir -p "$dest_path"
  
  info "Restoring files..."
  docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$config_dir:/app/.config" \
    -v "$dest_path:/restore" \
    -e KOPIA_CONFIG_PATH=/app/.config/repository.config \
    -e KOPIA_LOG_DIR=/tmp/logs \
    -e KOPIA_CACHE_DIRECTORY=/tmp/cache \
    -e KOPIA_PASSWORD="$KOPIA_PASSWORD" \
    kopia/kopia:latest snapshot restore "$snapshot_id" /restore
  
  success "Restore completed successfully to '$dest_path'."
  rm -rf "$config_dir"
}

# Interactive Menu Loop
while true; do
  title "Velero Homelab Recovery Menu"
  echo "  1) 📊 View Remote Storage Size (rclone)"
  echo "  2) 🔍 Browse Remote Storage Interactively (rclone ncdu)"
  echo "  3) 📁 Extract/Restore Volume Files Locally (Kopia/Docker)"
  echo "  4) 📝 View Quick Cheat Sheet"
  echo "  5) ❌ Exit"
  echo ""
  read -rp "Select an option [1-5]: " choice
  
  case "$choice" in
    1) view_rclone_size ;;
    2) browse_rclone_ncdu ;;
    3) restore_kopia_volume ;;
    4) show_cheatsheet ;;
    5) success "Goodbye!"; exit 0 ;;
    *) error "Invalid option. Please choose between 1 and 5." ;;
  esac
done
