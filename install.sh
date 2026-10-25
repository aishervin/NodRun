#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# NodRun Termux installer
# Runs the actual OpenCode API server inside Alpine via proot-distro.
# It intentionally does NOT use Python's static HTTP server on port 4096.

REPO_URL="https://github.com/aishervin/NodRun.git"
PROJECT_DIR="$HOME/NodRun"
DISTRO="alpine"
PORT="${NODRUN_PORT:-4096}"
HOST="${NODRUN_HOST:-127.0.0.1}"

say() { printf '\n[NodRun] %s\n' "$*"; }
die() { say "ERROR: $*"; exit 1; }
command -v pkg >/dev/null 2>&1 || die "Run this script from Termux, not inside Alpine or another shell."

say "Checking Termux prerequisites..."
pkg update -y
pkg install -y proot-distro git curl

if ! proot-distro list 2>/dev/null | grep -qiE '(^|[[:space:]])alpine([[:space:]]|$|\*)'; then
  say "Installing Alpine Linux (first run can take a while)..."
  proot-distro install "$DISTRO"
fi

say "Preparing NodRun repository..."
if [ -d "$PROJECT_DIR/.git" ]; then
  git -C "$PROJECT_DIR" pull --ff-only origin main || say "Git update skipped; keeping the existing checkout."
else
  if [ -e "$PROJECT_DIR" ]; then
    die "$PROJECT_DIR exists but is not a Git checkout. Move it aside or remove it, then rerun."
  fi
  git clone "$REPO_URL" "$PROJECT_DIR"
fi

say "Installing OpenCode and required packages inside Alpine..."
proot-distro login "$DISTRO" -- sh -lc '
  set -e
  apk update
  apk add --no-cache nodejs npm git curl bash ca-certificates
  npm install -g opencode-ai
  command -v opencode
  opencode --version
'

mkdir -p "$HOME/.config/nodrun"
cat > "$HOME/.config/nodrun/server.env" <<EOF
NODRUN_HOST="$HOST"
NODRUN_PORT="$PORT"
EOF
chmod 600 "$HOME/.config/nodrun/server.env"

cat > "$PREFIX/bin/ocr" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u
PORT="${NODRUN_PORT:-4096}"
HOST="${NODRUN_HOST:-127.0.0.1}"
LOG="$HOME/.nodrun-opencode.log"

# Avoid killing unrelated services: stop only a previously recorded NodRun launcher.
if [ -f "$HOME/.nodrun-opencode.pid" ]; then
  oldpid="$(cat "$HOME/.nodrun-opencode.pid" 2>/dev/null || true)"
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    kill "$oldpid" 2>/dev/null || true
    sleep 1
  fi
  rm -f "$HOME/.nodrun-opencode.pid"
fi

if curl --silent --show-error --max-time 2 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
  echo "Something is already listening on port $PORT."
  echo "Check it before starting NodRun. Log: $LOG"
  exit 1
fi

nohup proot-distro login alpine -- sh -lc "exec opencode serve --hostname '$HOST' --port '$PORT'" >>"$LOG" 2>&1 </dev/null &
echo "$!" > "$HOME/.nodrun-opencode.pid"
sleep 3

if kill -0 "$(cat "$HOME/.nodrun-opencode.pid")" 2>/dev/null; then
  echo "NodRun OpenCode server launch requested."
  echo "URL: http://127.0.0.1:$PORT"
  echo "Log: $LOG"
  echo "If the app cannot connect, inspect the log and ensure the app uses this URL."
else
  echo "Server process exited. Recent log:"
  tail -n 60 "$LOG" 2>/dev/null || true
  exit 1
fi
EOF
chmod +x "$PREFIX/bin/ocr"

cat > "$PREFIX/bin/ock" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u
if [ -f "$HOME/.nodrun-opencode.pid" ]; then
  pid="$(cat "$HOME/.nodrun-opencode.pid" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    echo "Stop signal sent to NodRun launcher (PID $pid)."
  else
    echo "NodRun launcher is not running."
  fi
  rm -f "$HOME/.nodrun-opencode.pid"
else
  echo "No NodRun launcher PID file found."
fi
EOF
chmod +x "$PREFIX/bin/ock"

if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || true
fi

say "Installation completed."
say "Start the actual OpenCode API server with: ocr"
say "Stop the launcher with: ock"
say "In NodRun, connect to: http://127.0.0.1:$PORT"
say "Diagnostics: tail -n 100 ~/.nodrun-opencode.log"
