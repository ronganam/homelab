# Cloudflare Tunnel Configuration

This directory contains the Kubernetes manifests for running Cloudflare Tunnel in your homelab cluster.

## Files

- `namespace.yaml` - Creates the `cloudflare-tunnel` namespace
- `cloudflared-deployment.yaml` - Deploys the cloudflared daemon
- `cloudflared-config.yaml` - Tunnel configuration with ingress rules
- `cloudflared-service.yaml` - Service for metrics endpoint
- `cloudflared-secret.yaml` - Template for tunnel credentials
- `kustomization.yaml` - Kustomize configuration

## Setup

Run the setup script:
```bash
./bootstrap/setup-cloudflare.sh
```

This will automatically create the tunnel and configure all credentials.

## Configuration

The tunnel is configured to route traffic to these services:

- `homepage.yourdomain.com` → Homepage dashboard
- `n9n.yourdomain.com` → n8n workflow automation
- `argocd.yourdomain.com` → Argo CD GitOps
- `longhorn.yourdomain.com` → Longhorn storage UI

## Monitoring

Check tunnel status:
```bash
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel deployment/cloudflared
```

Access metrics:
```bash
kubectl port-forward -n cloudflare-tunnel svc/cloudflared 8080:8080
curl http://localhost:8080/metrics
```
