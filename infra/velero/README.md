# Velero Cheat Sheet

Velero is used for cluster backups and restores. It is configured to use OCI Object Storage via S3-compatible API and Infisical for secret management.

## 🚀 Setup & Credentials

If you need to update OCI credentials in Infisical:
```bash
./setup-velero-credentials.sh
```

## 📦 Backups

### List all backups
```bash
velero backup get
```

### Trigger a manual backup (all configured namespaces)
```bash
velero backup create manual-backup-$(date +%Y%m%d) --from-schedule velero-daily-full
```

### Backup specific namespaces
```bash
velero backup create my-app-backup --include-namespaces my-namespace
```

## 💾 Persistent Volume Backups (Automated PVC-only)

Velero is configured to automatically back up all **PersistentVolumeClaims (PVCs)**. 

### 🚫 Automatic Exclusions
A global **Resource Policy** (`velero-resource-policy`) is active that automatically skips the following volume types to prevent large or ephemeral backups:
- **NFS** (inline)
- **hostPath**
- **emptyDir**

### 🎯 Manual Exclusions
If you need to skip a specific PVC that is normally included, you can annotate the pod:
```bash
kubectl -n <namespace> annotate pod <pod-name> backup.velero.io/backup-volumes-excludes=volume-name
```


### Check backup details/errors
```bash
velero backup describe <BACKUP_NAME>
velero backup logs <BACKUP_NAME>
```

## 🔄 Restores

### List all restores
```bash
velero restore get
```

### Restore from a specific backup
```bash
velero restore create --from-backup <BACKUP_NAME>
```

### Restore specific namespaces from a backup
```bash
velero restore create --from-backup <BACKUP_NAME> --include-namespaces bitwarden
```

### Check restore status/details
```bash
velero restore describe <RESTORE_NAME>
velero restore logs <RESTORE_NAME>
```

## 📅 Schedules

### List schedules
```bash
velero schedule get
```

### Pause/Resume a schedule
```bash
velero schedule pause velero-daily-full
velero schedule resume velero-daily-full
```

## 📊 Remote Storage Monitoring

### Inspect remote storage size/usage (using Infisical to inject credentials)
```bash
infisical run -e prod --path /velero -- bash -c '
  export AWS_ACCESS_KEY_ID=$(echo "${CLOUD:-$cloud}" | grep aws_access_key_id | cut -d= -f2-)
  export AWS_SECRET_ACCESS_KEY=$(echo "${CLOUD:-$cloud}" | grep aws_secret_access_key | cut -d= -f2-)
  export AWS_REGION=$(echo "${CLOUD:-$cloud}" | grep aws_region | cut -d= -f2-)
  export AWS_ENDPOINT=$(echo "${CLOUD:-$cloud}" | grep aws_endpoint | cut -d= -f2-)
  rclone size \
    --s3-provider Other \
    --s3-access-key-id "$AWS_ACCESS_KEY_ID" \
    --s3-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
    --s3-endpoint "$AWS_ENDPOINT" \
    --s3-region "$AWS_REGION" \
    :s3:homelab-ganam/velero
'
```

### Browse remote storage interactively using ncdu
```bash
infisical run -e prod --path /velero -- bash -c '
  export AWS_ACCESS_KEY_ID=$(echo "${CLOUD:-$cloud}" | grep aws_access_key_id | cut -d= -f2-)
  export AWS_SECRET_ACCESS_KEY=$(echo "${CLOUD:-$cloud}" | grep aws_secret_access_key | cut -d= -f2-)
  export AWS_REGION=$(echo "${CLOUD:-$cloud}" | grep aws_region | cut -d= -f2-)
  export AWS_ENDPOINT=$(echo "${CLOUD:-$cloud}" | grep aws_endpoint | cut -d= -f2-)
  rclone ncdu \
    --s3-provider Other \
    --s3-access-key-id "$AWS_ACCESS_KEY_ID" \
    --s3-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
    --s3-endpoint "$AWS_ENDPOINT" \
    --s3-region "$AWS_REGION" \
    :s3:homelab-ganam/velero
'
```

## 🛠 Troubleshooting

### Check Backup Storage Location (BSL)
```bash
velero backup-location get
kubectl -n velero get backupstoragelocation
```

### Check Velero logs
```bash
kubectl -n velero logs deployment/velero
```

## 📁 Direct Volume Restore via Kopia CLI (No Cluster Required)

If you need to recover volume content (like a database file) directly to your local machine without restoring it to a Kubernetes cluster, you can use the official Kopia Docker image. Kopia repositories are separated by namespace/prefix under `velero/kopia/`.

### 1. Retrieve OCI S3 Credentials
Extract your credentials using Infisical:
```bash
infisical run -e prod --path /velero -- bash -c '
  echo "AWS_ACCESS_KEY_ID: $(echo "${CLOUD:-$cloud}" | grep aws_access_key_id | cut -d= -f2-)"
  echo "AWS_SECRET_ACCESS_KEY: $(echo "${CLOUD:-$cloud}" | grep aws_secret_access_key | cut -d= -f2-)"
'
```

### 2. Connect to the Kopia Repository
Establish a connection to the Kopia repository for the namespace you want to restore (e.g. `excalidraw`). We run Kopia as your local user and redirect logs/cache to `/tmp` to avoid file permission issues on your host:
```bash
docker run --rm \
  -u $(id -u):$(id -g) \
  -v ~/.config/kopia:/app/.config \
  -e KOPIA_CONFIG_PATH=/app/.config/repository.config \
  -e KOPIA_LOG_DIR=/tmp/logs \
  -e KOPIA_CACHE_DIRECTORY=/tmp/cache \
  -e AWS_ACCESS_KEY_ID="<your-access-key>" \
  -e AWS_SECRET_ACCESS_KEY="<your-secret-key>" \
  kopia/kopia:latest repository connect s3 \
    --bucket=homelab-ganam \
    --prefix=velero/kopia/excalidraw/ \
    --endpoint=axpf1b4npys0.compat.objectstorage.il-jerusalem-1.oraclecloud.com \
    --region=il-jerusalem-1 \
    --password=static-passw0rd
```
*(Note: Repository password is set to `static-passw0rd` in the `velero-repo-credentials` secret).*

### 3. List Snapshots
List available snapshots and their IDs:
```bash
docker run --rm \
  -u $(id -u):$(id -g) \
  -v ~/.config/kopia:/app/.config \
  -e KOPIA_CONFIG_PATH=/app/.config/repository.config \
  -e KOPIA_LOG_DIR=/tmp/logs \
  -e KOPIA_CACHE_DIRECTORY=/tmp/cache \
  -e KOPIA_PASSWORD=static-passw0rd \
  kopia/kopia:latest snapshot list --all
```

### 4. Restore Files Locally
First, pre-create the host directory to ensure your user account owns it:
```bash
mkdir -p ~/Desktop/restored-data
```
Then, restore the files from the snapshot ID:
```bash
docker run --rm \
  -u $(id -u):$(id -g) \
  -v ~/.config/kopia:/app/.config \
  -v ~/Desktop/restored-data:/restore \
  -e KOPIA_CONFIG_PATH=/app/.config/repository.config \
  -e KOPIA_LOG_DIR=/tmp/logs \
  -e KOPIA_CACHE_DIRECTORY=/tmp/cache \
  -e KOPIA_PASSWORD=static-passw0rd \
  kopia/kopia:latest snapshot restore <snapshot-id> /restore
```

## 🧪 Local Kind Cluster Testing Gotchas

If deploying Velero in a local `kind` cluster for recovery testing, be aware of these requirements:

### 1. S3-Compatible Chunked Encoding
Oracle Cloud Infrastructure (OCI) Object Storage does not support AWS chunked encoding. When configuring the BackupStorageLocation (BSL), the config **must** include:
```yaml
config:
  checksumAlgorithm: ""
```
Without this, object uploads (like restore logs) will fail with `501 NotImplemented: AWS chunked encoding not supported`.

### 2. Local-Path Provisioner (Volume Type)
By default, Rancher's `local-path-provisioner` in Kind creates `hostPath` volumes. Kubelet does not mount `hostPath` volumes inside the node's `/var/lib/kubelet/pods` directory, making them invisible to the Velero node-agent.

To allow Kopia to restore persistent volume data, you **must** recreate the `local-path` StorageClass with the `defaultVolumeType: local` annotation:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    defaultVolumeType: local
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

## 🔥 Bare-Metal Disaster Recovery

If the entire cluster goes down, the node is completely wiped, or you are moving to a brand new hardware setup, follow this guide to recover all your stateful applications from the Velero backups stored in OCI.

### 1. Rebuild the Infrastructure
First, bring the base infrastructure back online:
1. Re-install your OS and configure your base networking.
2. Install **K3s** (ensure Traefik and ServiceLB are disabled if you are using Cilium/Envoy).
3. Clone your `homelab` Git repository.
4. Install **ArgoCD** and apply your `app-of-apps` to bootstrap the cluster. Wait for core namespaces to be created.
5. Deploy **Infisical** or inject your `velero-credentials` and `cloud` secrets into the `velero` namespace.

### 2. Install Velero & Connect to Object Storage
ArgoCD will attempt to deploy the Velero Helm chart, but you must ensure it successfully connects to the OCI bucket:
1. Verify the `velero` pod is running without errors.
2. Ensure the `BackupStorageLocation` is available:
   ```bash
   velero backup-location get
   ```
   *(It should list `default` with the status `Available`.)*

### 3. Identify the Latest Backup
Once Velero is connected to OCI, it will automatically sync the backup metadata down to the cluster. List the available backups to find the most recent successful run:
```bash
velero backup get
```
Identify the latest `velero-daily-full-<timestamp>` that has the status `Completed`.

### 4. Execute the Global Restore
Trigger a full restore of all namespaces from the backup you identified. Since `local-path` PVs are dynamically provisioned, Velero will perfectly recreate the PVCs, force the provisioner to create new empty local folders, and then securely inject your data back into them using Kopia.

```bash
velero restore create disaster-recovery --from-backup <BACKUP_NAME> --wait
```

### 5. Validate Restoration
Once the restore says `Completed`, check that the Kopia data injection succeeded:
```bash
velero restore describe disaster-recovery --details
```
Check your stateful pods (e.g., `webtop`, `bitwarden`, `homeassistant`). They should all transition to `Running` with their historic configurations and data perfectly intact!

