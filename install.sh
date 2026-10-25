#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# NodRun Termux installer. Safe to rerun; does not clone the mobile app repository.
DISTRO="alpine"
PORT="${NODRUN_PORT:-4096}"
HOST="${NODRUN_HOST:-127.0.0.1}"
LOG="$HOME/.nodrun-opencode.log"
PIDFILE="$HOME/.nodrun-opencode.pid"

say() { printf '\n[NodRun] %s\n' "$*"; }
die() { say "ERROR: $*"; exit 1; }
on_error() {
  rc=$?
  printf '\n[NodRun] ERROR: installer stopped at line %s (exit %s).\n' "${BASH_LINENO[0]:-unknown}" "$rc" >&2
  printf '[NodRun] Check network/storage, then rerun the same installer command.\n' >&2
  exit "$rc"
}
trap on_error ERR

command -v pkg >/dev/null 2>&1 || die "Run this script in Termux, not inside Alpine."
[ -n "${PREFIX:-}" ] || die "Termux PREFIX is missing. Open Termux and rerun."
case "$PORT" in ''|*[!0-9]*) die "NODRUN_PORT must be numeric.";; esac
[ "$PORT" -ge 1024 ] && [ "$PORT" -le 65535 ] || die "Port must be between 1024 and 65535."

say "Repairing Termux package state and installing prerequisites..."
pkg update -y
pkg install -y proot-distro curl ca-certificates coreutils procps

say "Checking Alpine..."
if ! proot-distro login "$DISTRO" -- true >/dev/null 2>&1; then
  if proot-distro list 2>/dev/null | grep -Eiq 'alpine.*(installed|stopped|running)'; then
    die "Alpine is registered but cannot start. Installer stopped without deleting your Alpine data. Run: proot-distro login alpine"
  fi
  say "Installing Alpine Linux. First setup can use several hundred MiB..."
  proot-distro install "$DISTRO"
fi
proot-distro login "$DISTRO" -- true >/dev/null 2>&1 || die "Alpine still cannot start; no data was deleted."

say "Installing/verifying OpenCode inside Alpine (safe to rerun)..."
proot-distro login "$DISTRO" -- sh -lc '
  set -eu
  apk update
  apk add --no-cache nodejs npm git curl bash ca-certificates
  npm install --global opencode-ai
  command -v opencode
  opencode --version
' || die "OpenCode install/verification failed. Rerun this installer to retry."

mkdir -p "$PREFIX/bin" "$HOME/.config/nodrun"
cat > "$HOME/.config/nodrun/server.env" <<EOF
NODRUN_HOST="$HOST"
NODRUN_PORT="$PORT"
EOF
chmod 600 "$HOME/.config/nodrun/server.env"

cat > "$PREFIX/bin/ocr" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u
DISTRO="alpine"
PORT="${NODRUN_PORT:-4096}"
HOST="${NODRUN_HOST:-127.0.0.1}"
LOG="$HOME/.nodrun-opencode.log"
PIDFILE="$HOME/.nodrun-opencode.pid"
URL="http://127.0.0.1:$PORT"

# Reuse a healthy API instead of creating duplicate servers.
if curl -fsS --max-time 2 "$URL/global/health" >/dev/null 2>&1; then
  echo "OpenCode API is already responding at $URL"
  exit 0
fi

# Stop only the launcher recorded by NodRun; never kill arbitrary port owners.
if [ -f "$PIDFILE" ]; then
  oldpid="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
    kill "$oldpid" 2>/dev/null || true
    sleep 2
    kill -0 "$oldpid" 2>/dev/null && kill -KILL "$oldpid" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
fi

if curl -sS --max-time 2 "$URL/" >/dev/null 2>&1; then
  echo "Port $PORT is occupied by a service that did not identify as OpenCode."
  echo "For safety, it was not killed. Stop that service or set NODRUN_PORT."
  exit 1
fi

: > "$LOG"
nohup proot-distro login "$DISTRO" -- sh -lc "exec opencode serve --hostname '$HOST' --port '$PORT'" >>"$LOG" 2>&1 </dev/null &
pid=$!
echo "$pid" > "$PIDFILE"

i=0
while [ "$i" -lt 45 ]; do
  if curl -fsS --max-time 2 "$URL/global/health" >/dev/null 2>&1; then
    echo "OpenCode API is ready: $URL"
    echo "Log: $LOG"
    exit 0
  fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 1
  i=$((i + 1))
done

echo "OpenCode did not become healthy. Recent log:"
tail -n 80 "$LOG" 2>/dev/null || true
exit 1
EOF
chmod 700 "$PREFIX/bin/ocr"

cat > "$PREFIX/bin/ock" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -u
PIDFILE="$HOME/.nodrun-opencode.pid"
[ -f "$PIDFILE" ] || { echo "No NodRun launcher PID file found."; exit 0; }
pid="$(cat "$PIDFILE" 2>/dev/null || true)"
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  kill "$pid" 2>/dev/null || true
  sleep 2
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
  echo "Stop signal sent to NodRun launcher (PID $pid)."
else
  echo "NodRun launcher was already stopped."
fi
rm -f "$PIDFILE"
EOF
chmod 700 "$PREFIX/bin/ock"

command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true

say "Installation and verification completed."
say "Starting the OpenCode API server now..."
"$PREFIX/bin/ocr" || { say "Automatic start failed. Diagnostics: tail -n 100 $LOG"; exit 1; }
say "In NodRun, connect to: http://127.0.0.1:$PORT"
say "Stop the launcher with: ock"
say "Diagnostics: tail -n 100 $LOG"
