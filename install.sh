#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

REPO="${OC_SKIN_REPO:-aishervin/SHENhero}"
BASE="${OC_SKIN_BASE:-termux-skin}"
RAW="https://raw.githubusercontent.com/${REPO}/main/${BASE}"
PORT="${OPENCODE_PORT:-4096}"
HOST="127.0.0.1"

red() {
  printf '\033[0;31m%s\033[0m\n' "$*" >&2
}

grn() {
  printf '\033[0;32m%s\033[0m\n' "$*"
}

say() {
  printf '  %s\n' "$*"
}

# Verify Termux
if [ -z "${PREFIX:-}" ] || [ ! -d "$PREFIX" ]; then
  red "This installer targets Termux."
  red "PREFIX is not set."
  exit 1
fi

# Install required dependencies
if ! command -v curl >/dev/null 2>&1 ||
   ! command -v python3 >/dev/null 2>&1; then
  grn "Installing curl and Python..."
  pkg install -y curl python
fi

# Install OpenCode if missing
if ! command -v opencode >/dev/null 2>&1; then
  grn "OpenCode not found. Installing..."

  curl -fsSL \
    https://raw.githubusercontent.com/bd-loser/opencode-bionic/main/install.sh \
    | bash
fi

if ! command -v opencode >/dev/null 2>&1; then
  red "OpenCode installation failed."
  exit 1
fi

# Install/update SHENhero web UI assets
grn "Updating SHENhero web UI assets..."

mkdir -p "$PREFIX/bin" "$HOME/.opencode-web"

curl -fsSL \
  "$RAW/bin/opencode-web-update" \
  -o "$PREFIX/bin/opencode-web-update"

chmod +x "$PREFIX/bin/opencode-web-update"

"$PREFIX/bin/opencode-web-update"

# Start only the OpenCode API server.
# Do not launch the browser or the SHENhero web proxy.
grn "Starting OpenCode API server..."
say "Endpoint: http://${HOST}:${PORT}"
say "The app is already configured to use this endpoint."
say "Keep Termux running while using the app."
say "Press Ctrl+C to stop the server."

exec opencode serve \
  --hostname "$HOST" \
  --port "$PORT"
