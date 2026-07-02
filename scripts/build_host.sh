#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.cargo/bin:$HOME/bin:/usr/bin:/bin"
cd /mnt/c/Users/petre/Desktop/zkaudit/zkvm
LOG=/mnt/c/Users/petre/Desktop/zkaudit/logs/build.log
mkdir -p /mnt/c/Users/petre/Desktop/zkaudit/logs
export RISC0_DEV_MODE=1
cargo build -p host --release > "$LOG" 2>&1 || { tail -100 "$LOG"; exit 1; }
echo BUILD_OK
tail -20 "$LOG"
