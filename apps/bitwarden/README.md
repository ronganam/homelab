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

## Optional secret: SMTP credentials

Non-secret SMTP fields (host, from, port, security) are configured in the `ConfigMap` (`configmap.yaml`). Only username and password go into a Secret.

```bash
kubectl -n bitwarden create secret generic vaultwarden-smtp \
  --from-literal=username='REPLACE_WITH_SMTP_USERNAME' \
  --from-literal=password='REPLACE_WITH_SMTP_PASSWORD'
```

Update later:
```bash
kubectl -n bitwarden delete secret vaultwarden-smtp
kubectl -n bitwarden create secret generic vaultwarden-smtp \
  --from-literal=username='REPLACE_WITH_SMTP_USERNAME' \
  --from-literal=password='REPLACE_WITH_SMTP_PASSWORD'
```

## Apply changes

After creating or updating secrets/config, restart the StatefulSet to pick up changes:
```bash
kubectl -n bitwarden rollout restart statefulset/bitwarden
```

## Verify
```bash
kubectl -n bitwarden get pods,svc,cm,secret
```
