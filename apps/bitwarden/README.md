# Bitwarden (Vaultwarden)

This app uses Vaultwarden with Longhorn storage and exposes an internal LoadBalancer. Create the required secrets before or right after ArgoCD sync.

## Required secrets

### Admin token

Generate a strong random token and store it in the `vaultwarden-admin` secret (key `token`).

```bash
# Example: generate a 64-char hex token
openssl rand -hex 32

# Create the secret with a secure Argon2 hash (recommended)
# First generate the hash:
docker run --rm vaultwarden/server:1.34.3 vaultwarden hash

# Then create the secret with the generated hash:
kubectl -n bitwarden create secret generic vaultwarden-admin \
  --from-literal=token='REPLACE_WITH_ARCON2_HASH'

# Alternative: use a simple random token (less secure)
# kubectl -n bitwarden create secret generic vaultwarden-admin \
#   --from-literal=token='REPLACE_WITH_STRONG_RANDOM_TOKEN'
```

### TLS certificates

**For testing (self-signed certificate):**
```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=bitwarden.buildin.group"

# Create the secret
kubectl -n bitwarden create secret tls vaultwarden-tls \
  --cert=tls.crt --key=tls.key

# Clean up local files
rm tls.crt tls.key
```

**For production (real certificates):**
```bash
kubectl -n bitwarden create secret tls vaultwarden-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

Update secrets later:
```bash
kubectl -n bitwarden delete secret vaultwarden-admin
kubectl -n bitwarden create secret generic vaultwarden-admin \
  --from-literal=token='REPLACE_WITH_STRONG_RANDOM_TOKEN'

kubectl -n bitwarden delete secret vaultwarden-tls
kubectl -n bitwarden create secret tls vaultwarden-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

## Optional: SMTP email support

To enable email features, you need to set both `SMTP_HOST` and `SMTP_FROM` in the ConfigMap, plus create the SMTP secret with credentials.

**Step 1: Enable SMTP in ConfigMap**
Edit `configmap.yaml` and uncomment the SMTP lines, then set your values:
```yaml
SMTP_FROM: "noreply@example.com"
SMTP_HOST: "smtp.example.com"
SMTP_PORT: "587"
SMTP_SECURITY: "starttls"
```

**Step 2: Create SMTP secret with credentials**
```bash
kubectl -n bitwarden create secret generic vaultwarden-smtp \
  --from-literal=username='REPLACE_WITH_SMTP_USERNAME' \
  --from-literal=password='REPLACE_WITH_SMTP_PASSWORD'
```

**To disable email features:** SMTP environment variables are commented out in the ConfigMap (default state).

Update later:
```bash
kubectl -n bitwarden delete secret vaultwarden-smtp
kubectl -n bitwarden create secret generic vaultwarden-smtp \
  --from-literal=username='REPLACE_WITH_SMTP_USERNAME' \
  --from-literal=password='REPLACE_WITH_SMTP_PASSWORD'
```

## Apply changes

After editing the ConfigMap or creating/updating secrets, ArgoCD will automatically sync the changes. The StatefulSet will restart automatically when the ConfigMap changes.

## Verify
```bash
kubectl -n bitwarden get pods,svc,cm,secret
```

## Backups

A CronJob performs a reliable online backup of Vaultwarden data using SQLite's Online Backup API and `restic` for encrypted, deduplicated storage.

### Configure backup destination (Oracle Object Storage)

Use the helper script to create/update the Secret securely (no secrets in Git):

```bash
chmod +x apps/bitwarden/setup-oci-restic-secret.sh
apps/bitwarden/setup-oci-restic-secret.sh
```

The script will:
- Discover your OCI namespace with `oci os ns get`
- Parse default bucket/region from `infra/longhorn/helm/values.yaml`
- Prompt for your Customer Secret Key ID/Secret and RESTIC_PASSWORD
- Create/update the `bitwarden-backup` Secret

Retention defaults can be adjusted in `backup-configmap.yaml` (`RESTIC_KEEP_*`). The CronJob runs daily at 03:00 (see `backup-cronjob.yaml`).

Notes:
- Backs up `/data` including `attachments`, `sends`, `config.json`, `rsa_key*`, and a consistent SQLite copy under `/data/backups/`.
- Excludes live SQLite files (`db.sqlite3`, `-wal`, `-shm`) and `icon_cache`.
- The backup job prefers scheduling on the same node as the `bitwarden` pod to avoid RWO mount conflicts.
- You can use `infra/longhorn/setup-oci-backup.sh` as a reference for obtaining your OCI namespace and region.

### Run a backup now

```bash
kubectl -n bitwarden create job --from=cronjob/bitwarden-backup bitwarden-backup-manual
kubectl -n bitwarden logs -l job-name=bitwarden-backup-manual -c backup --tail=-1 | cat
```

### Restore (SQLite backend)

0) Temporarily pause Argo CD reconciliation (to prevent it from scaling the StatefulSet back up during restore):
```bash
# Replace with your Argo CD Application name that manages this folder
APP_NAME="bitwarden"

# Disable Auto-Sync (and Self-Heal if enabled)
argocd app set "$APP_NAME" --sync-policy none
# Alternatively, if you only want to disable self-heal:
# argocd app set "$APP_NAME" --self-heal=false
```

1) Stop writes:
```bash
kubectl -n bitwarden scale statefulset/bitwarden --replicas=0
```

2) Start a temporary pod with the PVC mounted and restic available:
```bash
kubectl -n bitwarden apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: vw-restore
  namespace: bitwarden
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
            name: bitwarden-backup
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: data-bitwarden-0
EOF
```

3) Restore latest snapshot into `/` (contains `/data/...`):
```bash
kubectl -n bitwarden exec -it vw-restore -- sh -lc 'restic restore latest --target /'
```

4) Remove the restore pod and start Vaultwarden:
```bash
kubectl -n bitwarden delete pod vw-restore --wait=true
kubectl -n bitwarden scale statefulset/bitwarden --replicas=1
```

5) Re-enable Argo CD Auto-Sync/Self-Heal:
```bash
argocd app set "$APP_NAME" --sync-policy automated --self-heal
```

Test restores periodically to ensure backups are valid.
