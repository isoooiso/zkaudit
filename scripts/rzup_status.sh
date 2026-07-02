#!/usr/bin/env bash
export PATH="$HOME/.risc0/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
ps aux | grep rzup | grep -v grep || true
ls -lah ~/.risc0/tmp/ 2>/dev/null || true
echo "=== rzup show ==="
rzup show 2>&1 || true
