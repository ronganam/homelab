# External-DNS with Cloudflare

This directory contains the Kubernetes manifests for External-DNS, which automatically manages DNS records in Cloudflare based on Kubernetes service annotations.

## How It Works

External-DNS watches for Kubernetes services with specific annotations and automatically creates/updates DNS records in Cloudflare. This eliminates the need to manually create DNS records.

## Configuration

### Required Annotations

Add these annotations to your services to create DNS records:

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: service.yourdomain.com
    external-dns.alpha.kubernetes.io/ttl: "300"
```

### Example Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: myapp
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myapp.buildin.group
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: myapp
```

## Setup

Run the setup script:
```bash
./bootstrap/setup-cloudflare.sh
```

This will automatically configure External-DNS with your Cloudflare credentials and zone ID.

## Benefits

- **Automatic DNS Management**: No need to manually create DNS records
- **GitOps Friendly**: DNS records are managed through Kubernetes manifests
- **Scalable**: Easy to add new services with DNS records
- **Consistent**: All DNS records follow the same pattern

## Monitoring

Check External-DNS status:
```bash
kubectl get pods -n external-dns
kubectl logs -n external-dns deployment/external-dns
```

View created DNS records:
```bash
kubectl get services --all-namespaces -o jsonpath='{range .items[*]}{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}{"\n"}{end}'
```
