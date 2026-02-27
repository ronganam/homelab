# ConvertX

A free and open-source web-based tool for file conversion.

## Deployment

This application is deployed using Kubernetes manifests.

### Files

- `namespace.yaml` - Kubernetes namespace
- `deployment.yaml` - Application deployment with PVC
- `service-internal.yaml` - Internal service
- `ingress.yaml` - Ingress for internal access (`convertx.ganam.app`)
- `kustomization.yaml` - Kustomization for the application

## Configuration

- **Image:** `ghcr.io/c4illin/convertx:latest`
- **Port:** 3000
- **Storage:** 2Gi PVC (Longhorn)
- **Authentication:** Unauthenticated access enabled (`ALLOW_UNAUTHENTICATED=true`)
- **HTTP:** Enabled for internal traffic (`HTTP_ALLOWED=true`)

## Access

Internally accessible at: `https://convertx.ganam.app`
