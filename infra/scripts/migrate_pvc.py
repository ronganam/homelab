#!/usr/bin/env python3
import argparse
import subprocess
import json
import sys
import time

def run_cmd(cmd, check=True):
    result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and result.returncode != 0:
        print(f"Command failed: {cmd}")
        print(result.stderr)
        sys.exit(1)
    return result.stdout.strip()

def prompt_user(msg, interactive, dry_run=False):
    print(f"\n========================================")
    print(f"[ACTION REQUIRED]")
    print(msg)
    print(f"========================================")
    
    if dry_run:
        print("--> [DRY RUN] Skipping execution.")
        return False
    
    if not interactive:
        print("--> [NON-INTERACTIVE] Proceeding automatically.")
        return True

    while True:
        choice = input("Execute this step? [e]xecute / [s]kip / [q]uit: ").strip().lower()
        if choice == 'e':
            return True
        elif choice == 's':
            print("Skipping step.")
            return False
        elif choice == 'q':
            print("Quitting.")
            sys.exit(0)
        else:
            print("Invalid choice. Please enter 'e', 's', or 'q'.")

def get_deployment_pvcs(namespace, workload_name, workload_type):
    print(f"Discovering PVCs for {workload_type}/{workload_name} in namespace {namespace}...")
    cmd = f"kubectl get {workload_type} {workload_name} -n {namespace} -o json"
    output = run_cmd(cmd)
    
    data = json.loads(output)
    pvcs = []

    # Check regular volumes
    volumes = data.get('spec', {}).get('template', {}).get('spec', {}).get('volumes', [])
    for vol in volumes:
        if 'persistentVolumeClaim' in vol:
            pvcs.append(vol['persistentVolumeClaim']['claimName'])

    # Check volumeClaimTemplates for StatefulSets
    if workload_type == 'statefulset':
        templates = data.get('spec', {}).get('volumeClaimTemplates', [])
        # Even if replicas is 0, we might want to migrate existing PVCs.
        # We'll look for PVCs in the namespace that match the pattern <template>-<workload>-<index>
        all_pvcs_cmd = f"kubectl get pvc -n {namespace} -o json"
        all_pvcs_output = run_cmd(all_pvcs_cmd)
        all_pvcs_data = json.loads(all_pvcs_output)
        
        for template in templates:
            base_name = template['metadata']['name']
            pattern = f"{base_name}-{workload_name}-"
            for item in all_pvcs_data.get('items', []):
                pvc_name = item['metadata']['name']
                if pvc_name.startswith(pattern) and not pvc_name.endswith('-local'):
                    pvcs.append(pvc_name)
            
    if not pvcs:
        print(f"No PVCs found attached to {workload_type}/{workload_name}.")
        return []
        
    print(f"Found PVCs attached to workload: {', '.join(pvcs)}")
    return pvcs

def get_pvc_info(namespace, pvc):
    try:
        cmd = f"kubectl get pvc {pvc} -n {namespace} -o json"
        output = run_cmd(cmd)
        data = json.loads(output)
        return {
            'size': data['spec']['resources']['requests']['storage'],
            'storageClass': data['spec'].get('storageClassName', '')
        }
    except Exception:
        return None

def step_prepare(namespace, pvcs, interactive, dry_run):
    msg = f"""PREPARATION:
Please ensure ArgoCD AUTO-SYNC is DISABLED for this application before continuing.
If auto-sync is on, ArgoCD will fight the script when we try to halt the pods."""
    prompt_user(msg, interactive, dry_run)

def step_halt(namespace, workload_name, workload_type, interactive, dry_run):
    msg = f"""HALT WORKLOAD
Scale {workload_type}/{workload_name} to 0 replicas to halt I/O safely.
Command: kubectl scale {workload_type}/{workload_name} --replicas=0 -n {namespace}"""
    
    if prompt_user(msg, interactive, dry_run):
        run_cmd(f"kubectl scale {workload_type}/{workload_name} --replicas=0 -n {namespace}")
        print("Waiting for pods to terminate...")
        while True:
            # Check for pods matching the deployment name (label app.kubernetes.io/name or similar)
            # We'll use the name directly as a label filter which is common
            cmd = f"kubectl get pods -n {namespace} -o json"
            output = run_cmd(cmd, check=False)
            try:
                data = json.loads(output)
                # Filter pods that belong to this workload name (simple string match for now)
                active_pods = [p for p in data.get('items', []) 
                              if workload_name in p['metadata']['name'] 
                              and p['status']['phase'] in ['Running', 'Pending', 'Terminating']]
                if not active_pods:
                    break
            except Exception:
                pass
            time.sleep(2)
        print("Workload halted successfully.")

def step_provision(namespace, pvcs, interactive, dry_run, argocd_app=None):
    for pvc in pvcs:
        info = get_pvc_info(namespace, pvc)
        if not info: continue
        
        size = info['size']
        new_pvc = f"{pvc}-local"
        
        annotations = ""
        if argocd_app:
            # Format: <app-name>:<group>/<kind>:<namespace>/<name>
            # For PVC, group is empty
            tracking_id = f"{argocd_app}:v1:PersistentVolumeClaim:{namespace}/{new_pvc}"
            annotations = f"\n  annotations:\n    argocd.argoproj.io/tracking-id: {tracking_id}"

        yaml_def = f"""
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {new_pvc}
  namespace: {namespace}{annotations}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: {size}
"""
        msg = f"Provision new Local-Path PVC: {new_pvc} ({size})\nManifest:\n{yaml_def.strip()}"
        if prompt_user(msg, interactive, dry_run):
            process = subprocess.run(f"kubectl apply -f -", shell=True, input=yaml_def, text=True, capture_output=True)
            if process.returncode != 0:
                print(f"Failed to create PVC: {process.stderr}")
                sys.exit(1)
            print(f"PVC {new_pvc} created.")

def step_sync(namespace, pvcs, interactive, dry_run, to_local=True):
    pod_name = f"migration-pod-sync"
    
    volume_mounts = []
    volumes = []
    
    valid_pvcs = []
    for pvc in pvcs:
        # If syncing TO original names, we check for existence of original names
        # If syncing TO local names, we check for existence of original names (source)
        if get_pvc_info(namespace, pvc):
            valid_pvcs.append(pvc)
            
    if not valid_pvcs:
        print("No valid PVCs to sync.")
        return

    for i, pvc in enumerate(valid_pvcs):
        source_pvc = pvc if to_local else f"{pvc}-local"
        dest_pvc = f"{pvc}-local" if to_local else pvc
        
        volumes.append(f"""
  - name: vol-source-{i}
    persistentVolumeClaim:
      claimName: {source_pvc}
""")
        volume_mounts.append(f"""
    - name: vol-source-{i}
      mountPath: /source/{source_pvc}
""")
        volumes.append(f"""
  - name: vol-dest-{i}
    persistentVolumeClaim:
      claimName: {dest_pvc}
""")
        volume_mounts.append(f"""
    - name: vol-dest-{i}
      mountPath: /destination/{dest_pvc}
""")

    pod_yaml = f"""
apiVersion: v1
kind: Pod
metadata:
  name: {pod_name}
  namespace: {namespace}
spec:
  containers:
  - name: rsync
    image: alpine:latest
    command: ["tail", "-f", "/dev/null"]
    volumeMounts:
{''.join(volume_mounts)}
  volumes:
{''.join(volumes)}
  restartPolicy: Never
"""
    msg = f"""Deploy migration pod '{pod_name}' to run rsync between PVCs.
Direction: {'Original -> Local' if to_local else 'Local -> Original'}
Command: kubectl apply -f <pod-manifest>"""
    
    if prompt_user(msg, interactive, dry_run):
        process = subprocess.run(f"kubectl apply -f -", shell=True, input=pod_yaml, text=True, capture_output=True)
        if process.returncode != 0:
            print(f"Failed to create migration pod: {process.stderr}")
            sys.exit(1)
            
        print("Waiting for migration pod to be ready...")
        run_cmd(f"kubectl wait --for=condition=Ready pod/{pod_name} -n {namespace} --timeout=300s")
        
        run_cmd(f"kubectl exec -n {namespace} {pod_name} -- apk add --no-cache rsync")
        
        for pvc in valid_pvcs:
            source_pvc = pvc if to_local else f"{pvc}-local"
            dest_pvc = f"{pvc}-local" if to_local else pvc
            rsync_cmd = f"kubectl exec -n {namespace} {pod_name} -- rsync -avh --delete /source/{source_pvc}/ /destination/{dest_pvc}/"
            msg_rsync = f"Run rsync for PVC '{source_pvc}' -> '{dest_pvc}'\nCommand: {rsync_cmd}"
            if prompt_user(msg_rsync, interactive, dry_run):
                print(f"Running sync for {source_pvc}...")
                run_cmd(rsync_cmd)
                print(f"Sync complete for {source_pvc}.")

        msg_clean = f"Delete migration pod '{pod_name}'\nCommand: kubectl delete pod {pod_name} -n {namespace}"
        if prompt_user(msg_clean, interactive, dry_run):
            run_cmd(f"kubectl delete pod {pod_name} -n {namespace} --force --grace-period=0", check=False)
            print("Migration pod deleted.")

def step_delete_workload(namespace, workload_name, workload_type, interactive, dry_run):
    msg = f"""DELETE WORKLOAD & OLD PVCs
This is required for StatefulSets when changing storage classes.
Command: kubectl delete {workload_type} {workload_name} -n {namespace}
Also deletes existing Longhorn PVCs to allow recreation with local-path."""
    
    if prompt_user(msg, interactive, dry_run):
        pvcs = get_deployment_pvcs(namespace, workload_name, workload_type)
        run_cmd(f"kubectl delete {workload_type} {workload_name} -n {namespace}", check=False)
        for pvc in pvcs:
            run_cmd(f"kubectl delete pvc {pvc} -n {namespace}", check=False)
        print(f"Workload {workload_name} and its PVCs deleted.")

def step_gitops_commit(namespace, pvcs, interactive, dry_run):
    msg = f"""GITOPS COMMIT & CUTOVER
The data has been successfully copied to the new PVCs.
Please go to your Git repository and edit the values.yaml:
1. Change storageClass to 'local-path'.
2. If using Deployments, append '-local' to PVC names.
3. If using StatefulSets, keep original names but ensure storageClass is updated.

Commit and push. 
Then, RE-ENABLE ArgoCD Auto-Sync for this app.
ArgoCD will adopt the PVCs we created (if -local) or create new ones (if original names).

Press [e]xecute to confirm this is done and the app is running."""
    if prompt_user(msg, interactive, dry_run):
        print("GitOps Cutover confirmed.")

def step_cleanup(namespace, pvcs, interactive, dry_run):
    # During cleanup, we need to find PVCs that are NOT the new ones.
    # We should search for PVCs in the namespace that have 'longhorn' storage class
    # and match the base name of the workload.
    
    print(f"Searching for old Longhorn PVCs in namespace {namespace}...")
    cmd = f"kubectl get pvc -n {namespace} -o json"
    output = run_cmd(cmd)
    data = json.loads(output)
    
    old_pvcs = []
    for item in data.get('items', []):
        name = item['metadata']['name']
        sc = item['spec'].get('storageClassName', '')
        
        # SAFETY CHECKS:
        # 1. Must be Longhorn storage class
        # 2. Must NOT end in -local
        if sc == 'longhorn' and not name.endswith('-local'):
            old_pvcs.append(name)
            
    if not old_pvcs:
        print("No old Longhorn PVCs found for cleanup.")
        return

    print(f"Found old PVCs for cleanup: {', '.join(old_pvcs)}")
    
    for pvc in old_pvcs:
        msg = f"CRITICAL: Delete OLD Longhorn PVC '{pvc}'\nCommand: kubectl delete pvc {pvc} -n {namespace}\nONLY proceed if you have verified the app is running correctly on local-path storage!"
        if prompt_user(msg, interactive, dry_run):
            run_cmd(f"kubectl delete pvc {pvc} -n {namespace}")
            print(f"PVC {pvc} deleted.")

def main():
    parser = argparse.ArgumentParser(description="Migrate Longhorn PVCs to local-path-provisioner securely.")
    parser.add_argument("--namespace", "-n", required=True, help="Namespace of the deployment")
    parser.add_argument("--deployment", "-d", help="Name of the deployment to migrate")
    parser.add_argument("--statefulset", "-s", help="Name of the statefulset to migrate")
    parser.add_argument("--argocd-app", help="ArgoCD application name for tracking labels")
    parser.add_argument("--sync-back", action="store_true", help="Sync from -local back to original name")
    parser.add_argument("--non-interactive", action="store_true", help="Run without prompting (AI mode)")
    parser.add_argument("--dry-run", action="store_true", help="Show commands without executing them")
    parser.add_argument("--step", choices=['all', 'prepare', 'halt', 'provision', 'sync', 'gitops-commit', 'delete-workload', 'cleanup'], default='all', help="Run a specific step")
    
    args = parser.parse_args()
    
    if not args.deployment and not args.statefulset:
        print("Error: Must specify either --deployment or --statefulset")
        sys.exit(1)
        
    workload_type = "deployment" if args.deployment else "statefulset"
    workload_name = args.deployment or args.statefulset
    interactive = not args.non_interactive
    
    print(f"Starting Migration Orchestrator for {workload_type}/{workload_name} in namespace {args.namespace}")
    if args.dry_run:
        print("*** DRY RUN MODE ENABLED ***")
    
    pvcs = get_deployment_pvcs(args.namespace, workload_name, workload_type)
    
    if args.step in ['all', 'prepare']:
        step_prepare(args.namespace, pvcs, interactive, args.dry_run)
        
    if args.step in ['all', 'halt']:
        step_halt(args.namespace, workload_name, workload_type, interactive, args.dry_run)
        
    if args.step in ['all', 'provision']:
        step_provision(args.namespace, pvcs, interactive, args.dry_run, argocd_app=args.argocd_app)
        
    if args.step in ['all', 'sync']:
        step_sync(args.namespace, pvcs, interactive, args.dry_run, to_local=not args.sync_back)
        
    if args.step in ['all', 'delete-workload']:
        step_delete_workload(args.namespace, workload_name, workload_type, interactive, args.dry_run)

    if args.step in ['all', 'gitops-commit']:
        step_gitops_commit(args.namespace, pvcs, interactive, args.dry_run)
        
    if args.step in ['all', 'cleanup']:
        step_cleanup(args.namespace, pvcs, interactive, args.dry_run)
        
    print("\nMigration Script Execution Complete.")

if __name__ == "__main__":
    main()
