# Troubleshooting Guide

## Cloudflare Setup Issues

### Authentication Issues

**Error**: `Not authenticated with Cloudflare`

**Solution**:
```bash
cloudflared tunnel login
```
This will open a browser window for you to authenticate with Cloudflare.

### Tunnel Creation Issues

**Error**: `"cloudflared tunnel create" requires exactly 1 argument`

**Solution**: The script now checks if the tunnel already exists before trying to create it. If you're still having issues:

1. List existing tunnels:
   ```bash
   cloudflared tunnel list
   ```

2. If `homelab-tunnel` already exists, you can either:
   - Use the existing tunnel (the script will detect it)
   - Delete it and recreate:
     ```bash
     cloudflared tunnel delete homelab-tunnel
     ```

### Origin Certificate Issues

**Error**: `Cannot determine default origin certificate path`

**Solution**: This usually happens when the tunnel credentials are corrupted or missing. Try:

1. Delete the existing tunnel:
   ```bash
   cloudflared tunnel delete homelab-tunnel
   ```

2. Recreate it:
   ```bash
   cloudflared tunnel create homelab-tunnel
   ```

3. Run the setup script again.

### API Token Issues

**Error**: External-DNS not creating DNS records

**Solution**: 
1. Verify your API token has the correct permissions:
   - Zone:Zone:Read
   - Zone:DNS:Edit
   - Include: All zones (or just your domain)

2. Check External-DNS logs:
   ```bash
   kubectl logs -n external-dns deployment/external-dns
   ```

### Zone ID Issues

**Error**: Cannot find Zone ID

**Solution**:
1. Go to your Cloudflare dashboard
2. Select your domain
3. Copy the Zone ID from the right sidebar
4. Enter it when prompted by the script

## General Kubernetes Issues

### Pods Not Starting

Check pod status:
```bash
kubectl get pods --all-namespaces
```

Check pod logs:
```bash
kubectl logs -n <namespace> <pod-name>
```

### Services Not Accessible

Check service status:
```bash
kubectl get svc --all-namespaces
```

Check if External-DNS created DNS records:
```bash
kubectl get services --all-namespaces -o jsonpath='{range .items[*]}{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}{"\n"}{end}'
```

### Argo CD Issues

Check Argo CD application status:
```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

## Common Commands

### Check Everything is Running
```bash
# Check all pods
kubectl get pods --all-namespaces

# Check services
kubectl get svc --all-namespaces

# Check Argo CD applications
kubectl get applications -n argocd
```

### View Logs
```bash
# Cloudflare Tunnel
kubectl logs -n cloudflare-tunnel deployment/cloudflared

# External-DNS
kubectl logs -n external-dns deployment/external-dns

# Argo CD
kubectl logs -n argocd deployment/argocd-server
```

### Test DNS Resolution
```bash
nslookup homepage.yourdomain.com
nslookup n8n.yourdomain.com
```

## Getting Help

If you're still having issues:

1. Check the logs for the specific component that's failing
2. Verify your Cloudflare credentials and permissions
3. Ensure your domain is properly configured in Cloudflare
4. Check that all required ports are accessible in your network
