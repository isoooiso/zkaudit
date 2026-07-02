#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/bin:$HOME/.cargo/bin:/usr/bin:/bin"
export RISC0_DEV_MODE=1
cd /mnt/c/Users/petre/Desktop/zkaudit/zkvm
cargo clean -p methods
cargo build -p host --release 2>&1 | tee /mnt/c/Users/petre/Desktop/zkaudit/logs/rebuild.log
echo "=== V1 ==="
cargo run -p host --release -- --target v1 --suite suites/standard.json --dev 2>&1 | tee /mnt/c/Users/petre/Desktop/zkaudit/logs/cp5_v1.log
echo "=== V2 ==="
cargo run -p host --release -- --target v2 --suite suites/standard.json --dev 2>&1 | tee /mnt/c/Users/petre/Desktop/zkaudit/logs/cp5_v2.log
