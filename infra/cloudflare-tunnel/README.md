# Service Controller for Homelab

This is a comprehensive service management solution for your homelab that handles both **public (tunneled)** and **internal (MetalLB)** service exposure with **label-based configuration**.

## What's Included

- **Service Controller** - Generic controller that manages both tunneled and internal services
- **Label-based control** - Clean, intuitive labels for service configuration
- **Automatic DNS management** - Handles both public and internal DNS entries
- **Efficient resource usage** - Optimized label selectors and smart restart logic
- **ArgoCD compatible** - Works with GitOps workflow

## Quick Setup

1. **Run the setup script:**
   ```bash
   ./setup-cloudflare.sh
   ```

2. **Follow the prompts:**
   - Enter your domain (e.g., `example.com`)
   - The script will create the tunnel and deploy the service controller

3. **Configure services using labels:**
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: my-service
     namespace: my-namespace
     labels:
       dns.service-controller.io/enabled: "true"
       dns.service-controller.io/hostname: "myservice.example.com"
       exposure.service-controller.io/type: "public"  # or "internal"
   ```

## How It Works

1. **Service Controller** watches for services with DNS management labels
2. **Public services** are tunneled through Cloudflare with automatic DNS routes
3. **Internal services** use MetalLB LoadBalancer IPs for internal DNS entries
4. **Smart restarts** only occur when tunnel configuration actually changes
5. **Efficient queries** use label selectors for optimal performance

## Service Configuration

### Public Services (Tunneled through Cloudflare)

For services that should be accessible from the internet:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-public-service
  namespace: my-namespace
  labels:
    app: my-public-service
    dns.service-controller.io/enabled: "true"
    dns.service-controller.io/hostname: "myservice.example.com"
    exposure.service-controller.io/type: "public"
spec:
  type: ClusterIP  # Use ClusterIP for tunneled services
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: my-public-service
```

### Internal Services (MetalLB LoadBalancer)

For services that should only be accessible internally:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-internal-service
  namespace: my-namespace
  labels:
    app: my-internal-service
    dns.service-controller.io/enabled: "true"
    dns.service-controller.io/hostname: "myservice.internal.example.com"
    exposure.service-controller.io/type: "internal"
spec:
  type: LoadBalancer  # Use LoadBalancer for internal services
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: my-internal-service
```

### Internal-Only Services (No DNS)

For services that should only be accessible within the cluster:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-cluster-service
  namespace: my-namespace
  labels:
    app: my-cluster-service
    # No DNS management labels = internal cluster access only
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: my-cluster-service
```

## Label Reference

| Label | Values | Description |
|-------|--------|-------------|
| `dns.service-controller.io/enabled` | `"true"` | Enable DNS management for this service |
| `dns.service-controller.io/hostname` | `"hostname.example.com"` | The hostname for DNS entry |
| `exposure.service-controller.io/type` | `"public"` or `"internal"` | How the service should be exposed |

## Examples

### Public Services (Internet Accessible)
- **Homepage**: `homepage.example.com` → Tunneled through Cloudflare
- **n8n**: `n8n.example.com` → Tunneled through Cloudflare
- **ArgoCD**: `argocd.example.com` → Tunneled through Cloudflare

### Internal Services (Local Network Only)
- **Prometheus**: `prometheus.internal.example.com` → MetalLB LoadBalancer
- **Grafana**: `grafana.internal.example.com` → MetalLB LoadBalancer
- **Longhorn**: `longhorn.internal.example.com` → MetalLB LoadBalancer

### Cluster-Only Services
- **Database services** → No DNS labels, cluster access only
- **Internal APIs** → No DNS labels, cluster access only

## Monitoring

Check service controller status:
```bash
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel deployment/service-controller
kubectl logs -n cloudflare-tunnel deployment/cloudflared
```

Check which services have DNS management enabled:
```bash
kubectl get services --all-namespaces -l dns.service-controller.io/enabled=true
```

Check public vs internal services:
```bash
# Public services
kubectl get services --all-namespaces -l exposure.service-controller.io/type=public

# Internal services
kubectl get services --all-namespaces -l exposure.service-controller.io/type=internal
```

## Troubleshooting

- **Controller not working?** Check controller logs and ensure it has proper RBAC permissions
- **Public services not accessible?** Verify labels are correct and check tunnel status
- **Internal services not accessible?** Ensure MetalLB is running and service has LoadBalancer type
- **DNS not working?** Check if the appropriate DNS route was created
- **Config merging issues?** Check init container logs for yq errors
- **ArgoCD conflicts?** Verify that `cloudflared-config` is managed by ArgoCD and `cloudflared-ingress-config` is managed by service-controller

### Debugging Commands

```bash
# Check if configs are properly separated
kubectl get configmaps -n cloudflare-tunnel

# View static config (managed by ArgoCD)
kubectl get configmap cloudflared-config -n cloudflare-tunnel -o yaml

# View dynamic config (managed by service-controller)
kubectl get configmap cloudflared-ingress-config -n cloudflare-tunnel -o yaml

# Check init container logs for config merging
kubectl logs -n cloudflare-tunnel deployment/cloudflared -c config-merger

# Check service-controller logs
kubectl logs -n cloudflare-tunnel deployment/service-controller
```

## Key Improvements

### 🚀 **Performance Optimizations**
- **Smart restarts**: Only restarts cloudflared when tunnel config actually changes
- **Efficient queries**: Uses label selectors instead of processing all services
- **Config hashing**: Prevents unnecessary updates and restarts

### 🏷️ **Label-Based Configuration**
- **Intuitive labels**: Clear, self-documenting label names
- **Generic design**: Works with any service, not just tunneled ones
- **Scalable**: Easy to add new service types and configurations

### 🔧 **Enhanced Functionality**
- **Dual exposure types**: Supports both public (tunneled) and internal (MetalLB) services
- **Internal DNS support**: Framework for internal DNS management
- **Better error handling**: More robust error handling and logging

### 🛡️ **Security & Reliability**
- **Selective exposure**: Only services with labels are managed
- **No hardcoded tokens**: Secrets managed securely
- **GitOps compatible**: All configuration in version control

## ArgoCD Integration

This setup is designed to work seamlessly with ArgoCD using a **separation of concerns** approach:

### Static vs Dynamic Configuration

1. **Static ConfigMap** (`cloudflared-config`):
   - Managed by ArgoCD from Git
   - Contains base tunnel configuration (tunnel ID, credentials, metrics, logging)
   - Never modified by the service-controller

2. **Dynamic ConfigMap** (`cloudflared-ingress-config`):
   - Managed by the service-controller
   - Contains only ingress rules for services
   - Automatically updated when services are added/removed
   - Labeled with `app.kubernetes.io/managed-by: service-controller`

3. **Config Merging**:
   - Init container merges static and dynamic configs using `yq`
   - Cloudflared uses the merged configuration
   - No GitOps conflicts between ArgoCD and service-controller

### GitOps Workflow

1. **Setup script** creates the secret locally (not in git)
2. **ArgoCD manages** static resources from the repository
3. **Service-controller manages** dynamic ingress rules
4. **No credentials in git** - Secrets are created manually for security
5. **No conflicts** - Each component manages its own resources

The secret is created manually by the setup script and is not managed by ArgoCD to ensure credentials never end up in your repository.