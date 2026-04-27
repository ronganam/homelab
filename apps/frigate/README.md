# Frigate YOLOv9 – Quick Guide

Minimal, two-step workflow to build and load a YOLOv9 model for Frigate.

## Commands

```bash
# 1) Build ONNX model into ./yolov9-artifacts/
./frigate-model.sh create-model

# 2) Copy model into the running Frigate pod at /config/model_cache/
./frigate-model.sh copy-model
```

## Options

- Model size: `--model-size t|s|m|c|e` (default: `s`)
- Image size: `--img-size 320|640` (default: `320`)

Examples:
```bash
MODEL_SIZE=m IMG_SIZE=640 ./frigate-model.sh create-model
MODEL_SIZE=m IMG_SIZE=640 ./frigate-model.sh copy-model
```

## Notes

- Frigate expects the model at `/config/model_cache/yolov9-<size>-<img>.onnx`.
- Ensure the `width`/`height` in `values.yaml` match the `IMG_SIZE` you build.

Verify and (if needed) restart Frigate:
```bash
kubectl exec -n frigate deployment/frigate -- ls -la /config/model_cache/
kubectl rollout restart deployment/frigate -n frigate
```
