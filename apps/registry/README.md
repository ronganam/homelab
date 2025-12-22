# Internal Docker Registry

This deploys a **simple, internal** Docker image registry using the official `registry:2` image.

## Endpoint

- Hostname: `registry.buildin.group`

## Push/Pull examples

```bash
docker tag alpine:3.20 registry.buildin.group/alpine:3.20
docker push registry.buildin.group/alpine:3.20
docker pull registry.buildin.group/alpine:3.20
```

## Storage

- Uses a Longhorn PVC: `registry-data` (5Gi) mounted at `/var/lib/registry`.


