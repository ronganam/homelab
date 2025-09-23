## Internal HTTPS with wildcard cert (simple & reliable)

This setup gives all internal apps HTTPS with a trusted Let's Encrypt certificate, using:
- NGINX Ingress (LoadBalancer via MetalLB)
- cert-manager (ACME DNS-01 on Cloudflare)
- Wildcard certificate for `*.internal.example.com`
- Service controller updates Cloudflare DNS to the ingress IP for internal hosts

### 1) Prereqs
- MetalLB providing an external IP for `ingress-nginx-controller`
- Secret `cloudflare-api-token` in `cert-manager` namespace with key `token`

```bash
kubectl create ns cert-manager || true
kubectl -n cert-manager create secret generic cloudflare-api-token \
  --from-literal=token=CF_API_TOKEN_VALUE
```

### 2) Deploy
Apply the kustomizations (ArgoCD or kubectl):

```bash
kubectl apply -k infra/ingress-nginx
kubectl apply -k infra/cert-manager
kubectl apply -k infra/cloudflare-tunnel
``;

Wait for:
- `ingress-nginx-controller` to get an external IP
- Certificate `wildcard-internal-tls` to become `Ready`

### 3) DNS and domains
- Replace `example.com` with your domain in:
  - `infra/cert-manager/wildcard-certificate.yaml`
  - `infra/examples/internal-app-ingress.yaml`
- Internal hosts should follow `app.internal.<your-domain>`.

The service controller automatically creates/updates A records in Cloudflare for internal hosts to point at the ingress IP.

### 4) Using it for an app
Create a `Service` (ClusterIP) and an `Ingress` for the host, then label the Service for internal DNS management:

```yaml
metadata:
  labels:
    dns.service-controller.io/enabled: "true"
    dns.service-controller.io/hostname: "app.internal.example.com"
    exposure.service-controller.io/type: "internal"
```

Because the ingress has a default TLS cert (`ingress-nginx/wildcard-internal-tls`), you don't need to set per-Ingress TLS sections.

### Notes
- The controller now uses the ingress IP for all internal records, simplifying per-app setup.
- Public services continue to be tunneled and managed as before.

