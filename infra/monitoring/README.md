# Monitoring Stack

A simple monitoring solution for your homelab using Prometheus and Grafana.

**Location**: `infra/monitoring/` - This is infrastructure that supports all applications in your homelab.

## What's Included

- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Node Exporter** - Node-level metrics (CPU, memory, disk, network)
- **Kube State Metrics** - Kubernetes cluster metrics (pods, deployments, services, etc.)

## Access

After deployment, your monitoring services will be available at:

- **Prometheus**: `http://prometheus.buildin.group` (internal access via MetalLB)
- **Grafana**: `http://grafana.buildin.group` (internal access via MetalLB)
  - Default login: `admin` / `admin`
  - **Change the default password after first login!**

## Features

### Prometheus
- Collects metrics from all Kubernetes components
- Scrapes node metrics from Node Exporter
- Scrapes cluster metrics from Kube State Metrics
- 200-hour data retention (configurable)
- Web UI for querying metrics

### Grafana
- Pre-configured Prometheus datasource
- Ready for custom dashboards
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

- **Prometheus**: 10Gi persistent volume for metrics storage
- **Grafana**: 5Gi persistent volume for dashboards and settings
- Both use Longhorn storage class

## Resource Usage

The monitoring stack is designed to be lightweight:

- **Prometheus**: 512Mi-1Gi memory, 250m-500m CPU
- **Grafana**: 256Mi-512Mi memory, 100m-200m CPU
- **Node Exporter**: 180Mi memory, 100m-200m CPU per node
- **Kube State Metrics**: 190Mi memory, 10m-100m CPU

## Next Steps

1. **Access Grafana** and change the default admin password
2. **Import dashboards** from the Grafana community:
   - Kubernetes Cluster Monitoring: https://grafana.com/grafana/dashboards/7249
   - Node Exporter Full: https://grafana.com/grafana/dashboards/1860
3. **Set up alerts** in Prometheus (optional)
4. **Customize dashboards** for your specific needs

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
