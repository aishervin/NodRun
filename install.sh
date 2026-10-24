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

if ! proot-distro login debian -- true >/dev/null 2>&1; then
  printf 'Installing Debian runtime...\n'
  proot-distro install debian
fi

printf 'Installing OpenCode server...\n'
proot-distro login debian -- bash -lc '
  set -e
  if ! command -v opencode >/dev/null 2>&1; then
    apt-get update
    apt-get install -y ca-certificates nodejs npm
    npm install -g opencode-ai
  fi
'

mkdir -p "$HOME/.config/opencode" "$HOME/.local/share/opencode"
printf '\nStarting OpenCode on http://127.0.0.1:4096\n'
printf 'Keep this Termux session open while using NodRun. Press Ctrl+C to stop the server.\n\n'

exec proot-distro login debian \
  --bind "$HOME:/root/workspace" \
  --bind "$HOME/.config/opencode:/root/.config/opencode" \
  --bind "$HOME/.local/share/opencode:/root/.local/share/opencode" \
  -- bash -lc 'cd /root/workspace && exec opencode serve --hostname 127.0.0.1 --port 4096'
