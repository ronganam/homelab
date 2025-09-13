# Simple Cloudflare Tunnel Setup

This is a clean, simple Cloudflare Tunnel setup for your homelab with **annotation-based service exposure**.

## What's Included

- **Single setup script** - Just run and follow prompts
- **Annotation-based control** - Add/remove services with simple annotations
- **Automatic DNS management** - No manual DNS route creation needed
- **Internal/External separation** - Control which services are internet-accessible

## Quick Setup

1. **Run the setup script:**
   ```bash
   ./setup-cloudflare.sh
   ```

2. **Follow the prompts:**
   - Enter your domain (e.g., `example.com`)
   - The script will create the tunnel and deploy the controller

3. **Add services to expose:**
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: my-service
     namespace: my-namespace
     annotations:
       cloudflare.com/tunnel-hostname: "myservice.example.com"
   ```

## Adding/Removing Services

### To Expose a Service to the Internet:
Add the annotation to your Service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: my-namespace
  annotations:
    cloudflare.com/tunnel-hostname: "myservice.example.com"
spec:
  # ... your service spec
```

### To Keep a Service Internal-Only:
Don't add the annotation. The service will only be accessible through:
- MetalLB (if using LoadBalancer type)
- Port-forwarding: `kubectl port-forward svc/my-service 8080:80`
- Internal cluster access

### Examples:
- **Homepage**: `cloudflare.com/tunnel-hostname: "homepage.example.com"`
- **n8n**: `cloudflare.com/tunnel-hostname: "n8n.example.com"`
- **ArgoCD**: `cloudflare.com/tunnel-hostname: "argocd.example.com"`
- **Longhorn**: No annotation = Internal only
- **Prometheus**: No annotation = Internal only

## Monitoring

Check tunnel and controller status:
```bash
kubectl get pods -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel deployment/cloudflared
kubectl logs -n cloudflare-tunnel deployment/tunnel-controller
```

Check which services are exposed:
```bash
kubectl get services --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.metadata.annotations.cloudflare\.com/tunnel-hostname}{"\n"}{end}' | grep -v "^$"
```

## Troubleshooting

- **Tunnel not starting?** Check the logs above
- **Controller not working?** Check controller logs and ensure it has proper RBAC permissions
- **Services not accessible?** Verify the annotation is correct and the service is running
- **DNS not working?** Check if the tunnel route was created: `cloudflared tunnel route list homelab-tunnel`

## Security Benefits

🔒 **No Hardcoded Tokens** - Secrets are created dynamically  
🔒 **Selective Exposure** - Only services with annotations are exposed to internet  
🔒 **Internal Services Protected** - Services without annotations remain internal-only  
🔒 **Secure Storage** - Tokens stored in Kubernetes secrets  
🔒 **No Token Exposure** - Tokens never appear in configuration files  

## Benefits

✅ **Simple** - One script, annotation-based control  
✅ **Secure** - Traffic encrypted through Cloudflare, selective exposure  
✅ **Fast** - Cloudflare's global CDN  
✅ **Reliable** - No need for LoadBalancer or external IPs  
✅ **Maintainable** - Clear, minimal configuration  
✅ **Safe** - No hardcoded credentials in version control  
✅ **Flexible** - Easy to add/remove services with annotations
