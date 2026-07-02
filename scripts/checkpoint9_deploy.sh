#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin"

ROOT=/mnt/c/Users/petre/Desktop/zkaudit
REGISTRY_DIR="$ROOT/contracts/attestation-registry"
ROUTER="CC3K4SGFS3ATCQKDKZNNC3BVDMXC5KXIK7GTZQOMYLIYPVYTVXSWW4N5"
ADMIN=$(stellar keys address hacker)
IMAGE_V1="2b421e8181bdefa2deeecd65802cc4771819332d8e142117427bf69d5235cbc0"
IMAGE_V2="8bd7b25bdfc8749301140588c11c97df9829bbaa739d227ae08788c00219a951"

cd "$REGISTRY_DIR"
echo "=== stellar contract build ==="
stellar contract build --optimize 2>&1 | tee "$ROOT/logs/cp9_build.log"

WASM="$REGISTRY_DIR/target/wasm32v1-none/release/attestation_registry.wasm"
if [ ! -f "$WASM" ]; then
  WASM=$(find "$REGISTRY_DIR/target" -name 'attestation_registry.wasm' | head -1)
fi
SIZE=$(wc -c < "$WASM")
echo "wasm_path=$WASM"
echo "wasm_bytes=$SIZE"

echo ""
echo "=== deploy registry ==="
stellar contract deploy \
  --wasm "$WASM" \
  --source hacker \
  --network testnet \
  --alias attestation-registry \
  -- \
  --admin "$ADMIN" \
  --router "$ROUTER" 2>&1 | tee "$ROOT/logs/cp9_deploy.log"

REGISTRY=$(tail -n 1 "$ROOT/logs/cp9_deploy.log" | tr -d '"')
echo "registry_id=$REGISTRY"

register_engine() {
  local label="$1"
  local image_id="$2"
  echo ""
  echo "=== register_engine $label ==="
  echo "simulate:"
  stellar contract invoke --send=no --network testnet --source hacker --id "$REGISTRY" -- \
    register_engine --image_id "$image_id"
  echo "submit:"
  stellar contract invoke --send=yes --network testnet --source hacker --id "$REGISTRY" -- \
    register_engine --image_id "$image_id"
}

register_engine v1 "$IMAGE_V1"
register_engine v2 "$IMAGE_V2"

echo ""
echo "=== is_engine_registered sanity ==="
for label in v1 v2; do
  if [ "$label" = v1 ]; then id="$IMAGE_V1"; else id="$IMAGE_V2"; fi
  echo -n "$label: "
  stellar contract invoke --send=no --network testnet --source hacker --id "$REGISTRY" -- \
    is_engine_registered --image_id "$id"
done

echo "$REGISTRY" > "$ROOT/logs/registry_id.txt"
echo "saved registry id to logs/registry_id.txt"
