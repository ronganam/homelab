# Cloudflare Tunnel DNS Management

This directory contains the namespace for external-dns, but since we're using Cloudflare Tunnel, external-dns is not needed.

## How It Works

**Cloudflare Tunnel** automatically handles DNS records for your services. When you configure hostnames in the tunnel configuration, Cloudflare automatically creates the necessary DNS records.

## Current Setup

We use **Cloudflare Tunnel** (cloudflared) which:
- Automatically creates DNS records for configured hostnames
- Routes traffic through Cloudflare's network
- Provides DDoS protection and CDN features
- Eliminates the need for external-dns

## Configuration

DNS records are managed through the Cloudflare Tunnel configuration in `/infra/cloudflare-tunnel/cloudflared-config.yaml`:

```yaml
ingress:
  - hostname: homepage.buildin.group
    service: http://homepage.homepage.svc.cluster.local:3000
  - hostname: n9n.buildin.group
    service: http://n8n.n8n.svc.cluster.local:5678
  - hostname: argocd.buildin.group
    service: http://argocd-server.argocd.svc.cluster.local:80
  - hostname: longhorn.buildin.group
    service: http://longhorn-frontend.longhorn-system.svc.cluster.local:80
```

## Benefits

- **Automatic DNS Management**: Cloudflare Tunnel creates DNS records automatically
- **No External Dependencies**: No need for external-dns or LoadBalancer services
- **Cloudflare Features**: Built-in DDoS protection, CDN, and security features
- **Simple Configuration**: Just configure hostnames in tunnel config

## Monitoring

Check Cloudflare Tunnel status:
```bash
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel deployment/cloudflared
```

View DNS records in Cloudflare dashboard or via API.
