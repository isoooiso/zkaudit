#!/usr/bin/env bash
# Wrapper so docker.exe from WSL can mount WSL/DrvFS paths into Linux containers.
DOCKER_EXE="/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"

convert_volume() {
  local vol="$1"
  local host="${vol%%:*}"
  local rest="${vol#*:}"
  if [[ "$host" == /mnt/c/* || "$host" == /home/* || "$host" == /tmp/* ]]; then
    host=$(wslpath -w "$host" | tr '\\' '/')
  fi
  echo "${host}:${rest}"
}

args=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-v" && -n "${2:-}" ]]; then
    args+=(-v "$(convert_volume "$2")")
    shift 2
  else
    args+=("$1")
    shift
  fi
done

exec "$DOCKER_EXE" "${args[@]}"
