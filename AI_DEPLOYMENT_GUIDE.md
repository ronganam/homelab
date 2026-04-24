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

## 4. App-Specific Operations & Gotchas

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
