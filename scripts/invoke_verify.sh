#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin"

ROUTER="CC3K4SGFS3ATCQKDKZNNC3BVDMXC5KXIK7GTZQOMYLIYPVYTVXSWW4N5"
ROOT=/mnt/c/Users/petre/Desktop/zkaudit/zkvm

verify_proof() {
  local label="$1"
  local proof_file="$2"
  local seal_hex image_id_hex journal_digest_hex

  seal_hex=$(sed -n '1p' "$proof_file")
  image_id_hex=$(sed -n '2p' "$proof_file")
  journal_digest_hex=$(sed -n '3p' "$proof_file")

  echo "=== [$label] simulate verify ==="
  stellar contract invoke --send=no --network testnet --source hacker --id "$ROUTER" -- \
    verify --seal "$seal_hex" --image_id "$image_id_hex" --journal "$journal_digest_hex"

  echo ""
  echo "=== [$label] submit verify (--send=yes) ==="
  stellar contract invoke --send=yes --network testnet --source hacker --id "$ROUTER" -- \
    verify --seal "$seal_hex" --image_id "$image_id_hex" --journal "$journal_digest_hex"
}

verify_proof v1 "$ROOT/out/proof_v1.txt"
echo ""
verify_proof v2 "$ROOT/out/proof_v2.txt"
