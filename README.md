# Homelab GitOps with Argo CD

A complete, ready-to-deploy homelab setup using GitOps principles with Argo CD. This repository bootstraps a fully functional Kubernetes homelab environment with minimal manual intervention.

## 🚀 Quick Start

### Prerequisites

- A running Kubernetes cluster (k3s, k8s, kind, etc.)
- `kubectl` configured to access your cluster
- Git repository hosting (GitHub, GitLab, etc.)
- Cloudflare account with a domain (for secure external access)

### Bootstrap Steps

1. **Clone this repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
   cd YOUR_REPO
   ```

2. **Update the repository URLs:**
   Edit `bootstrap/root-applicationsets.yaml` and replace all instances of:
   - `https://github.com/YOUR_USERNAME/YOUR_REPO.git` with your actual repository URL

3. **Configure MetalLB IP range:**
   Edit `infra/metallb/address-pool.yaml` and update the IP address range to match your network:
   ```yaml
   addresses:
   - 192.168.1.200-192.168.1.250  # Change this to your network range
   ```

4. **Deploy Argo CD and ApplicationSets:**
   ```bash
   # Create Argo CD namespace
   kubectl create namespace argocd

   # Install Argo CD
   kubectl apply -n argocd -f bootstrap/argocd-install.yaml

   # Wait for Argo CD to be ready
   kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

   # Deploy the ApplicationSets (app-of-apps pattern)
   kubectl apply -n argocd -f bootstrap/root-applicationsets.yaml
   ```

5. **Set up Cloudflare Tunnel (Recommended for secure external access):**
   ```bash
   # Run the setup script
   ./bootstrap/setup-cloudflare.sh
   
   # This will:
   # - Create a Cloudflare tunnel
   # - Set up External-DNS for automatic DNS management
   # - Configure all credentials and settings
   # - Update all configurations with your domain
   ```

6. **Access your services:**
   - **Homepage Dashboard**: `https://homepage.yourdomain.com`
   - **n8n Workflow Automation**: `https://n8n.yourdomain.com`
   - **Argo CD GitOps**: `https://argocd.yourdomain.com`
   - **Longhorn Storage UI**: `https://longhorn.yourdomain.com`

That's it! Argo CD will automatically sync and deploy all infrastructure and applications.

## 📁 Repository Structure

```
.
├── bootstrap/                   # Argo CD installation and root ApplicationSets
│   ├── argocd-install.yaml     # Complete Argo CD installation
│   ├── root-applicationsets.yaml # App-of-apps ApplicationSets
│   └── setup-cloudflare.sh     # Cloudflare Tunnel setup script
├── infra/                      # Infrastructure components
│   ├── metallb/               # MetalLB load balancer
│   │   ├── namespace.yaml
│   │   ├── metallb.yaml
│   │   └── address-pool.yaml  # ⚠️ Edit IP range here
│   ├── longhorn/             # Longhorn distributed storage
│   │   ├── namespace.yaml
│   │   ├── kustomization.yaml
│   │   └── longhorn.yaml
│   ├── cloudflare-tunnel/    # Cloudflare Tunnel for secure access
│   │   ├── namespace.yaml
│   │   ├── kustomization.yaml
│   │   ├── cloudflared-deployment.yaml
│   │   ├── cloudflared-config.yaml
│   │   ├── cloudflared-service.yaml
│   │   └── cloudflared-secret.yaml
│   └── external-dns/         # Automatic DNS management
│       ├── namespace.yaml
│       ├── kustomization.yaml
│       ├── external-dns-deployment.yaml
│       ├── external-dns-rbac.yaml
│       └── external-dns-secret.yaml
├── apps/                      # Applications
│   ├── n8n/                 # n8n workflow automation
│   ├── homepage/            # Homepage dashboard
│   └── _template/          # Template for new apps
└── README.md               # This file
```

## 🛠 What Gets Deployed

### Infrastructure
- **Argo CD**: GitOps continuous delivery
- **MetalLB**: Load balancer for bare metal clusters
- **Longhorn**: Distributed block storage with web UI
- **Cloudflare Tunnel**: Secure external access without exposing your network
- **External-DNS**: Automatic DNS record management in Cloudflare

### Applications
- **n8n**: Workflow automation platform
- **Homepage**: Beautiful homelab dashboard

## 🔧 Configuration

### MetalLB IP Pool
Edit `infra/metallb/address-pool.yaml`:
```yaml
spec:
  addresses:
  - 192.168.1.200-192.168.1.250  # Your network range
```

### Cloudflare Tunnel Setup

#### Prerequisites
- Cloudflare account with a domain (e.g., `buildin.group`)
- `cloudflared` CLI installed on your local machine

#### Setup
```bash
# Run the setup script
./bootstrap/setup-cloudflare.sh
```

This script will:
1. Create a Cloudflare tunnel named `homelab-tunnel`
2. Set up External-DNS for automatic DNS management
3. Configure tunnel credentials in Kubernetes
4. Update all configurations with your domain

#### How It Works
- **External-DNS** automatically creates DNS records based on service annotations
- **Cloudflare Tunnel** routes traffic from DNS records to your Kubernetes services
- **No manual DNS management** required

#### Benefits
- **Security**: No need to expose ports on your router
- **SSL/TLS**: Automatic HTTPS certificates
- **DDoS Protection**: Cloudflare's global network protection
- **Performance**: Cloudflare's CDN and caching
- **Automatic DNS**: DNS records created automatically via External-DNS

### Application Access

After setting up Cloudflare Tunnel, your services will be available at:
- **Homepage Dashboard**: `https://homepage.yourdomain.com`
- **n8n Workflow Automation**: `https://n8n.yourdomain.com`
- **Argo CD GitOps**: `https://argocd.yourdomain.com`
- **Longhorn Storage UI**: `https://longhorn.yourdomain.com`

## ➕ Adding New Applications

1. **Copy the template:**
   ```bash
   cp -r apps/_template apps/myapp
   ```

2. **Update the manifests:**
   - Replace all instances of `CHANGEME` with your app name
   - Update image, ports, environment variables, etc.
   - Adjust resource requests/limits as needed
   - Add External-DNS annotations to the service for automatic DNS:
     ```yaml
     metadata:
       annotations:
         external-dns.alpha.kubernetes.io/hostname: myapp.yourdomain.com
         external-dns.alpha.kubernetes.io/ttl: "300"
     ```

3. **Commit and push:**
   ```bash
   git add apps/myapp/
   git commit -m "Add myapp"
   git push
   ```

Argo CD will automatically discover and deploy your new application!

## 🔍 Monitoring and Troubleshooting

### Check Argo CD Applications
```bash
# List all applications
kubectl get applications -n argocd

# Check application status
kubectl describe application n8n -n argocd
```

### Check Infrastructure Status
```bash
# MetalLB pods
kubectl get pods -n metallb-system

# Longhorn status
kubectl get pods -n longhorn-system

# Storage classes
kubectl get storageclass
```

### Common Issues

#### MetalLB not assigning IPs
- Verify the IP range in `infra/metallb/address-pool.yaml` matches your network
- Ensure no IP conflicts with existing devices
- Check MetalLB logs: `kubectl logs -n metallb-system -l app=metallb`

#### Longhorn UI not accessible
- Wait for all Longhorn pods to be ready: `kubectl get pods -n longhorn-system`
- Check the LoadBalancer service: `kubectl get svc -n longhorn-system`

#### Applications stuck in sync
- Check Argo CD application status: `kubectl describe application APP_NAME -n argocd`
- View application events in Argo CD UI
- Verify repository URL and branch in ApplicationSets

#### Cloudflare Tunnel not working
- Check tunnel pod status: `kubectl get pods -n cloudflare-tunnel`
- View tunnel logs: `kubectl logs -n cloudflare-tunnel deployment/cloudflared`
- Verify tunnel credentials: `kubectl get secret cloudflared-tunnel-credentials -n cloudflare-tunnel -o yaml`
- Test tunnel connectivity: `cloudflared tunnel list`

#### External-DNS not creating DNS records
- Check External-DNS pod status: `kubectl get pods -n external-dns`
- View External-DNS logs: `kubectl logs -n external-dns deployment/external-dns`
- Verify API token: `kubectl get secret cloudflare-api-token -n external-dns -o yaml`
- Check service annotations: `kubectl get services --all-namespaces -o jsonpath='{range .items[*]}{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}{"\n"}{end}'`

## 🎯 Customization

### Argo CD Configuration
The Argo CD installation includes:
- Insecure mode enabled (no TLS) for easier homelab access
- Default admin policy for simplified RBAC
- LoadBalancer service type for external access

### Storage
- Longhorn is configured as the default storage class
- All applications use Longhorn for persistent volumes
- Adjust PVC sizes in application manifests as needed

### Networking
- All services use LoadBalancer type for external access
- MetalLB provides IP addresses from your configured range
- No ingress controller included (can be added as another app)

## 🔒 Security Considerations

This setup prioritizes simplicity for homelab use:

- Argo CD runs in insecure mode (HTTP)
- Default admin credentials (change after first login)
- Permissive RBAC policies
- No network policies or service mesh

For production use, consider:
- Enabling TLS for Argo CD
- Implementing proper authentication
- Adding network policies
- Using ingress with TLS certificates

## 🤝 Contributing

Feel free to:
- Add more applications to the `apps/` directory
- Improve the infrastructure setup
- Submit issues and pull requests
- Share your homelab configurations

## 📚 Resources

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [n8n Documentation](https://docs.n8n.io/)
- [Homepage Documentation](https://gethomepage.dev/)

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
