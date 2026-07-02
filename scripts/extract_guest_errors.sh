#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/bin:$HOME/.cargo/bin:/usr/bin:/bin"
mkdir -p "$HOME/bin"
ln -sf /mnt/c/Users/petre/Desktop/zkaudit/scripts/docker_wsl_wrapper.sh "$HOME/bin/docker"
chmod +x "$HOME/bin/docker"
cd "$HOME/zkaudit/zkvm"
cargo clean -p methods
cargo build -p methods --release 2>/dev/null || true
find target/riscv-guest -name 'output-bin-audit_v1' | head -1 | while read -r f; do
  grep -o '"message":"[^"]*"' "$f" | head -5
  echo "---"
  grep '"level":"error"' "$f" | head -3
done
