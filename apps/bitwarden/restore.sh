#!/bin/bash

# Bitwarden (Vaultwarden) restore helper
set -euo pipefail

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
err()  { echo "[ERROR] $*" >&2; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found in PATH"; exit 1; }
}

require kubectl

DEFAULT_APP_NAME="bitwarden"
DEFAULT_ARGOCD_NAMESPACE="argocd"
DEFAULT_NAMESPACE="bitwarden"
DEFAULT_SECRET_NAME="bitwarden-backup"
DEFAULT_RESTORE_SNAPSHOT="latest"

read -r -p "Argo CD Application name [${DEFAULT_APP_NAME}]: " APP_NAME
APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}

read -r -p "Argo CD namespace [${DEFAULT_ARGOCD_NAMESPACE}]: " ARGOCD_NS
ARGOCD_NS=${ARGOCD_NS:-$DEFAULT_ARGOCD_NAMESPACE}

read -r -p "Vaultwarden namespace [${DEFAULT_NAMESPACE}]: " NS
NS=${NS:-$DEFAULT_NAMESPACE}

read -r -p "Restic secret name [${DEFAULT_SECRET_NAME}]: " RESTIC_SECRET
RESTIC_SECRET=${RESTIC_SECRET:-$DEFAULT_SECRET_NAME}

# Try to discover the PVC claim name if not provided
DISCOVERED_PVC=$(kubectl -n "$NS" get pvc -o name 2>/dev/null | grep -E '^persistentvolumeclaim/data-bitwarden-[0-9]+' | head -n1 | sed 's#persistentvolumeclaim/##' || true)
read -r -p "PVC claim name to mount [${DISCOVERED_PVC:-data-bitwarden-0}]: " PVC_NAME
PVC_NAME=${PVC_NAME:-${DISCOVERED_PVC:-data-bitwarden-0}}

read -r -p "Restic snapshot to restore [${DEFAULT_RESTORE_SNAPSHOT}]: " SNAPSHOT
SNAPSHOT=${SNAPSHOT:-$DEFAULT_RESTORE_SNAPSHOT}

echo
info "Summary:"
echo "  Application:         ${APP_NAME} (ns: ${ARGOCD_NS})"
echo "  Vaultwarden ns:      ${NS}"
echo "  PVC:                 ${PVC_NAME}"
echo "  Restic secret:       ${RESTIC_SECRET}"
echo "  Snapshot:            ${SNAPSHOT}"
echo
read -r -p "Proceed with restore? [y/N]: " CONFIRM
if [[ "${CONFIRM:-}" != "y" && "${CONFIRM:-}" != "Y" ]]; then
  warn "Aborted by user."
  exit 1
fi

# Remember current auto-sync state
CURRENT_SYNC_JSON=$(kubectl -n "$ARGOCD_NS" get application "$APP_NAME" -o jsonpath='{.spec.syncPolicy}' 2>/dev/null || true)
PREV_AUTOMATED_ENABLED=$(echo "$CURRENT_SYNC_JSON" | grep -q '"enabled":true' && echo true || echo false)

# Try to disable auto-sync using argocd CLI, fall back to kubectl
if command -v argocd >/dev/null 2>&1; then
  info "Disabling Argo CD auto-sync via argocd CLI..."
  if ! argocd app set "$APP_NAME" --grpc-web --sync-policy none >/dev/null 2>&1; then
    warn "argocd CLI failed to disable auto-sync; falling back to kubectl patch"
    kubectl -n "$ARGOCD_NS" patch application "$APP_NAME" --type=merge -p '{"spec":{"syncPolicy":{}}}' >/dev/null
  fi
else
  warn "argocd CLI not found; disabling auto-sync via kubectl patch"
  kubectl -n "$ARGOCD_NS" patch application "$APP_NAME" --type=merge -p '{"spec":{"syncPolicy":{}}}' >/dev/null
fi

info "Scaling down statefulset/bitwarden to 0"
kubectl -n "$NS" scale statefulset/bitwarden --replicas=0
kubectl -n "$NS" rollout status statefulset/bitwarden --timeout=180s || true

info "Creating temporary restore pod 'vw-restore'"
kubectl -n "$NS" delete pod vw-restore --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl -n "$NS" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: vw-restore
  namespace: ${NS}
spec:
  restartPolicy: Never
  securityContext:
    fsGroup: 33
    runAsNonRoot: true
    runAsUser: 33
    runAsGroup: 33
  containers:
    - name: restore
      image: alpine:3.20
      command: ["/bin/sh","-c"]
      args: ["apk add --no-cache restic bash ca-certificates && sleep 3600"]
      envFrom:
        - secretRef:
            name: ${RESTIC_SECRET}
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ${PVC_NAME}
EOF

info "Waiting for 'vw-restore' to be Ready"
kubectl -n "$NS" wait --for=condition=Ready pod/vw-restore --timeout=180s

info "Running restic restore (${SNAPSHOT})"
kubectl -n "$NS" exec vw-restore -- sh -lc "restic restore ${SNAPSHOT} --target /"

info "Cleaning up restore pod"
kubectl -n "$NS" delete pod vw-restore --wait=true

info "Scaling statefulset/bitwarden back to 1"
kubectl -n "$NS" scale statefulset/bitwarden --replicas=1
kubectl -n "$NS" rollout status statefulset/bitwarden --timeout=180s || true

# Re-enable auto-sync if it was enabled before
if [[ "$PREV_AUTOMATED_ENABLED" == true ]]; then
  if command -v argocd >/dev/null 2>&1; then
    info "Re-enabling Argo CD auto-sync via argocd CLI..."
    if ! argocd app set "$APP_NAME" --grpc-web --sync-policy automated >/dev/null 2>&1; then
      warn "argocd CLI failed; falling back to kubectl patch to enable auto-sync"
      kubectl -n "$ARGOCD_NS" patch application "$APP_NAME" --type=merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":true}}}}' >/dev/null
    fi
  else
    warn "argocd CLI not found; enabling auto-sync via kubectl patch"
    kubectl -n "$ARGOCD_NS" patch application "$APP_NAME" --type=merge -p '{"spec":{"syncPolicy":{"automated":{"enabled":true}}}}' >/dev/null
  fi
else
  info "Auto-sync was not enabled previously; leaving it disabled"
fi

info "Restore complete. Verify application functionality and consider rotating secrets if needed."


