# Homelab App Templates

This directory contains templates for creating new apps in your homelab.

## Template Types

### 1. Blueprint App (`blueprint-app/`) -- Recommended

Use this for most apps. It uses the reusable `charts/app-blueprint` Helm chart, so each app only needs **2 files**: `Chart.yaml` and `values.yaml`.

The blueprint handles namespace, deployment, PVC, service, ingress, infisical secrets, and homepage annotations automatically.

**Quick start:**
1. Copy `blueprint-app/` to `apps/<your-app-name>/`
2. Replace all `CHANGEME` placeholders in both files
3. Remove any sections you don't need (volumes, infisical, etc.)

**What you specify in values.yaml:**
- Image and tag
- Container port
- DNS hostname and exposure type (internal/public)
- Homepage dashboard info
- Persistent volumes
- Environment variables
- Infisical secret path (optional)

**Examples in your homelab:**
- `papra/` - Internal app with infisical secrets
- `convertx/` - Internal app with storage
- `gilartworks-soon/` - Minimal public app (no storage)
- `gilartworks-portfolio/` - Public app with 2 PVCs + infisical
- `registry/` - Internal app with custom ingress annotations
- `n8n/` - Public app with storage

### 2. Helm Wrapper (`helm-app/`)

Use this only for apps that have an **upstream Helm chart** you want to wrap.

**Files:** `Chart.yaml`, `values.yaml`

**Examples in your homelab:**
- `stirling-pdf/` - Wraps upstream Stirling-PDF chart
- `frigate/` - Wraps upstream Frigate chart
- `pihole/` - Wraps upstream Pi-hole chart

### 3. Custom Manifests (`non-helm-app/`)

Use this only for complex apps that need resources beyond what the blueprint supports (StatefulSets, multiple deployments, GPU, RBAC, CronJobs, etc.).

**Examples in your homelab:**
- `bitwarden/` - StatefulSet with backup CronJob
- `speakr/` - Multiple deployments (app + ASR)
- `jellyfin/` - GPU passthrough, multiple PVC types
- `homepage/` - RBAC, ConfigMap-heavy

## Access Types

### Internal Apps
- **Access**: Via internal domain + nginx ingress
- **DNS label**: `exposure.service-controller.io/type: "internal"`
- **Example domains**: `app.ganam.app`, `app.buildin.group`

### Public Apps
- **Access**: Via public domain through Cloudflare tunnel
- **DNS label**: `exposure.service-controller.io/type: "public"`
- **No ingress needed**
- **Example domains**: `app.yourdomain.com`

## Conventions

- **Storage**: Longhorn storage class for all persistent volumes
- **DNS**: Labels on services for automatic DNS management
- **Homepage**: Annotations on ingress for automatic dashboard discovery
- **Secrets**: Infisical operator for secret management
