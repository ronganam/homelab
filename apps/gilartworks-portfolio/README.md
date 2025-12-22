# Gilartworks Portfolio

Portfolio application deployed on Kubernetes.

## Configuration

- **Image**: `registry.buildin.group/gilartworks-portfolio:1.0`
- **Port**: 3000
- **Domain**: https://portfolio.gilartworks.com/
- **Exposure**: Public (via Cloudflare tunnel)

## Environment Variables

- `NODE_ENV`: production
- `ADMIN_PASSWORD`: Set via Kubernetes secret `gilartworks-portfolio-secret`

## Storage

Two persistent volumes are used:
- `gilartworks-portfolio-assets`: 1Gi for assets
- `gilartworks-portfolio-uploads`: 5Gi for uploads

## Setup

1. Create the secret for ADMIN_PASSWORD:
   ```bash
   kubectl create secret generic gilartworks-portfolio-secret \
     --from-literal=admin-password='your-password-here' \
     -n gilartworks-portfolio
   ```

2. Apply the kustomization:
   ```bash
   kubectl apply -k apps/gilartworks-portfolio/kustomization-public.yaml
   ```

## Deployment

This is a public app using Cloudflare tunnel, so no ingress is needed. The service is automatically exposed via the DNS service controller.

