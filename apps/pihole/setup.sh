#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="pihole"
SECRET_NAME="pihole-admin"

main() {
  echo "[pihole] Ensuring namespace '${NAMESPACE}' exists..."
  kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

  local password
  password="${PIHOLE_ADMIN_PASSWORD:-}"
  if [ -z "${password}" ]; then
    read -r -s -p "Enter Pi-hole admin password: " password
    echo
  fi

  if [ -z "${password}" ]; then
    echo "Error: Admin password empty. Set PIHOLE_ADMIN_PASSWORD or enter when prompted." >&2
    exit 1
  fi

  echo "[pihole] Creating/updating admin secret '${SECRET_NAME}' in namespace '${NAMESPACE}'..."
  kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
    --from-literal=password="${password}" \
    --dry-run=client -o yaml | kubectl apply -f -

  cat <<EOF

[pihole] Done.

To have the chart use this secret, add the following under 'pihole:' in apps/pihole/values.yaml:

  admin:
    existingSecret: ${SECRET_NAME}
    passwordKey: password

If you want LAN devices to use Pi-hole for DNS, expose DNS via MetalLB by adding:

  serviceDns:
    type: LoadBalancer
    loadBalancerIP: <YOUR_STATIC_LAN_IP>
    annotations:
      metallb.universe.tf/allow-shared-ip: pihole

Replace <YOUR_STATIC_LAN_IP> with a free IP in your MetalLB pool/outside DHCP.

EOF
}

main "$@"


