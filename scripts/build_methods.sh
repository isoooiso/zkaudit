#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/bin:$HOME/.cargo/bin:/usr/bin:/bin"
export RUST_BACKTRACE=1
# Use docker wrapper for risc0 guest builds on WSL
if [ -x /mnt/c/Users/petre/Desktop/zkaudit/scripts/docker_wsl_wrapper.sh ]; then
  ln -sf /mnt/c/Users/petre/Desktop/zkaudit/scripts/docker_wsl_wrapper.sh "$HOME/bin/docker"
  chmod +x "$HOME/bin/docker" 2>/dev/null || true
fi
cd /mnt/c/Users/petre/Desktop/zkaudit/zkvm
LOG=/mnt/c/Users/petre/Desktop/zkaudit/logs/methods_build.log
mkdir -p /mnt/c/Users/petre/Desktop/zkaudit/logs
export RISC0_DEV_MODE=1
cargo build -p methods --release 2>&1 | tee "$LOG"
echo METHODS_OK
