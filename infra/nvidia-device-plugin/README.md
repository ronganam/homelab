# NVIDIA Device Plugin (GPU)

This module deploys the NVIDIA Device Plugin via a Helm wrapper and creates a `RuntimeClass` named `nvidia` so pods can request GPUs easily.

- Namespace: `kube-system`
- Upstream chart: `nvidia-device-plugin` (NVIDIA)
- RuntimeClass: `nvidia` (created here)
- Targets only nodes labeled `nvidia.com/gpu.present=true`

## Prerequisites (on the GPU node)
- NVIDIA driver installed (verify with `nvidia-smi`).
- NVIDIA Container Toolkit installed and containerd configured.
- CDI enabled in containerd (expected by this setup).

Enable CDI if needed:
```bash
ssh worker-1 'sudo nvidia-ctk runtime configure --runtime=containerd --cdi.enabled=true && sudo systemctl restart containerd'
```

## Deploy (GitOps)
This module lives in `infra/nvidia-device-plugin`. Argo CD auto-discovers and syncs it.
```bash
kubectl -n argocd get applications.argoproj.io nvidia-device-plugin
```

## Label a worker as GPU-enabled
Label only the actual GPU node(s):
```bash
# Label the GPU node
kubectl label node k8s-worker-1 nvidia.com/gpu.present=true --overwrite

# (Optional) remove from non-GPU nodes
kubectl label node k8s-worker-2 nvidia.com/gpu.present- || true
kubectl label node k8s-control-plane nvidia.com/gpu.present- || true
```

## Verify device plugin
```bash
# DaemonSet
kubectl -n kube-system get ds nvidia-device-plugin

# Allocatable GPUs per node
kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"
```
You should see a GPU count (e.g., `1`) for your GPU node.

## Quick test (nvidia-smi)
Minimal pod manifest:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  runtimeClassName: nvidia
  nodeSelector:
    nvidia.com/gpu.present: "true"
  restartPolicy: Never
  containers:
    - name: gpu-test
      image: docker.io/nvidia/cuda:12.6.2-base-ubuntu24.04
      command: ["/bin/sh", "-c"]
      args: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1
```
Run and view output:
```bash
kubectl apply -f gpu-test.yaml
kubectl logs -f pod/gpu-test
```

One-liner alternative:
```bash
kubectl run gpu-test \
  --image=docker.io/nvidia/cuda:12.6.2-base-ubuntu24.04 \
  --restart=Never \
  --overrides='{"apiVersion":"v1","kind":"Pod","spec":{"runtimeClassName":"nvidia","nodeSelector":{"nvidia.com/gpu.present":"true"},"containers":[{"name":"gpu-test","image":"docker.io/nvidia/cuda:12.6.2-base-ubuntu24.04","command":["/bin/sh","-c"],"args":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}'
```

## Using GPUs in workloads
In any container spec, request GPUs by setting a limit and (recommended) use the RuntimeClass and node selector:
```yaml
spec:
  runtimeClassName: nvidia
  nodeSelector:
    nvidia.com/gpu.present: "true"
  containers:
    - name: app
      image: YOUR_IMAGE
      resources:
        limits:
          nvidia.com/gpu: 1  # number of GPUs
```

## Troubleshooting
- NVML errors inside pods: ensure NVIDIA driver is present and CDI is enabled on the node.
- No GPUs allocatable: confirm node label and that the DaemonSet is running on the GPU node.
