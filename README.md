# Homelab GitOps with Argo CD

A complete, ready-to-deploy homelab setup using GitOps principles with Argo CD. This repository bootstraps a fully functional Kubernetes homelab environment with minimal manual intervention.

## 🚀 Quick Start

### Prerequisites

- A running Kubernetes cluster (k3s, k8s, kind, etc.)
- `kubectl` configured to access your cluster
- Git repository hosting (GitHub, GitLab, etc.)

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

5. **Access Argo CD UI:**
   ```bash
   # Get the LoadBalancer IP
   kubectl get svc argocd-server -n argocd

   # Default credentials:
   # Username: admin
   # Password: admin
   ```

That's it! Argo CD will now automatically sync and deploy all infrastructure and applications.

## 📁 Repository Structure

```
.
├── bootstrap/                   # Argo CD installation and root ApplicationSets
│   ├── argocd-install.yaml     # Complete Argo CD installation
│   └── root-applicationsets.yaml # App-of-apps ApplicationSets
├── infra/                      # Infrastructure components
│   ├── metallb/               # MetalLB load balancer
│   │   ├── namespace.yaml
│   │   ├── metallb.yaml
│   │   └── address-pool.yaml  # ⚠️ Edit IP range here
│   └── longhorn/             # Longhorn distributed storage
│       ├── namespace.yaml
│       ├── kustomization.yaml
│       └── longhorn.yaml
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

### Application Access
After deployment, your services will be available via LoadBalancer IPs:

```bash
# Get all LoadBalancer services
kubectl get svc --all-namespaces -o wide | grep LoadBalancer
```

Services you'll see:
- Argo CD UI (argocd namespace)
- Longhorn UI (longhorn-system namespace)  
- n8n (n8n namespace)
- Homepage dashboard (homepage namespace)

## ➕ Adding New Applications

1. **Copy the template:**
   ```bash
   cp -r apps/_template apps/myapp
   ```

2. **Update the manifests:**
   - Replace all instances of `CHANGEME` with your app name
   - Update image, ports, environment variables, etc.
   - Adjust resource requests/limits as needed

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
