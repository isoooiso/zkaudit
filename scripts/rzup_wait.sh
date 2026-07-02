#!/usr/bin/env bash
export PATH="$HOME/.risc0/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

FILE="$HOME/.risc0/tmp/rust-toolchain-x86_64-unknown-linux-gnu.tar.gz"
for i in $(seq 1 120); do
  if ! pgrep -f "rzup install" >/dev/null 2>&1; then
    echo "rzup install process finished"
    break
  fi
  SIZE=$(stat -c '%s' "$FILE" 2>/dev/null || echo 0)
  echo "$(date +%H:%M:%S) rust tarball bytes: $SIZE"
  sleep 30
done

echo "=== final rzup show ==="
rzup show 2>&1 || true

if rzup show 2>&1 | grep -q rust; then
  echo "=== installing groth16 ==="
  rzup install risc0-groth16 2>&1 || true
fi

echo "=== cargo risczero ==="
cargo risczero --version 2>&1 || true

echo "=== final rzup show ==="
rzup show 2>&1 || true
