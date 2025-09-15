# Monitoring Stack

A comprehensive monitoring solution for your homelab using the **kube-prometheus-stack** Helm chart.

**Location**: `infra/monitoring/` - This is infrastructure that supports all applications in your homelab.

## What's Included

- **Prometheus** - Metrics collection and storage with pre-configured scraping
- **Grafana** - Visualization with 20+ pre-configured dashboards
- **Node Exporter** - Node-level metrics (CPU, memory, disk, network)
- **Kube State Metrics** - Kubernetes cluster metrics (pods, deployments, services, etc.)
- **Service Monitors** - Automatic discovery and monitoring of your homelab services

## Access

After deployment, your monitoring services will be available at:

- **Prometheus**: `http://prometheus.buildin.group` (internal access via MetalLB)
- **Grafana**: `http://grafana.buildin.group` (internal access via MetalLB)
  - Default login: `admin` / `admin`
  - **Change the default password after first login!**

## Features

### Prometheus
- Collects metrics from all Kubernetes components automatically
- Scrapes node metrics from Node Exporter
- Scrapes cluster metrics from Kube State Metrics
- **Automatic service discovery** for your homelab applications
- 200-hour data retention (configurable)
- Web UI for querying metrics

### Grafana
- **Pre-configured Prometheus datasource** (no manual setup needed)
- **20+ pre-configured dashboards** including:
  - Kubernetes Cluster Overview
  - Node Exporter Full
  - Kubernetes Pod Monitoring
  - Kubernetes Deployment State
  - And many more!
- Persistent storage for dashboards and settings
- Plugin support (pie chart, world map panels included)

### Node Exporter
- Runs as DaemonSet on all nodes
- Collects system metrics (CPU, memory, disk, network)
- Exposes metrics on port 9100

### Kube State Metrics
- Exposes Kubernetes object state as metrics
- Tracks pods, deployments, services, nodes, etc.
- Essential for cluster monitoring dashboards

## Storage

- **Prometheus**: 2Gi persistent volume for metrics storage
- **Grafana**: 1Gi persistent volume for dashboards and settings
- Both use Longhorn storage class

## Resource Usage

The monitoring stack is designed to be lightweight:

- **Prometheus**: 512Mi-1Gi memory, 250m-500m CPU
- **Grafana**: 256Mi-512Mi memory, 100m-200m CPU
- **Node Exporter**: 180Mi memory, 100m-200m CPU per node
- **Kube State Metrics**: 190Mi memory, 10m-100m CPU

## Next Steps

1. **Access Grafana** and change the default admin password
2. **Explore pre-configured dashboards** - they're already imported and working!
3. **Check the "Kubernetes Cluster Overview" dashboard** for a complete cluster view
4. **Set up alerts** in Prometheus (optional)
5. **Customize dashboards** for your specific needs

## ArgoCD + Helm Integration

This monitoring stack follows **Helm best practices** and the **proper ArgoCD way** to deploy Helm charts:

### **How It Works:**
- **ArgoCD Application** directly references the Helm chart repository
- **Clean, organized Helm values** embedded in the Application manifest
- **No manual Helm commands** - ArgoCD handles everything
- **GitOps workflow** - changes to the Application manifest trigger updates
- **Automatic sync** - ArgoCD keeps the deployment in sync

### **Benefits:**
- **Simple and maintainable** - following [Helm Chart Template Guide](https://helm.sh/docs/chart_template_guide/getting_started/) best practices
- **No manual configuration** - everything is pre-configured
- **Automatic service discovery** - your homelab services are automatically monitored
- **Pre-configured dashboards** - no need to import manually
- **Proper networking** - Prometheus and Grafana communicate correctly
- **GitOps native** - all configuration is in version control
- **Easy updates** - modify the Application manifest and ArgoCD handles the rest

### **File Structure:**
```
infra/monitoring/
├── namespace.yaml              # Namespace definition
├── monitoring-application.yaml # ArgoCD Application with Helm values
├── kustomization.yaml         # Kustomize configuration
└── README.md                  # This documentation
```

This follows the **Helm principle** of keeping things simple and maintainable while leveraging ArgoCD's GitOps capabilities.

## Troubleshooting

### Check if monitoring is running:
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

### View logs:
```bash
kubectl logs -n monitoring deployment/prometheus
kubectl logs -n monitoring deployment/grafana
```

### Permission Issues (Fixed)
If you see permission errors like "permission denied" or "not writable":
- The manifests include init containers that fix permissions automatically
- Prometheus runs as user 65534 (nobody)
- Grafana runs as user 472 (grafana)
- Both use proper security contexts and fsGroup settings

### Check Prometheus targets:
1. Go to `http://prometheus.buildin.group`
2. Click "Status" → "Targets"
3. Verify all targets are "UP"

### Check Grafana datasource:
1. Go to `http://grafana.buildin.group`
2. Login with admin/admin
3. Go to "Configuration" → "Data Sources"
4. Verify Prometheus datasource is working
