#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.cargo/bin:$HOME/bin:/usr/bin:/bin"
cd /mnt/c/Users/petre/Desktop/zkaudit/zkvm
export RISC0_DEV_MODE=1

echo "=== V1 ==="
cargo run -p host --release -- --target v1 --suite suites/standard.json --dev

echo ""
echo "=== V2 ==="
cargo run -p host --release -- --target v2 --suite suites/standard.json --dev
