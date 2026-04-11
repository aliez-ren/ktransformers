#!/usr/bin/env bash
set -euo pipefail

MODEL_PATH="${MODEL_PATH:-/root/.cache/huggingface/hub/models--moonshotai--Kimi-K2.5}"

# Resolve HuggingFace Hub cache structure: use snapshot dir if MODEL_PATH has no config.json
if [ ! -f "${MODEL_PATH}/config.json" ]; then
  SNAP=$(ls -td "${MODEL_PATH}/snapshots/"*/ 2>/dev/null | head -1)
  if [ -n "$SNAP" ]; then
    MODEL_PATH="${SNAP%/}"
  fi
fi

KT_WEIGHT_PATH="${KT_WEIGHT_PATH:-$MODEL_PATH}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-31245}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-Kimi-K2.5}"

if command -v nvidia-smi >/dev/null 2>&1; then
  DEFAULT_TP_SIZE="$(nvidia-smi -L | wc -l)"
else
  DEFAULT_TP_SIZE="1"
fi

TP_SIZE="${TP_SIZE:-$DEFAULT_TP_SIZE}"
KT_CPUINFER="${KT_CPUINFER:-$(nproc)}"
KT_THREADPOOL_COUNT="${KT_THREADPOOL_COUNT:-2}"
KT_NUM_GPU_EXPERTS="${KT_NUM_GPU_EXPERTS:-30}"
KT_GPU_PREFILL_TOKEN_THRESHOLD="${KT_GPU_PREFILL_TOKEN_THRESHOLD:-0}"
MEM_FRACTION_STATIC="${MEM_FRACTION_STATIC:-0.94}"
CHUNKED_PREFILL_SIZE="${CHUNKED_PREFILL_SIZE:-32658}"
MAX_TOTAL_TOKENS="${MAX_TOTAL_TOKENS:-50000}"
ATTENTION_BACKEND="${ATTENTION_BACKEND:-flashinfer}"

export CPUINFER_CPU_INSTRUCT="${CPUINFER_CPU_INSTRUCT:-AVX2}"
export CPUINFER_ENABLE_AMX="${CPUINFER_ENABLE_AMX:-OFF}"
export CPUINFER_ENABLE_AVX512="${CPUINFER_ENABLE_AVX512:-OFF}"

exec python3 -m sglang.launch_server \
  --host "$HOST" \
  --port "$PORT" \
  --model "$MODEL_PATH" \
  --kt-weight-path "$KT_WEIGHT_PATH" \
  --kt-cpuinfer "$KT_CPUINFER" \
  --kt-threadpool-count "$KT_THREADPOOL_COUNT" \
  --kt-num-gpu-experts "$KT_NUM_GPU_EXPERTS" \
  --kt-method RAWINT4 \
  --kt-gpu-prefill-token-threshold "$KT_GPU_PREFILL_TOKEN_THRESHOLD" \
  --trust-remote-code \
  --mem-fraction-static "$MEM_FRACTION_STATIC" \
  --served-model-name "$SERVED_MODEL_NAME" \
  --enable-mixed-chunk \
  --tensor-parallel-size "$TP_SIZE" \
  --enable-p2p-check \
  --disable-shared-experts-fusion \
  --chunked-prefill-size "$CHUNKED_PREFILL_SIZE" \
  --max-total-tokens "$MAX_TOTAL_TOKENS" \
  --attention-backend "$ATTENTION_BACKEND" \
  "$@"
