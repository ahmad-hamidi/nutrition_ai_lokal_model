#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./models}"
mkdir -p "$OUT_DIR"

MODEL="$OUT_DIR/Qwen3VL-2B-Instruct-Q4_K_M.gguf"
MMPROJ="$OUT_DIR/mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf"

MODEL_URL='https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3VL-2B-Instruct-Q4_K_M.gguf?download=true'
MMPROJ_URL='https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-2B-Instruct-Q8_0.gguf?download=true'

MODEL_SHA='089d75c52f4b7ffc56ba998ffc50aae89fcafc755f9e7208aacca281dca6c2ae'
MMPROJ_SHA='f9a68fabba69c3b81e153367b2c7521030b0fa8bb0de400c9599c8e6725f9c82'

echo 'Downloading Qwen3-VL language model (~1.11 GB)...'
curl -L --fail --retry 3 --continue-at - -o "$MODEL" "$MODEL_URL"

echo 'Downloading Qwen3-VL vision projector (~445 MB)...'
curl -L --fail --retry 3 --continue-at - -o "$MMPROJ" "$MMPROJ_URL"

verify_sha() {
  local expected="$1"
  local file="$2"
  local actual
  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  else
    echo 'No SHA-256 tool found; skipping checksum verification.' >&2
    return 0
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "Checksum mismatch: $file" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
  echo "Checksum OK: $file"
}

verify_sha "$MODEL_SHA" "$MODEL"
verify_sha "$MMPROJ_SHA" "$MMPROJ"

echo
echo "Models ready in: $OUT_DIR"
