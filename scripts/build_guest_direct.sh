#!/usr/bin/env bash
set -x
export PATH="$HOME/.cargo/bin:$HOME/bin:/usr/bin:/bin"
cd /mnt/c/Users/petre/Desktop/zkaudit/zkvm/methods/guest
/home/petre/.risc0/toolchains/v1.94.1-rust-x86_64-unknown-linux-gnu/bin/cargo build --release --target riscv32im-risc0-zkvm-elf 2>&1 | tee /mnt/c/Users/petre/Desktop/zkaudit/logs/guest_build.log
