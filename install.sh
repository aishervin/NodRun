#!/usr/bin/env bash
set -euo pipefail

case "$(uname -m)" in
  aarch64|x86_64) ;;
  *) printf 'OpenCode server requires a 64-bit ARM or x86_64 device.\n' >&2; exit 1 ;;
esac

if ! command -v proot-distro >/dev/null 2>&1; then
  pkg update -y
  pkg install -y proot-distro
fi

if ! proot-distro login alpine -- true >/dev/null 2>&1; then
  printf 'Installing Alpine runtime...\n'
  proot-distro install alpine
fi

printf 'Installing OpenCode server...\n'
proot-distro login alpine -- sh -lc '
  set -e
  apk add --no-cache ca-certificates nodejs npm gcompat libstdc++
  if ! command -v opencode >/dev/null 2>&1; then
    npm install -g opencode-ai
  fi
'

mkdir -p "$HOME/.config/opencode" "$HOME/.local/share/opencode"
printf '\nStarting OpenCode on http://127.0.0.1:4096\n'
printf 'Keep this Termux session open while using NodRun. Press Ctrl+C to stop the server.\n\n'

exec proot-distro login alpine \
  --bind "$HOME:/root/workspace" \
  --bind "$HOME/.config/opencode:/root/.config/opencode" \
  --bind "$HOME/.local/share/opencode:/root/.local/share/opencode" \
  -- sh -lc 'cd /root/workspace && exec opencode serve --hostname 127.0.0.1 --port 4096'
