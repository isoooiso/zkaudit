#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.cargo/bin:/usr/bin:/bin"
SRC=/mnt/c/Users/petre/Desktop/zkaudit/zkvm/methods/guest
DST=$HOME/zkaudit_build/guest
rm -rf "$DST"
mkdir -p "$DST"
cp -a "$SRC/." "$DST/"
cd "$DST"
export CARGO_TARGET_DIR="$HOME/zkaudit_build/target"
/home/petre/.risc0/toolchains/v1.94.1-rust-x86_64-unknown-linux-gnu/bin/cargo build --release --bin audit_v1 --target riscv32im-risc0-zkvm-elf --message-format=short 2>&1 | tee /mnt/c/Users/petre/Desktop/zkaudit/logs/guest_native.log
