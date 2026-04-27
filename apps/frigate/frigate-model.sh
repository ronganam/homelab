#!/usr/bin/env bash
set -euo pipefail

# Simple one-shot helper for Frigate YOLOv9 models
# Commands:
#   create-model  -> builds ONNX into ./yolov9-artifacts/
#   copy-model    -> copies ONNX into running Frigate pod at /config/model_cache/

ACTION="${1:-}"

# Tunables
MODEL_SIZE="${MODEL_SIZE:-s}"          # t, s, m, c, e
IMG_SIZE="${IMG_SIZE:-320}"            # 320 or 640
OUT_DIR="./yolov9-artifacts"
OUT_NAME="yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx"
MODEL_LOCAL_PATH="${OUT_DIR}/${OUT_NAME}"
MODEL_POD_PATH="/config/model_cache/${OUT_NAME}"

# K8s
NAMESPACE="${NAMESPACE:-frigate}"
LABEL_SELECTOR="${LABEL_SELECTOR:-app.kubernetes.io/name=frigate}"

usage() {
  cat <<USAGE
Usage:
  $0 create-model [--model-size s|m|t|c|e] [--img-size 320|640]
  $0 copy-model   [--model-size s|m|t|c|e] [--img-size 320|640]

Environment overrides:
  MODEL_SIZE (default: s)
  IMG_SIZE   (default: 320)
  NAMESPACE  (default: frigate)
  LABEL_SELECTOR (default: app.kubernetes.io/name=frigate)
USAGE
}

parse_args() {
  # shift ACTION already consumed
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model-size)
        MODEL_SIZE="$2"; shift 2;;
      --img-size)
        IMG_SIZE="$2"; shift 2;;
      --help|-h)
        usage; exit 0;;
      *)
        echo "Unknown option: $1" >&2; usage; exit 1;;
    esac
  done
  OUT_NAME="yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx"
  MODEL_LOCAL_PATH="${OUT_DIR}/${OUT_NAME}"
  MODEL_POD_PATH="/config/model_cache/${OUT_NAME}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

create_model() {
  require_cmd docker
  mkdir -p "${OUT_DIR}"
  echo "[1/3] Building exporter and producing ${OUT_NAME}..."
  docker build . \
    --build-arg MODEL_SIZE="${MODEL_SIZE}" \
    --build-arg IMG_SIZE="${IMG_SIZE}" \
    --output . \
    -f- <<'EOF'
FROM python:3.11 AS build

RUN apt-get update && apt-get install --no-install-recommends -y \
    libgl1 cmake build-essential git \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.8.0 /uv /bin/

WORKDIR /yolov9
ADD https://github.com/WongKinYiu/yolov9.git .
RUN uv pip install --system -r requirements.txt

RUN uv pip install --system \
    "numpy<2" \
    "protobuf<5" \
    "onnx==1.16.0" \
    "onnxruntime==1.19.2" \
    "onnxsim==0.4.36"

ARG MODEL_SIZE
ARG IMG_SIZE
ADD https://github.com/WongKinYiu/yolov9/releases/download/v0.1/yolov9-${MODEL_SIZE}-converted.pt yolov9-${MODEL_SIZE}.pt

RUN sed -i "s/ckpt = torch.load(attempt_download(w), map_location='cpu')/ckpt = torch.load(attempt_download(w), map_location='cpu', weights_only=False)/g" models/experimental.py

RUN python3 export.py --weights ./yolov9-${MODEL_SIZE}.pt --imgsz ${IMG_SIZE} --simplify --include onnx

FROM scratch
ARG MODEL_SIZE
ARG IMG_SIZE
COPY --from=build /yolov9/yolov9-${MODEL_SIZE}.onnx /yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx
EOF

  echo "[2/3] Moving artifact into ${MODEL_LOCAL_PATH}"
  mv -f "yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx" "${MODEL_LOCAL_PATH}"

  echo "[3/3] Done. File: ${MODEL_LOCAL_PATH}"
  sha256sum "${MODEL_LOCAL_PATH}" || true
}

copy_model() {
  require_cmd kubectl
  if [[ ! -f "${MODEL_LOCAL_PATH}" ]]; then
    echo "Model not found locally: ${MODEL_LOCAL_PATH}" >&2
    echo "Run: $0 create-model --model-size ${MODEL_SIZE} --img-size ${IMG_SIZE}" >&2
    exit 1
  fi

  echo "Waiting for Frigate pod (ns=${NAMESPACE}, selector=${LABEL_SELECTOR})..."
  kubectl wait --for=condition=ready pod -l "${LABEL_SELECTOR}" -n "${NAMESPACE}" --timeout=300s >/dev/null
  POD_NAME="$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" -o jsonpath='{.items[0].metadata.name}')"
  if [[ -z "${POD_NAME}" ]]; then
    echo "Could not find Frigate pod in namespace ${NAMESPACE}" >&2
    exit 1
  fi

  echo "Copying ${MODEL_LOCAL_PATH} -> pod/${POD_NAME}:${MODEL_POD_PATH}"
  kubectl cp "${MODEL_LOCAL_PATH}" "${NAMESPACE}/${POD_NAME}:${MODEL_POD_PATH}"
  echo "Copied. You may restart Frigate to load the new model:"
  echo "  kubectl rollout restart deployment/frigate -n ${NAMESPACE}"
}

main() {
  if [[ -z "${ACTION}" ]]; then
    usage; exit 1
  fi
  shift || true
  parse_args "$@"

  case "${ACTION}" in
    create-model)
      create_model;;
    copy-model)
      copy_model;;
    *)
      echo "Unknown command: ${ACTION}" >&2; usage; exit 1;;
  esac
}

main "$@"


