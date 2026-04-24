# AI Skill: Longhorn to Local-Path PVC Migration

**Description:** This skill guides the AI to safely migrate Persistent Volumes (PVCs) from Longhorn to local-path-provisioner for a given application namespace, handling both Deployments and StatefulSets with ArgoCD integration.

## Prerequisites
- The `infra/scripts/migrate_pvc.py` script must exist and be executable.
- The `local-path-provisioner` must be deployed and the `local-path` StorageClass must exist.

## Execution Steps

When asked to migrate a namespace, strictly follow these sequential steps:

### Step 1: Pre-flight Check & Discovery
1. Use `kubectl get deployments,statefulset,pvc -n <namespace>` to identify the workload and its attached Longhorn PVCs.
2. **Crucial:** Instruct the user to go to the ArgoCD UI and disable **Auto-Sync** for the target application. Wait for their confirmation.

### Step 2: Halt & Provision
1. Run the orchestrator to scale down and provision new storage with ArgoCD tracking:
   ```bash
   /home/ronganam/Documents/projects/homelab/infra/scripts/migrate_pvc.py -n <namespace> -d <deployment_name> --argocd-app <app_name> --step halt --non-interactive
   /home/ronganam/Documents/projects/homelab/infra/scripts/migrate_pvc.py -n <namespace> -d <deployment_name> --argocd-app <app_name> --step provision --non-interactive
   ```
   *(Replace `-d` with `-s` for StatefulSets)*.

### Step 3: Data Synchronization (Phase 1)
1. Run the orchestrator to sync data from Longhorn to local-path (`-local` PVCs):
   ```bash
   /home/ronganam/Documents/projects/homelab/infra/scripts/migrate_pvc.py -n <namespace> -d <deployment_name> --step sync --non-interactive
   ```

### Step 4: Cutover & GitOps
1. **For Deployments:**
   - Update `values.yaml`: Set `storageClass: local-path` and append `-local` to volume names.
   - Commit and Push.
2. **For StatefulSets:**
   - Run the delete step (StatefulSets cannot update storage classes in-place):
     ```bash
     /home/ronganam/Documents/projects/homelab/infra/scripts/migrate_pvc.py -n <namespace> -s <sts_name> --step delete-workload --non-interactive
     ```
   - Update `values.yaml`: Set `storageClass: local-path` (keep original volume names).
   - Commit and Push.

### Step 5: ArgoCD Sync & Verification
1. Instruct the user to **Re-enable Auto-Sync** and **Sync** the application in ArgoCD.
2. **StatefulSet Final Sync:** If it's a StatefulSet, the pods will now have *empty* local-path volumes. Run the "Sync Back" step:
   ```bash
   /home/ronganam/Documents/projects/homelab/infra/scripts/migrate_pvc.py -n <namespace> -s <sts_name> --step sync --sync-back --non-interactive
   ```
3. Wait for the user to confirm the application is healthy.

### Step 6: Cleanup
1. Once confirmed, run the cleanup step to delete the old Longhorn PVCs and temporary `-local` PVCs (if synced back).
   ```bash
   /home/ronganam/Documents/projects/homelab/infra/scripts/migrate_pvc.py -n <namespace> -d <deployment_name> --step cleanup --non-interactive
   ```
