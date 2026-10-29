# Vertical Pod Autoscaler

Automated right-sizing of pod **requests** based on real usage. Deployed as an
infra Helm wrapper (`infra/vpa`) and discovered by the `infra` ApplicationSet.

## Components

The Fairwinds `vpa` chart (v5.1.0 / VPA 1.7.1) installs into the `vpa` namespace:

| Component | Purpose |
|---|---|
| Recommender | Watches Metrics Server data and writes recommendations to each VPA |
| Updater | Resizes pods in-place or evicts pods whose requests drift outside the recommendation |
| Admission Controller | Mutates newly created pods with the recommended requests |

Metrics Server already exists in `infra/metrics-server`; the chart's bundled
Metrics Server is disabled.

## Design choices

- **`updateMode: InPlaceOrRecreate`** — leverages Kubernetes native in-place pod vertical scaling (`InPlacePodVerticalScaling`). Changes container CPU and memory requests dynamically without evicting or restarting running pods; falls back to recreation only if in-place resize cannot fit node capacity.
- **`controlledValues: RequestsOnly`** — VPA changes requests only. Container
  limits (the OOM ceiling) are never touched, and recommendations are capped at
  the existing limit. This is what frees scheduler capacity without changing
  runtime behaviour.
- **`min-replicas: "1"`** — the upstream default of 2 would silently skip every
  single-replica workload in this cluster.
- **Throttled evictions** — `eviction-rate-limit: 0.2` avoids restarting all
  apps at once when a fallback recreate occurs.
- **cert-manager webhook certs** — `templates/certificate.yaml` creates a
  self-signed `Issuer` + `Certificate`; cainjector injects the CA into the
  webhook. The chart's Helm certgen hooks are disabled because they regenerate
  the cert on every sync.
- **`failurePolicy: Ignore`** — a VPA outage must never block pod creation.

## Adding a workload

Append an entry to `vpaTargets.targets` in `values.yaml`:\

```yaml
    - namespace: my-app
      deployment: my-app
```

Then commit. Argo CD syncs the new `VerticalPodAutoscaler` into the app's
namespace. Per-target overrides (`updateMode`, `minCpu`, `minMemory`, `maxCpu`,
`maxMemory`) are supported by `templates/vpa-targets.yaml`.

### Deliberately excluded

- Databases and StatefulSets (postgres, redis, CNPG clusters).
- GPU workloads (`frigate`).
- Cluster-critical services: `pihole` (DNS), `wireguard` (VPN), `registry`
  (image pulls), `infisical` (secret sync).
- Containers whose request already equals a tiny limit (no headroom to tune).

## Verification

```bash
kubectl get vpa -A
kubectl -n homepage get vpa homepage-vpa -o yaml
kubectl -n vpa get pods,issuer,certificate
kubectl get mutatingwebhookconfiguration vpa-webhook-config \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | wc -c
```

A resized pod carries a `vpaUpdates` annotation:

```bash
kubectl get pods -A -o json | jq -r '
  .items[] | select(.metadata.annotations.vpaUpdates)
  | [.metadata.namespace, .metadata.name,
     ([.spec.containers[] | (.resources.requests.cpu//"-")+"/"+(.resources.requests.memory//"-")]|join(","))]
  | @tsv'
```

Evictions (when fallback recreation occurs) are recorded as `EvictedByVPA` events:

```bash
kubectl get events -A --field-selector reason=EvictedByVPA
```
