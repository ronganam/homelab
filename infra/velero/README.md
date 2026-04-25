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

## 💾 Persistent Volume Backups (Opt-in)

By default, Velero is configured to **NOT** back up any volumes (to avoid backing up large NFS mounts). 

To back up a volume, you must annotate the pod in your deployment:

```yaml
spec:
  template:
    metadata:
      annotations:
        backup.velero.io/backup-volumes: volume-name-1,volume-name-2
```

To see volume names for a pod:
```bash
kubectl get pod <POD_NAME> -o jsonpath='{.spec.volumes[*].name}'
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
