#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/bin"
ln -sf /mnt/c/Users/petre/Desktop/zkaudit/scripts/docker_wsl_wrapper.sh "$HOME/bin/docker"
chmod +x "$HOME/bin/docker"
export PATH="$HOME/bin:$HOME/.cargo/bin:/usr/bin:/bin"
export RISC0_DEV_MODE=1
SRC=/mnt/c/Users/petre/Desktop/zkaudit
DST=$HOME/zkaudit
mkdir -p "$DST/logs"
rsync -a --delete "$SRC/" "$DST/" --exclude target --exclude logs
cd "$DST/zkvm"
cargo clean -p methods
cargo build -p host --release 2>&1 | tee "$DST/logs/build_native.log"
echo "=== V1 ==="
cargo run -p host --release -- --target v1 --suite suites/standard.json --dev 2>&1 | tee "$DST/logs/cp5_v1.log"
echo "=== V2 ==="
cargo run -p host --release -- --target v2 --suite suites/standard.json --dev 2>&1 | tee "$DST/logs/cp5_v2.log"
cp "$DST/logs/cp5_v1.log" /mnt/c/Users/petre/Desktop/zkaudit/logs/
cp "$DST/logs/cp5_v2.log" /mnt/c/Users/petre/Desktop/zkaudit/logs/
