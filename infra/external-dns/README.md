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

### 1. Create Cloudflare API Token
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Create a custom token with:
   - Zone:Zone:Read permissions
   - Zone:DNS:Edit permissions
   - Include: All zones (or just your domain)

### 2. Get Your Zone ID
1. Go to your domain in Cloudflare dashboard
2. Copy the Zone ID from the right sidebar

### 3. Create Kubernetes Resources
```bash
# Create the secret with your API token
kubectl create secret generic cloudflare-api-token \
  --namespace=external-dns \
  --from-literal=api-token=YOUR_ACTUAL_TOKEN_HERE

# Create the configmap with your zone ID
kubectl create configmap cloudflare-config \
  --namespace=external-dns \
  --from-literal=zone-id=YOUR_ACTUAL_ZONE_ID_HERE
```

### 4. Deploy External-DNS
```bash
kubectl apply -k infra/external-dns/
```

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
