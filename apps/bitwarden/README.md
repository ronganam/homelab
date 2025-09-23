# Bitwarden (Vaultwarden)

This app uses Vaultwarden with Longhorn storage and exposes an internal LoadBalancer. Create the required secrets before or right after ArgoCD sync.

## Required secret: Admin token

Generate a strong random token and store it in the `vaultwarden-admin` secret (key `token`).

```bash
# Example: generate a 64-char hex token
openssl rand -hex 32

# Create the secret
kubectl -n bitwarden create secret generic vaultwarden-admin \
  --from-literal=token='REPLACE_WITH_STRONG_RANDOM_TOKEN'
```

Update later:
```bash
kubectl -n bitwarden delete secret vaultwarden-admin
kubectl -n bitwarden create secret generic vaultwarden-admin \
  --from-literal=token='REPLACE_WITH_STRONG_RANDOM_TOKEN'
```

## Optional: SMTP email support

To enable email features, you need to set both `SMTP_HOST` and `SMTP_FROM` in the ConfigMap, plus create the SMTP secret with credentials.

**Step 1: Enable SMTP in ConfigMap**
Edit `configmap.yaml` and uncomment the SMTP lines, then set your values:
```yaml
SMTP_FROM: "noreply@example.com"
SMTP_HOST: "smtp.example.com"
SMTP_PORT: "587"
SMTP_SECURITY: "starttls"
```

**Step 2: Create SMTP secret with credentials**
```bash
kubectl -n bitwarden create secret generic vaultwarden-smtp \
  --from-literal=username='REPLACE_WITH_SMTP_USERNAME' \
  --from-literal=password='REPLACE_WITH_SMTP_PASSWORD'
```

**To disable email features:** SMTP environment variables are commented out in the ConfigMap (default state).

Update later:
```bash
kubectl -n bitwarden delete secret vaultwarden-smtp
kubectl -n bitwarden create secret generic vaultwarden-smtp \
  --from-literal=username='REPLACE_WITH_SMTP_USERNAME' \
  --from-literal=password='REPLACE_WITH_SMTP_PASSWORD'
```

## Apply changes

After editing the ConfigMap or creating/updating secrets, ArgoCD will automatically sync the changes. The StatefulSet will restart automatically when the ConfigMap changes.

## Verify
```bash
kubectl -n bitwarden get pods,svc,cm,secret
```
