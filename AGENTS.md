# Homelab GitOps — Agent Guide

Single-node Kubernetes homelab. Argo CD GitOps, Cloudflare tunnels for public access, MetalLB for internal IPs.

## Architecture in 30 seconds

```
apps/     → 37 application deployments (blueprint Helm charts, upstream Helm wrappers, raw manifests)
infra/    → 15 infrastructure components (Argo CD, MetalLB, cert-manager, monitoring, etc.)
bootstrap/→ Cluster init: Argo CD install + root ApplicationSets
scripts/  → Resource optimization tooling
```

- **Domain:** `ganam.app`, `buildin.group`, `gilartworks.com`
- **Wildcard TLS:** cert-manager DNS-01 via Cloudflare → `*.ganam.app` etc.
- **Ingress:** Envoy Gateway (Gateway API) on MetalLB IP `192.168.1.178`
- **Public access:** Cloudflare Tunnel + custom Service Controller watches K8s Service labels

## How Apps Are Discovered

Argo CD ApplicationSets auto-discover from directory structure:

| ApplicationSet | Path pattern | Excludes |
|---|---|---|
| `apps` | `apps/*` | `apps/_template`, `apps/_blueprint` |
| `infra` | `infra/*/app.yaml` | — |

- **Apps:** Namespace = directory basename. Each directory is one ArgoCD Application.
- **Infra:** Requires `infra/<name>/app.yaml` with fields `name`, `namespace`, `path`, and optional `wave` (controls deploy order: 1→50).

## Three App Patterns

### 1. Blueprint App (preferred for simple apps)
- `apps/<name>/Chart.yaml` + `apps/<name>/values.yaml`
- Depends on `apps/_blueprint` chart (`file://../_blueprint`)
- Handles: Deployment, Service, DNS labels, PVCs, Infisical secrets, Homepage annotations
- Template at `apps/_template/blueprint-app/`

### 2. Helm Wrapper (upstream charts)
- `apps/<name>/Chart.yaml` (with `dependencies:` to upstream repo) + `values.yaml` + `app.yaml`
- Example: `apps/frigate`, `apps/infisical`, `infra/monitoring`
- Infra components using this pattern also need `infra/<name>/app.yaml` for ApplicationSet discovery

### 3. Custom Manifests (complex apps)
- `apps/<name>/kustomization.yaml` + raw YAML files
- Example: `apps/bitwarden`, `apps/homepage`

## DNS / Exposure via Service Controller

The Service Controller (`infra/cloudflare-tunnel`) watches K8s Services for labels:

```
dns.service-controller.io/enabled: "true"
dns.service-controller.io/hostname: "<app>.ganam.app"
exposure.service-controller.io/type: "internal" | "public"
```

- **Internal:** MetalLB `LoadBalancer` → DNS A record pointing to MetalLB IP
- **Public:** `ClusterIP` + Cloudflare Tunnel → DNS CNAME to `<tunnel-uuid>.cfargotunnel.com`
- Blueprint apps set these via `dns.hostname` and `dns.exposure` in values
- Homepage only auto-discovers **internal** apps (those with Ingress); public apps need manual `services.yaml` entries

## Key Commands

```bash
# Bootstrap (first cluster setup)
bash bootstrap/install-argocd.sh        # Install Argo CD + apply root ApplicationSets
bash setup-cloudflare.sh                # Create tunnel + secrets + deploy service controller

# Resource optimization (re-tune CPU/memory based on Grafana metrics)
export GRAFANA_URL="https://grafana.ganam.app" GRAFANA_TOKEN=""
python3 scripts/optimize_resources.py --lookback 48

# Infisical secrets setup
bash apps/infisical/create-secret.sh

# Vaultwarden restic backup credentials
bash apps/bitwarden/setup-oci-restic-secret.sh
```

## Conventions

- **Blueprint values** go under the `app-blueprint:` key in `values.yaml` (not at root)
- **Blueprint Chart.yaml** dependency must be `repository: "file://../_blueprint"`
- **Image registries:** `registry.ganam.app/<app>` (self-hosted) or `ghcr.io/<org>/<app>`
- **Default StorageClass:** `local-path` (Local Path Provisioner)
- **Secrets:** Prefer Infisical integration; static K8s secrets only where required
- **GPU pods:** Must set `runtimeClassName: nvidia`, `nvidia.com/gpu.present: "true"` node selector, and `nvidia.com/gpu: 1` resource limit
- **Git commit style:** `chore(<app>): deploy version X.Y.Z` for version bumps, `feat:` / `fix:` for functional changes
- **Renovate:** Auto-merges minor/patch Docker updates; Helm/Kubernetes updates on weekly schedule

## Gotchas

- `Chart.lock` and `charts/` directories are `.gitignore`d — Helm dependencies are resolved at sync time
- `apps/_template/` and `apps/_blueprint/` are excluded from Argo CD discovery; do not deploy them directly
- Argo CD auto-sync is **disabled** per default; only `syncOptions` are set in ApplicationSets
- Cloudflare Tunnel reconciles config by hashing the entire `cloudflared-config` ConfigMap; triggering rollout on change
- `live.yaml` and `target.yaml` at repo root are exported K8s resources (not source manifests)

## Further Reading

`AI_DEPLOYMENT_GUIDE.md` — detailed architecture, app patterns, DNS labeling, app-specific ops (Bitwarden, Infisical, GPU, Homepage).
