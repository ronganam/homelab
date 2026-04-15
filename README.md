# Homelab GitOps with Argo CD

Welcome to the automated, GitOps-driven Kubernetes homelab repository.

This repository serves as the single source of truth for the cluster, bootstrapping a fully functional environment with minimal manual intervention.

## 🚀 Key Technologies

*   **Argo CD:** Continuous delivery for GitOps. 
*   **MetalLB:** Load balancer providing IPs for internal network access.
*   **Cloudflare Tunnel:** Secure external access without exposing local ports.
*   **Longhorn:** Distributed block storage for applications.
*   **cert-manager:** Automatic Let's Encrypt TLS certificates.
*   **Infisical:** Secret management.
*   **Prometheus & Grafana:** Full monitoring stack and dashboards.

## 📁 Repository Structure

```
.
├── AI_DEPLOYMENT_GUIDE.md   # Extensive AI/Developer instructions for deployments, networking, and apps
├── bootstrap/               # Initial cluster setup scripts and root ApplicationSets
├── infra/                   # Core infrastructure components and services
└── apps/                    # Application definitions and manifests
```

## 🤖 Contributing and Deploying

For all instructions regarding adding new applications, troubleshooting existing components, updating configurations, or configuring the custom Service Controller, please consult the **`AI_DEPLOYMENT_GUIDE.md`**.

That file is designed to help both humans and AI successfully understand the architectural patterns (Blueprint apps, Helm wrappers, manual manifests) and successfully deploy resources.

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
