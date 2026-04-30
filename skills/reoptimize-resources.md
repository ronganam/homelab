# Skill: Re-optimize Kubernetes Pod Resources

This skill allows you to automatically adjust Kubernetes pod CPU/Memory requests and limits based on actual usage data from the past 48 hours.

## Prerequisites
- **Python 3** with `requests` and `ruamel.yaml` installed.
- **Grafana API Token** with viewer permissions (or higher) to query Prometheus.
- **Environment Variables**:
  ```bash
  export GRAFANA_URL="https://grafana.ganam.app"
  export GRAFANA_TOKEN=""
  ```

## Execution
Run the optimization script from the root of the repository:
```bash
python3 scripts/optimize_resources.py --lookback 48
```

## Optimization Logic
The script follows these rules to ensure stability while minimizing wasted resources:

1.  **CPU Request**: Set to **110%** of the maximum observed usage over the lookback period (minimum 10m).
2.  **Memory Request**: Set to **110%** of the maximum observed usage (minimum 16Mi).
3.  **Memory Limit**: Set to **130%** of the maximum observed usage to provide a safety buffer for spikes and prevent OOMKills.
4.  **CPU Limit**: **Removed**. Modern Kubernetes best practices suggest avoiding CPU limits to prevent unnecessary throttling (latency), allowing pods to burst into idle node capacity.

## How it works
1.  **Metrics Collection**: Queries the Prometheus datasource via Grafana's proxy API.
2.  **App Mapping**: Matches Prometheus namespaces to directories in `apps/`.
3.  **YAML Patching**: Uses `ruamel.yaml` to edit `deployment.yaml`, `statefulset.yaml`, or `values.yaml` while preserving comments and formatting.
4.  **Batching**: Updates all identified containers in one pass.

## Maintenance
If the repository structure changes or new Helm chart patterns are introduced, update the `process_file` function in `scripts/optimize_resources.py` to handle the new YAML paths.
