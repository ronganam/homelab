# Longhorn Distributed Storage

A distributed block storage solution for your homelab using the **Longhorn** Helm chart.

**Location**: `infra/longhorn/` - This is infrastructure that provides persistent storage for all applications in your homelab.

## What's Included

- **Longhorn Engine** - Distributed block storage engine
- **Longhorn Manager** - Storage management and orchestration
- **Longhorn UI** - Web interface for storage management
- **CSI Driver** - Container Storage Interface for Kubernetes
- **Default Storage Class** - Automatic persistent volume provisioning

## Access

After deployment, your Longhorn services will be available at:

- **Longhorn UI**: `http://longhorn.buildin.group` (internal access via MetalLB)
  - Monitor storage usage, volumes, and backups
  - Manage storage classes and settings
  - View cluster health and performance

## Features

### Distributed Storage
- **Replicated volumes** with configurable replica count
- **Automatic failover** when nodes become unavailable
- **Data integrity** with checksums and self-healing
- **Backup and restore** capabilities
- **Cross-zone replication** support

### Kubernetes Integration
- **Default Storage Class** - automatically provisioned for PVCs
- **CSI Driver** - native Kubernetes storage integration
- **Dynamic provisioning** - create volumes on-demand
- **Snapshot support** - point-in-time volume snapshots

### Resource Management
- **Storage over-provisioning** - 200% by default for efficiency
- **Minimal available space** - 25% threshold for safety
- **CPU resource limits** - guaranteed CPU for engine and replica managers
- **Soft anti-affinity** - spread replicas across nodes when possible

## Storage Configuration

### Default Settings
- **Replica Count**: 1 (suitable for homelab)
- **Data Path**: `/var/lib/longhorn/`
- **Storage Class**: `longhorn` (default)
- **Over-provisioning**: 200%
- **Minimal Available**: 25%

### Volume Management
- **Automatic provisioning** when PVCs are created
- **Replica placement** across available nodes
- **Health monitoring** with automatic recovery
- **Performance metrics** in the UI

## ArgoCD + Helm Integration

This Longhorn deployment follows **Helm best practices** and the **proper ArgoCD way** to deploy Helm charts:

### **How It Works:**
- **ArgoCD Application** directly references the Longhorn Helm chart repository
- **Clean, organized Helm values** embedded in the Application manifest
- **No manual Helm commands** - ArgoCD handles everything
- **GitOps workflow** - changes to the Application manifest trigger updates
- **Automatic sync** - ArgoCD keeps the deployment in sync

### **Benefits:**
- **Simple and maintainable** - following Helm Chart best practices
- **No manual configuration** - everything is pre-configured
- **Proper storage class** - automatically available for all applications
- **GitOps native** - all configuration is in version control
- **Easy updates** - modify the Application manifest and ArgoCD handles the rest

### **File Structure:**
```
infra/longhorn/
├── helm/                       # Helm chart directory
│   ├── Chart.yaml             # Helm chart metadata
│   ├── values.yaml            # Helm values for Longhorn
│   ├── namespace.yaml         # Namespace definition
│   └── kustomization.yaml     # Kustomize configuration
├── kustomization.yaml         # Main kustomization file
└── README.md                  # This documentation
```

### **How It Works:**
1. **ArgoCD ApplicationSet** automatically discovers `infra/*/helm` directories
2. **Helm chart** references the `longhorn` chart as a dependency
3. **Values file** customizes the chart for your homelab
4. **GitOps workflow** - changes trigger automatic updates

This follows the **Helm principle** of keeping things simple and maintainable while leveraging ArgoCD's GitOps capabilities.

## Usage in Applications

Once deployed, Longhorn automatically provides the `longhorn` storage class. Your applications can use it like this:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn  # Uses Longhorn automatically
  resources:
    requests:
      storage: 10Gi
```

## Troubleshooting

### Check if Longhorn is running:
```bash
kubectl get pods -n longhorn-system
kubectl get storageclass
```

### View Longhorn UI:
1. Go to `http://longhorn.buildin.group`
2. Check volume health and usage
3. Monitor cluster status

### Check storage class:
```bash
kubectl get storageclass longhorn -o yaml
```

### View logs:
```bash
kubectl logs -n longhorn-system deployment/longhorn-manager
kubectl logs -n longhorn-system daemonset/longhorn-manager
```
