#!/data/data/com.termux/files/usr/bin/bash
# NodRun Termux bootstrap: install/repair OpenCode and start its local API.
# Safe to rerun; does not delete the user's Termux or OpenCode data.
set -euo pipefail

if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
  echo "Run this installer inside Termux, not in a desktop shell." >&2
  exit 1
fi
if [ "$(uname -m)" != "aarch64" ]; then
  echo "The bundled OpenCode build currently supports Android aarch64 only." >&2
  exit 1
fi

pkg update -y
pkg install -y curl
mkdir -p "$HOME/.local/bin"
curl -fsSL "https://raw.githubusercontent.com/aishervin/NodRun/main/scripts/termux-opencode-manager.sh" -o "$HOME/.local/bin/nodrun-opencode-manager"
chmod 700 "$HOME/.local/bin/nodrun-opencode-manager"
"$HOME/.local/bin/nodrun-opencode-manager" install

cat <<'EOF'

NodRun local OpenCode engine is ready.
API:  http://127.0.0.1:4096
Logs: ~/.local/state/nodrun-opencode/server.log
Commands:
  nodrun-opencode-manager start
  nodrun-opencode-manager stop
  nodrun-opencode-manager status
  nodrun-opencode-manager logs
EOF
