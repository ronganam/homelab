# Service Controller for Homelab

This is a comprehensive service management solution for your homelab that handles both **public (tunneled)** and **internal (MetalLB)** service exposure with **label-based configuration**.

## What's Included

- **Service Controller** - Generic controller that manages both tunneled and internal services
- **Label-based control** - Clean, intuitive labels for service configuration
- **Automatic DNS management** - Handles both public and internal DNS entries
- **Dynamic DNS (DDNS)** - Automatically keeps a DNS record pointing to your public IP
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
4. **DDNS** periodically checks and updates a DNS record to point to your current public IP
5. **Smart restarts** only occur when tunnel configuration actually changes
6. **Efficient queries** use label selectors for optimal performance

## Dynamic DNS (DDNS)

The service controller includes built-in DDNS functionality that automatically keeps a DNS A record pointing to your homelab's current public IP address. This is useful for:

- Direct access to your homelab without going through the Cloudflare tunnel
- VPN connections that need to know your public IP
- Any service that requires your actual public IP address

### Configuration

DDNS is configured via environment variables in the service-controller deployment:

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `DDNS_ENABLED` | `"false"` | Set to `"true"` to enable DDNS |
| `DDNS_HOSTNAME` | `""` | The hostname to update (e.g., `homelab.example.com`) |

### Current Configuration

```yaml
env:
  - name: DDNS_HOSTNAME
    value: homelab.buildin.group
  - name: DDNS_ENABLED
    value: "true"
```

### How It Works

1. **Periodic checks** - Every 5 minutes (configurable via `RECONCILE_INTERVAL_SEC`), the controller checks your public IP
2. **Multiple IP services** - Uses multiple fallback services for reliability:
   - `api.ipify.org`
   - `ifconfig.me`
   - `icanhazip.com`
   - `checkip.amazonaws.com`
   - `api.my-ip.io`
3. **Efficient updates** - Only updates Cloudflare when the IP actually changes
4. **CNAME handling** - Automatically replaces conflicting CNAME records with A records
5. **Initial sync** - Runs immediately on startup, then periodically

### Monitoring DDNS

Check DDNS status in the controller logs:

```bash
kubectl logs -n cloudflare-tunnel deployment/service-controller | grep DDNS
```

Example log output:
```
DDNS: homelab.buildin.group already points to 203.0.113.42 (no change needed)
DDNS: IP changed from 203.0.113.42 to 198.51.100.23, updating homelab.buildin.group
DDNS: Successfully updated homelab.buildin.group -> 198.51.100.23
```

### Disabling DDNS

To disable DDNS, set the environment variable:

```yaml
- name: DDNS_ENABLED
  value: "false"
```

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
- **ArgoCD conflicts?** Verify that the `ignoreDifferences` configuration is present in the ApplicationSet
- **DDNS not updating?** Check that `DDNS_ENABLED=true` and verify Cloudflare API token has DNS edit permissions

### Debugging Commands

```bash
# Check ConfigMap and its annotations
kubectl get configmap cloudflared-config -n cloudflare-tunnel -o yaml

# Check service-controller logs
kubectl logs -n cloudflare-tunnel deployment/service-controller

# Check cloudflared logs
kubectl logs -n cloudflare-tunnel deployment/cloudflared

# Check which services have DNS management enabled
kubectl get services --all-namespaces -l dns.service-controller.io/enabled=true
```

## Key Improvements

### 🚀 **Performance Optimizations**
- **No unnecessary restarts**: cloudflared automatically reloads config when ConfigMap changes
- **Efficient queries**: Uses label selectors instead of processing all services
- **Config hashing**: Prevents unnecessary updates
- **Limited revision history**: Prevents ReplicaSet accumulation

### 🏷️ **Label-Based Configuration**
- **Intuitive labels**: Clear, self-documenting label names
- **Generic design**: Works with any service, not just tunneled ones
- **Scalable**: Easy to add new service types and configurations

### 🔧 **Enhanced Functionality**
- **Dual exposure types**: Supports both public (tunneled) and internal (MetalLB) services
- **Internal DNS support**: Framework for internal DNS management
- **Dynamic DNS (DDNS)**: Automatically tracks and updates public IP changes
- **Better error handling**: More robust error handling and logging

### 🛡️ **Security & Reliability**
- **Selective exposure**: Only services with labels are managed
- **No hardcoded tokens**: Secrets managed securely
- **GitOps compatible**: All configuration in version control

## ArgoCD Integration

This setup is designed to work with ArgoCD using the **ignoreDifferences** feature:

### GitOps Conflict Resolution

The `cloudflared-config` ConfigMap is managed by ArgoCD but the service-controller can modify it without conflicts using ArgoCD's `ignoreDifferences` configuration in the ApplicationSet:

```yaml
# In bootstrap/root-applicationsets.yaml
spec:
  ignoreDifferences:
  - group: ""
    kind: ConfigMap
    name: cloudflared-config
    jsonPointers:
    - /data/config.yaml
```

This configuration tells ArgoCD:
- **Ignore changes** to the `config.yaml` data field in the `cloudflared-config` ConfigMap
- **Allow service-controller** to modify the ConfigMap content
- **Don't override** changes made by the service-controller during sync

### GitOps Workflow

1. **Setup script** creates the secret locally (not in git)
2. **ArgoCD manages** the ConfigMap from Git but ignores content changes
3. **Service-controller** can modify the ConfigMap without conflicts
4. **No credentials in git** - Secrets are created manually for security
5. **Clean solution** - Uses ArgoCD's built-in ignoreDifferences feature

The secret is created manually by the setup script and is not managed by ArgoCD to ensure credentials never end up in your repository.