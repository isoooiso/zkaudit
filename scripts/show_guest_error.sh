#!/usr/bin/env bash
set -euo pipefail
find "$HOME/zkaudit/zkvm/target/riscv-guest" -name 'output-bin-audit_v1' -printf '%p\n' 2>/dev/null | head -1 | xargs -r cat
