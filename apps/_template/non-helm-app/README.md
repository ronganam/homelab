# Non-Helm App Template

This template shows how to create a non-Helm app for your homelab using Kubernetes manifests.

## Files

- `namespace.yaml` - Kubernetes namespace
- `deployment.yaml` - Application deployment with PVC
- `service-internal.yaml` - Service for internal apps (with ingress)
- `service-public.yaml` - Service for public apps (with Cloudflare tunnel)
- `ingress.yaml` - Ingress for internal apps only
- `kustomization-internal.yaml` - Kustomization for internal apps
- `kustomization-public.yaml` - Kustomization for public apps
- `README.md` - This file

## Usage

### For Internal App (with Ingress)

1. Copy this template to your app directory
2. Replace all `CHANGEME` placeholders with your app name
3. Customize `deployment.yaml` for your app (image, ports, env vars, etc.)
4. Use `service-internal.yaml` as your service
5. Use `kustomization-internal.yaml` as your kustomization
6. The ingress will be automatically included

### For Public App (with Cloudflare Tunnel)

1. Copy this template to your app directory
2. Replace all `CHANGEME` placeholders with your app name
3. Customize `deployment.yaml` for your app (image, ports, env vars, etc.)
4. Use `service-public.yaml` as your service
5. Use `kustomization-public.yaml` as your kustomization
6. No ingress needed

## Key Differences

### Internal Apps
- Use `service-internal.yaml` with `exposure.service-controller.io/type: "internal"`
- Include `ingress.yaml` in kustomization
- Accessible via internal domain + ingress
- Example: `speakr.buildin.group`

### Public Apps
- Use `service-public.yaml` with `exposure.service-controller.io/type: "public"`
- No ingress needed
- Accessible via public domain through Cloudflare tunnel
- Example: `n9n.buildin.group`

## DNS Management

Both internal and public apps use the DNS service controller labels:
- `dns.service-controller.io/enabled: "true"`
- `dns.service-controller.io/hostname: "your.domain.com"`
- `exposure.service-controller.io/type: "internal"` or `"public"`

## Storage

All apps use Longhorn storage class for persistent volumes.

## Security

The deployment includes security context with:
- `runAsUser: 1000`
- `runAsGroup: 1000`
- `fsGroup: 1000`
- `fsGroupChangePolicy: OnRootMismatch`

Adjust these values as needed for your application.

## Homepage Integration

### Automatic Service Discovery

Internal non-Helm apps are automatically discovered by Homepage when they have the required annotations in their ingress. The template includes these annotations in `ingress.yaml`.

### Resource Monitoring

The deployment template includes proper Kubernetes labels for CPU and memory monitoring:

```yaml
labels:
  app: service-name
```

### Public Apps

Public apps (using Cloudflare tunnel) don't have ingresses, so they need to be manually added to Homepage's `services.yaml` configuration.

### Configuration

The template includes Homepage annotations in the ingress configuration:

```yaml
annotations:
  gethomepage.dev/enabled: "true"
  gethomepage.dev/name: "Service Name"
  gethomepage.dev/description: "Service Description"
  gethomepage.dev/icon: "icon-name.png"
  gethomepage.dev/group: "Applications"
  gethomepage.dev/weight: "10"
```
