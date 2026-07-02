#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.risc0/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
source "$HOME/.bashrc" 2>/dev/null || true

echo "=== uname ==="
uname -a

echo "=== rustc/cargo ==="
rustc --version
cargo --version

echo "=== docker ==="
docker ps

echo "=== stellar ==="
stellar --version

echo "=== rzup ==="
rzup --version

echo "=== installing risc0 toolchain ==="
rzup install
rzup install risc0-groth16

echo "=== cargo risczero ==="
cargo risczero --version 2>&1 || true

echo "=== rzup show ==="
rzup show 2>&1 || true

echo "=== git ==="
cd /mnt/c/Users/petre/Desktop/zkaudit
git status
