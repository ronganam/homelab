# Metrics Server

A Kubernetes metrics server implementation for resource usage metrics collection.

**Location**: `infra/metrics-server/` - This is infrastructure that supports all applications in your homelab.

## What's Included

- **Metrics Server** - Resource usage metrics collection for Kubernetes API
- **Automatic Deployment** - Deployed via ArgoCD from official Kubernetes SIGs repository
- **Proper Configuration** - Configured with necessary flags for homelab environment

## Access

The metrics-server runs in the `kube-system` namespace and provides metrics to the Kubernetes API server.

## Features

### Metrics Server
- Collects resource usage metrics from all nodes and pods
- Provides metrics to Kubernetes API server for `kubectl top` commands
- Essential for horizontal pod autoscaling (HPA)
- Required for resource-based scheduling decisions

## Configuration

The metrics-server is configured with the following flags:
- `--kubelet-insecure-tls` - Allows insecure TLS connections to kubelets
- `--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname` - Preferred address types for kubelet connections

## ArgoCD Integration

This metrics-server follows the **proper ArgoCD way** to deploy infrastructure:

### **How It Works:**
- **ArgoCD Application** directly references the official Kubernetes SIGs repository
- **Kustomize patches** customize the deployment for your homelab environment
- **GitOps workflow** - changes trigger automatic updates
- **Automatic sync** - ArgoCD keeps the deployment in sync

### **Benefits:**
- **Official source** - uses the official Kubernetes SIGs metrics-server repository
- **No manual configuration** - everything is pre-configured
- **Proper networking** - configured for homelab environment
- **GitOps native** - all configuration is in version control
- **Easy updates** - ArgoCD handles updates automatically

## Troubleshooting

### Check if metrics-server is running:
```bash
kubectl get pods -n kube-system | grep metrics-server
```

### View logs:
```bash
kubectl logs -n kube-system deployment/metrics-server
```

### Test metrics collection:
```bash
kubectl top nodes
kubectl top pods --all-namespaces
```

### Check API availability:
```bash
kubectl get apiservice v1beta1.metrics.k8s.io
```
