# Excalidraw (ExcaliDash)

Internal-only Kubernetes deployment of [ExcaliDash](https://github.com/ZimengXiong/ExcaliDash).

## What gets deployed

- `excalidraw-backend` (1 replica, SQLite on PVC)
- `excalidraw-frontend` (1 replica)
- Internal ingress at `http://excalidraw.ganam.app`

## Secrets (recommended)

`JWT_SECRET` and `CSRF_SECRET` are wired from an optional secret named `excalidraw-secrets`.

```bash
kubectl -n excalidraw create secret generic excalidraw-secrets \
  --from-literal=jwt_secret='replace-with-strong-random-secret' \
  --from-literal=csrf_secret='replace-with-strong-random-secret'
```

If this secret is not created, the backend still starts, but fixed secrets are recommended.

## Notes

- Backend uses `TRUST_PROXY=1` because traffic comes through NGINX ingress.
- Backend URL for frontend is set to the in-cluster service DNS:
  `excalidraw-backend.excalidraw.svc.cluster.local:8000`.
- Ingress rewrites cookies to `SameSite=None; Secure` so CSRF/session cookies
  can be used when ExcaliDash is embedded as an iframe (for example in
  Home Assistant dashboards).

