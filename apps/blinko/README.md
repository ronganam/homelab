# Blinko

A minimal Kubernetes deployment of Blinko (Next.js) with an internal Postgres using Longhorn storage.

## Secrets

Create the app secret for NextAuth and database URL:

```bash
kubectl -n blinko create secret generic blinko-secrets \
  --from-literal=nextauth_secret='REPLACE_WITH_STRONG_SECRET' \
  --from-literal=database_url='postgresql://postgres:REPLACE_WITH_PASSWORD@postgres.blinko.svc.cluster.local:5432/postgres'
```

Create the Postgres credentials secret:

```bash
kubectl -n blinko create secret generic blinko-postgres \
  --from-literal=username='postgres' \
  --from-literal=password='REPLACE_WITH_PASSWORD'
```

## Apply

Managed by Argo CD via `apps/blinko/kustomization.yaml`.

### Internal Access

This app is internal-only. No Ingress is deployed. Service DNS inside the cluster:

```
http://blinko.blinko.svc.cluster.local:1111
```

## Notes

- Service `blinko` exposes port 1111 inside the cluster.
- DNS labels on the Service are set for `blinko.buildin.group` with `exposure.service-controller.io/type: "internal"`.
- PVC for Postgres uses `longhorn` and requests 5Gi.
