#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/bin:$HOME/.cargo/bin:/usr/bin:/bin"
export RUST_BACKTRACE=1
export RISC0_BUILD_DEBUG=1
export RISC0_DEV_MODE=1
cd /mnt/c/Users/petre/Desktop/zkaudit/zkvm/methods
LOG=/mnt/c/Users/petre/Desktop/zkaudit/logs/methods_debug.log
mkdir -p /mnt/c/Users/petre/Desktop/zkaudit/logs
cargo build --release 2>&1 | tee "$LOG"
echo OK
