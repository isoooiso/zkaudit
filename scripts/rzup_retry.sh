#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.risc0/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

echo "=== retry rzup install ==="
rzup install || true

echo "=== install risc0-groth16 ==="
rzup install risc0-groth16 || true

echo "=== cargo risczero ==="
cargo risczero --version 2>&1 || true

echo "=== rzup show ==="
rzup show 2>&1 || true
