# Homelab App Templates

This directory contains templates for creating new apps in your homelab. Choose the appropriate template based on your needs.

## Template Types

### 1. Helm App Template (`helm-app/`)
Use this for apps that have upstream Helm charts available.

**Files:**
- `Chart.yaml` - Helm chart definition
- `app.yaml` - Argo CD application configuration
- `values-internal.yaml` - Values for internal apps (with ingress)
- `values-public.yaml` - Values for public apps (with Cloudflare tunnel)
- `README.md` - Detailed usage instructions

**Examples in your homelab:**
- `stirling-pdf/` - Internal Helm app

### 2. Non-Helm App Template (`non-helm-app/`)
Use this for apps that need custom Kubernetes manifests.

**Files:**
- `namespace.yaml` - Kubernetes namespace
- `deployment.yaml` - Application deployment with PVC
- `service-internal.yaml` - Service for internal apps
- `service-public.yaml` - Service for public apps
- `ingress.yaml` - Ingress for internal apps only
- `kustomization-internal.yaml` - Kustomization for internal apps
- `kustomization-public.yaml` - Kustomization for public apps
- `README.md` - Detailed usage instructions

**Examples in your homelab:**
- `speakr/` - Internal non-Helm app
- `n8n/` - Public non-Helm app

## Access Types

### Internal Apps
- **Access**: Via internal domain + ingress
- **DNS**: `exposure.service-controller.io/type: "internal"`
- **Ingress**: Required (nginx ingress class)
- **Example domains**: `app.buildin.group`

### Public Apps
- **Access**: Via public domain through Cloudflare tunnel
- **DNS**: `exposure.service-controller.io/type: "public"`
- **Ingress**: Not needed (uses Cloudflare tunnel)
- **Example domains**: `app.yourdomain.com`

## Quick Start

1. **Choose your template type** (Helm or Non-Helm)
2. **Choose your access type** (Internal or Public)
3. **Copy the template** to your app directory
4. **Replace all `CHANGEME` placeholders** with your app name
5. **Customize the configuration** for your app
6. **Use the appropriate kustomization file**

## DNS Management

All apps use the DNS service controller with these labels:
- `dns.service-controller.io/enabled: "true"`
- `dns.service-controller.io/hostname: "your.domain.com"`
- `exposure.service-controller.io/type: "internal"` or `"public"`

## Storage

All apps use Longhorn storage class for persistent volumes.

## Security

Non-Helm apps include security context with proper user/group settings. Helm apps should configure security context in their values files.
