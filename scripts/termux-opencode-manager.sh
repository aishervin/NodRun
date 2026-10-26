#!/data/data/com.termux/files/usr/bin/bash
# NodRun local OpenCode engine manager. Intended to be invoked by NodRun via Termux RUN_COMMAND.
set -euo pipefail
ACTION="${1:-status}"
BIN="$HOME/.local/bin"
STATE="$HOME/.local/state/nodrun-opencode"
MANAGER="$BIN/nodrun-opencode-manager"
mkdir -p "$BIN" "$STATE"
LOG="$STATE/server.log"
PIDFILE="$STATE/server.pid"
PORT="${NODRUN_OPENCODE_PORT:-4096}"
INSTALLER_URL="https://raw.githubusercontent.com/bd-loser/opencode-bionic/main/install.sh"

start_server() {
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/global/health" >/dev/null 2>&1; then
    echo "OpenCode is already responding on port $PORT"
    return 0
  fi
  command -v opencode >/dev/null 2>&1 || { echo "OpenCode is not installed. Tap Install / Repair first."; exit 2; }
  nohup opencode serve --hostname 127.0.0.1 --port "$PORT" >"$LOG" 2>&1 </dev/null &
  echo "$!" > "$PIDFILE"
  for _ in $(seq 1 30); do
    if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/global/health" >/dev/null 2>&1; then
      echo "OpenCode API is ready at http://127.0.0.1:$PORT"
      exit 0
    fi
    sleep 1
  done
  echo "OpenCode did not become ready. Last log lines:"
  tail -n 30 "$LOG" || true
  exit 3
}

case "$ACTION" in
  install|repair)
    pkg update -y
    pkg install -y curl dpkg jq
    curl -fsSL "$INSTALLER_URL" -o "$STATE/opencode-install.sh"
    bash "$STATE/opencode-install.sh"
    start_server
    ;;
  start)
    start_server
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      PID="$(cat "$PIDFILE")"
      if kill -0 "$PID" 2>/dev/null; then kill "$PID"; fi
      rm -f "$PIDFILE"
    fi
    # Fallback for a server started before the PID file was written.
    pkill -f '^opencode serve --hostname 127\.0\.0\.1 --port 4096$' 2>/dev/null || true
    echo "Stop requested"
    ;;
  status)
    if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/global/health"; then
      echo
    else
      echo "OpenCode API is not responding on port $PORT"
      exit 1
    fi
    ;;
  logs)
    tail -n 80 "$LOG" 2>/dev/null || echo "No server log yet"
    ;;
  *)
    echo "Usage: nodrun-opencode-manager {install|repair|start|stop|status|logs}"
    exit 64
    ;;
esac
