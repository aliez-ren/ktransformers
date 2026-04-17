#!/usr/bin/env bash
# Launch the kimi-k25-avx2 container with a hard 248 GB memory cap to prevent
# host OOM.  Memory swap is set equal to the limit (no swap headroom) so the
# kernel OOM-kills the container instead of thrashing the host.
set -euo pipefail

IMAGE="${IMAGE:-kimi-k25-avx2:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-kimi-smoke}"
HOST_MODEL_PATH="${HOST_MODEL_PATH:-/home/rzh/.cache/huggingface/hub}"
HOST_PORT="${HOST_PORT:-31245}"

# 248 GB hard limit; --memory-swap same value → no extra swap for this container
MEMORY_LIMIT="${MEMORY_LIMIT:-248g}"

exec docker run \
  --rm \
  --name "$CONTAINER_NAME" \
  --gpus all \
  --ipc host \
  --memory "$MEMORY_LIMIT" \
  --memory-swap "$MEMORY_LIMIT" \
  -v "${HOST_MODEL_PATH}:/home/rzh/.cache/huggingface/hub:ro" \
  -p "${HOST_PORT}:31245" \
  "$IMAGE" \
  "$@"
