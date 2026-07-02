#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/bin:/bin"
VENDOR=/mnt/c/Users/petre/Desktop/zkaudit/vendor/stellar-risc0-verifier
ZKVM=~/zkaudit/zkvm
cd "$VENDOR"

SELECTOR=$(grep '^selector = ' deployment.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
ROUTER=$(python3 scripts/toml_helper.py read deployment.toml chains.stellar-testnet.router)
echo "SELECTOR=$SELECTOR"
echo "ROUTER=$ROUTER"

./scripts/manage.sh schedule-add-verifier -n testnet -a hacker --selector "$SELECTOR"
./scripts/manage.sh execute-add-verifier -n testnet -a hacker --selector "$SELECTOR"
./scripts/manage.sh status -n testnet

SEAL_HEX=$(sed -n '1p' "$ZKVM/proof.txt")
IMAGE_ID_HEX=$(sed -n '2p' "$ZKVM/proof.txt")
JOURNAL_DIGEST_HEX=$(sed -n '3p' "$ZKVM/proof.txt")

echo "=== simulate verify ==="
stellar contract invoke --send=no --network testnet --source hacker --id "$ROUTER" -- \
  verify --seal "$SEAL_HEX" --image_id "$IMAGE_ID_HEX" --journal "$JOURNAL_DIGEST_HEX"

echo "=== submit verify ==="
stellar contract invoke --network testnet --source hacker --id "$ROUTER" -- \
  verify --seal "$SEAL_HEX" --image_id "$IMAGE_ID_HEX" --journal "$JOURNAL_DIGEST_HEX"
