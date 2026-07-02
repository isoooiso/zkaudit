#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/bin"
ln -sf /mnt/c/Users/petre/Desktop/zkaudit/scripts/docker_wsl_wrapper.sh "$HOME/bin/docker"
chmod +x "$HOME/bin/docker"
export PATH="$HOME/bin:$HOME/.cargo/bin:/usr/bin:/bin"
export RISC0_DEV_MODE=0
WORK=$HOME/zkaudit/zkvm/groth-work-v1
rm -rf "$WORK"
mkdir -p "$WORK"
export RISC0_WORK_DIR="$WORK"
cd "$HOME/zkaudit/zkvm"
set +e
cargo run -p host --release -- --target v1 --suite suites/standard.json 2>&1 | tee "$HOME/zkaudit/logs/groth16_debug.log"
status=$?
set -e
echo "host_exit=$status"
ls -la "$WORK" || true
if [ -f "$WORK/input.json" ]; then
  echo "input.json bytes=$(wc -c < "$WORK/input.json")"
  echo "=== manual docker ==="
  docker run --rm -v "$WORK:/mnt" risczero/risc0-groth16-prover:v2025-04-03.1 2>&1 | tee "$HOME/zkaudit/logs/docker_manual.log"
fi
