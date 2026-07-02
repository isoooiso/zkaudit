#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/bin"
cat > "$HOME/bin/docker" <<'EOF'
#!/usr/bin/env bash
exec "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" "$@"
EOF
chmod +x "$HOME/bin/docker"
export PATH="$HOME/bin:$HOME/.risc0/bin:$HOME/.cargo/bin:$PATH"
cd /mnt/c/Users/petre/Desktop/zkaudit/zkvm
RISC0_DEV_MODE=0 cargo run -p host --release
