#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin"

ROOT=/mnt/c/Users/petre/Desktop/zkaudit
ZKVM="$ROOT/zkvm"
REGISTRY=$(cat "$ROOT/logs/registry_id.txt")
AUDITOR=$(stellar keys address hacker)

IMAGE_V1="2b421e8181bdefa2deeecd65802cc4771819332d8e142117427bf69d5235cbc0"
IMAGE_V2="8bd7b25bdfc8749301140588c11c97df9829bbaa739d227ae08788c00219a951"
HASH_V1="1c4426846cccbb0d3823e7bd9feba44f80db11d7f6f9fc23fc7344588a98ee7b"
HASH_V2="c9442e39c964a1c53df205a9fbce57b351759db139e3ee95b9f73d09a967bd0f"
PHASE1_IMAGE="f89da9fa7eaaa2061fe528d93c96aabd568565d8e02cbdf52b41d7d166f25479"

read_proof() {
  local file="$1"
  SEAL_HEX=$(sed -n '1p' "$file")
  IMAGE_ID_HEX=$(sed -n '2p' "$file")
}

attest() {
  local step="$1"
  local seal="$2"
  local image_id="$3"
  local journal="$4"
  echo ""
  echo "=== STEP $step: attest (simulate) ==="
  stellar contract invoke --send=no --network testnet --source hacker --id "$REGISTRY" -- \
    attest --auditor "$AUDITOR" --seal "$seal" --image_id "$image_id" --journal "$journal" || true
  echo ""
  echo "=== STEP $step: attest (submit) ==="
  stellar contract invoke --send=yes --network testnet --source hacker --id "$REGISTRY" -- \
    attest --auditor "$AUDITOR" --seal "$seal" --image_id "$image_id" --journal "$journal"
}

get_attestation() {
  local step="$1"
  local contract_hash="$2"
  echo ""
  echo "=== STEP $step: get_attestation($contract_hash) ==="
  stellar contract invoke --send=no --network testnet --source hacker --id "$REGISTRY" -- \
    get_attestation --contract_hash "$contract_hash"
}

expect_fail() {
  local step="$1"
  local label="$2"
  shift 2
  echo ""
  echo "=== STEP $step: $label (expect FAIL) ==="
  set +e
  OUT=$("$@" 2>&1)
  STATUS=$?
  set -e
  echo "$OUT"
  if [ "$STATUS" -eq 0 ]; then
    echo "ERROR: expected failure but command succeeded"
    exit 1
  fi
  echo "failed as expected (exit $STATUS)"
}

echo "AttestationRegistry E2E demo"
echo "registry=$REGISTRY"
echo "auditor=$AUDITOR"

JOURNAL_V1=$(tr -d '\n\r' < "$ZKVM/out/journal_v1.hex")
JOURNAL_V2=$(tr -d '\n\r' < "$ZKVM/out/journal_v2.hex")
read_proof "$ZKVM/out/proof_v1.txt"

echo ""
echo "=== STEP 1: attest v1 ==="
attest 1 "$SEAL_HEX" "$IMAGE_V1" "$JOURNAL_V1"

get_attestation 2 "$HASH_V1"

read_proof "$ZKVM/out/proof_v2.txt"
echo ""
echo "=== STEP 3: attest v2 ==="
attest 3 "$SEAL_HEX" "$IMAGE_V2" "$JOURNAL_V2"

get_attestation 4 "$HASH_V2"

TAMPERED="${JOURNAL_V1%??}0b"
read_proof "$ZKVM/out/proof_v1.txt"
expect_fail 5 "NEGATIVE-1 tampered journal (n_total 10->11)" \
  stellar contract invoke --send=no --network testnet --source hacker --id "$REGISTRY" -- \
  attest --auditor "$AUDITOR" --seal "$SEAL_HEX" --image_id "$IMAGE_V1" --journal "$TAMPERED"

read_proof "$ZKVM/proof.txt"
JOURNAL_P1=$(tr -d '\n\r' < "$ZKVM/journal.hex")
expect_fail 6 "NEGATIVE-2 unregistered Phase-1 engine" \
  stellar contract invoke --send=no --network testnet --source hacker --id "$REGISTRY" -- \
  attest --auditor "$AUDITOR" --seal "$SEAL_HEX" --image_id "$PHASE1_IMAGE" --journal "$JOURNAL_P1"

echo ""
echo "=== E2E demo complete ==="
