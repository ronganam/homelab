# AI Deployment & Architecture Guide

This guide is designed for AI agents and developers to understand the GitOps structure, naming conventions, and deployment procedures for this homelab repository.

## 1. Architectural Overview
This homelab uses **Argo CD** for GitOps-driven deployments on a Kubernetes cluster. 

*   **Ingress & Routing:** 
    *   **Internal:** NGINX Ingress LoadBalancer (provided by MetalLB) + cert-manager (wildcard certs via DNS-01 on Cloudflare).
    *   **Public:** Cloudflare Tunnels (no open ports).
*   **DNS Automation:** Managed by a custom **Service Controller** (`infra/cloudflare-tunnel`). It observes Services for labels and automatically configures Cloudflare DNS and Tunnels.
*   **Storage:** **Local-Path-Provisioner** is the default StorageClass (`local-path`). It provides high-performance node-local storage suitable for single-node clusters.
*   **Secret Management:** **Infisical** is used via an Infisical Operator (or static K8s secrets where required).

## 2. App Deployment Patterns
All applications live under `apps/` and infrastructure components under `infra/`. 
ArgoCD ApplicationSets automatically discover directories based on structure.

There are three primary ways to deploy applications:

### A. Blueprint App (Recommended)
Uses the reusable `charts/app-blueprint` Helm chart. This requires only 2 files (`Chart.yaml` and `values.yaml`) to handle Deployments, Services, Ingress, PVCs, Infisical secrets, and Homepage annotations.
*   **Structure:** `apps/<name>/Chart.yaml` and `apps/<name>/values.yaml`.
*   **What you configure:** Image tag, ports, hostname exposure type, persistent volume specs, env variables, or Infisical references.

### B. Helm Wrapper
Used to wrap public upstream helm charts (e.g., `monitoring`, `argocd`).
*   **Structure:** `apps/<name>/helm/` containing `Chart.yaml` (with dependency), `values.yaml`, and `namespace.yaml` / `kustomization.yaml`.

### C. Custom Manifests (Non-Helm)
Used for complex setups (StatefulSets, GPUs, multiple deployments like `bitwarden` or `jellyfin`).
*   **Structure:** `apps/<name>/kustomization.yaml`, `deployment.yaml`, `service.yaml`, etc.

## 3. Network & DNS Labeling (Service Controller)
To expose your service, attach the following labels to your Kubernetes `Service` object (handled natively by the Blueprint app's values):

### Internal Apps (accessible on local network)
*   **Labels:**
    *   `dns.service-controller.io/enabled: "true"`
    *   `dns.service-controller.io/hostname: "<app>.ganam.app"`
    *   `exposure.service-controller.io/type: "internal"`
*   **Service Type:** `LoadBalancer` (MetalLB assigns an IP, wildcard cert applies).

### Public Apps (accessible over the internet)
*   **Labels:**
    *   `dns.service-controller.io/enabled: "true"`
    *   `dns.service-controller.io/hostname: "<app>.yourdomain.com"`
    *   `exposure.service-controller.io/type: "public"`
*   **Service Type:** `ClusterIP` (traffic runs securely through the Cloudflare Tunnel without an ingress).

### Blueprint options worth knowing
*   `dns.extraHostnames: ["*.myapp.ganam.app"]` — more hostnames for the same app (added to the HTTPRoute **and** to the Service annotation `dns.service-controller.io/extra-hostnames`, which the Service Controller turns into DNS records; wildcards allowed, internal exposure only). Needed for apps with one subdomain per tenant.
*   `database.superuserAccess: true` (+ optional `database.superuserSecret`) — enables CloudNativePG's `postgres` superuser, for apps whose migrations create roles or rely on `SECURITY DEFINER` functions bypassing row-level security.
*   `database` + `cache` can be combined with the main workload (`enabled: true`); the cache pod gets its own selector so the app Service never routes to it. (Cache-only use via `enabled: false` is unchanged.)
*   Multiple containers in one pod: `initContainers` / `extraContainers` (repeat `envFrom`, `volumeMounts`, `resources`, `securityContext` per container); a pod-level volume from `volumes:` is visible to all of them.

### Multi-tenant apps (one subdomain per tenant)
The shared certificate `*.ganam.app` covers **one** label, so `tenant.myapp.ganam.app` needs its own wildcard certificate + listener:
1.  `infra/gateway/<app>-certificate.yaml` — a `Certificate` for `*.myapp.ganam.app` (issuer `letsencrypt-dns01`) in `gateway-system`.
2.  A hostname-specific listener in `infra/gateway/gateway.yaml` (`hostname: "*.myapp.ganam.app"`, own `certificateRefs`). It is additive: the existing `https` listener and certificate are untouched.
3.  `dns.extraHostnames: ["*.myapp.ganam.app"]` in the app values (creates the wildcard DNS record).
See `apps/gymote` for a complete example.

## 4. App-Specific Operations & Gotchas

### GYMote (multi-tenant personal-trainer app)
*   **Layout:** one pod = `gymote` (Caddy: static PWA + proxy, the only exposed port) + `api` + `worker` sidecars sharing the media volume; Postgres via CloudNativePG (`gymote-db`), Valkey (`gymote-cache`). Images: `registry.ganam.app/gymote-api` and `gymote-web` (built from the app repo with `--build-arg CADDYFILE=deploy/Caddyfile.k8s`).
*   **Before the first sync:** run `apps/gymote/create-secret.sh` (idempotent; never rotates existing passwords or VAPID keys). Without `SMTP_URL`, emails queue in `email_outbox` and are not sent.
*   **Hostnames:** platform `gymote.ganam.app`; tenants `<slug>.gymote.ganam.app` (wildcard cert + listener in `infra/gateway`).
*   **Migrations** run as an init container using the Postgres superuser and are idempotent.
*   **Operations** (run inside the `api` container): `kubectl -n gymote exec deploy/gymote -c api -- node dist/db/create-admin.js <email>` (operator + 2FA), `create-tenant.js`, `set-password.js`, `legacy/import.js`.

### Bitwarden / Vaultwarden
*   **Secrets:** Generates hashes for admin via `docker run --rm vaultwarden/server:1.34.3 vaultwarden hash`. Put token in `vaultwarden-admin` secret.
*   **Backups:** Scheduled SQLite backup with `restic` to OCI Object Storage via CronJob. 
*   **Setup Script:** Run `apps/bitwarden/setup-oci-restic-secret.sh` manually to configure the restic credentials.



### Cloudflare Tunnel & DDNS
*   **DDNS:** The Service Controller has DDNS built-in, tracking the public IP and updating Cloudflare A records. Can be toggled via `DDNS_ENABLED`.
*   **Setup:** Use `bootstrap/setup-cloudflare.sh` to initialize Cloudflare credentials prior to ArgoCD deploying the tunneled services.

### Infisical
*   Before deploying, run `apps/infisical/create-secret.sh` to generate the underlying encryption keys and postgres/redis credentials locally.

### Excalidraw
*   Requires a K8s secret named `excalidraw-secrets` holding `JWT_SECRET` and `CSRF_SECRET` or it will use rotating ephemeral defaults.

### NVIDIA Device Plugin (GPU Passthrough)
*   Pods requesting GPUs must use `runtimeClassName: nvidia` and the node selector `nvidia.com/gpu.present: "true"`.
*   Also required: resources limit `nvidia.com/gpu: 1`.

### Homepage
*   **Discovery:** Internal applications with Ingress entries and `gethomepage.dev/...` annotations are automatically picked up.
*   **Manual:** Public applications (which lack Ingress objects due to Tunnel design) must be manually added to Homepage's configuration (`services.yaml`).
