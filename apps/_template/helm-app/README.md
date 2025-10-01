# Helm App Template

This template shows how to create a Helm-based app for your homelab.

## Files

- `Chart.yaml` - Helm chart definition with upstream dependency
- `app.yaml` - Argo CD application configuration
- `values-internal.yaml` - Values for internal app (accessible via ingress)
- `values-public.yaml` - Values for public app (accessible via Cloudflare tunnel)
- `README.md` - This file

## Usage

### For Internal App (with Ingress)

1. Copy this template to your app directory
2. Replace all `CHANGEME` placeholders with your app name
3. Update the upstream chart information in `Chart.yaml`
4. Customize `values-internal.yaml` for your app
5. Use `values-internal.yaml` as your values file

### For Public App (with Cloudflare Tunnel)

1. Copy this template to your app directory
2. Replace all `CHANGEME` placeholders with your app name
3. Update the upstream chart information in `Chart.yaml`
4. Customize `values-public.yaml` for your app
5. Use `values-public.yaml` as your values file

## Key Differences

### Internal Apps
- Use `exposure.service-controller.io/type: "internal"`
- Have `ingress.enabled: true`
- Accessible via internal domain + ingress
- Example: `pdf.buildin.group`

### Public Apps
- Use `exposure.service-controller.io/type: "public"`
- Have `ingress.enabled: false`
- Accessible via public domain through Cloudflare tunnel
- Example: `n9n.buildin.group`

## DNS Management

Both internal and public apps use the DNS service controller labels:
- `dns.service-controller.io/enabled: "true"`
- `dns.service-controller.io/hostname: "your.domain.com"`
- `exposure.service-controller.io/type: "internal"` or `"public"`

## Storage

All apps use Longhorn storage class for persistent volumes.

## Homepage Integration

### Automatic Service Discovery

Internal Helm apps are automatically discovered by Homepage when they have the required annotations in their ingress. The template includes these annotations in `values-internal.yaml`.

### Resource Monitoring

For CPU and memory monitoring, ensure your Helm chart supports the standard Kubernetes labels:

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
: "internal"
```
