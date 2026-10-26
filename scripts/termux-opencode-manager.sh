#!/data/data/com.termux/files/usr/bin/bash
# NodRun local OpenCode engine manager.
# Deliberately installs/runs ONLY the OpenCode API; never installs or opens the SHENhero web UI.
set -euo pipefail

ACTION="${1:-status}"
BIN="$HOME/.local/bin"
STATE="$HOME/.local/state/nodrun-opencode"
mkdir -p "$BIN" "$STATE"
LOG="$STATE/server.log"
PIDFILE="$STATE/server.pid"
PORT="${NODRUN_OPENCODE_PORT:-4096}"
INSTALLER_URL="https://raw.githubusercontent.com/bd-loser/opencode-bionic/main/install.sh"
API_URL="http://127.0.0.1:$PORT"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "Invalid NODRUN_OPENCODE_PORT: $PORT" >&2
  exit 64
fi

api_ready() {
  curl -fsS --max-time 2 "$API_URL/global/health" >/dev/null 2>&1
}

start_server() {
  if api_ready; then
    echo "OpenCode API is already responding at $API_URL"
    return 0
  fi

  if ! command -v opencode >/dev/null 2>&1; then
    echo "OpenCode is not installed. Tap Install / Repair first." >&2
    exit 2
  fi

  # This is the local API only. Do not call opencode-web-open or install the web skin.
  nohup opencode serve --hostname 127.0.0.1 --port "$PORT" >"$LOG" 2>&1 </dev/null &
  echo "$!" > "$PIDFILE"

  for _ in $(seq 1 40); do
    if api_ready; then
      echo "OpenCode API is ready at $API_URL"
      return 0
    fi
    if [ -f "$PIDFILE" ] && ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  echo "OpenCode did not become ready on port $PORT. Last log lines:" >&2
  tail -n 40 "$LOG" >&2 || true
  exit 3
}

case "$ACTION" in
  install|repair)
    pkg update -y
    pkg install -y curl
    # Use the Termux-compatible OpenCode installer only. The separate SHENhero
    # install.sh also installs a web proxy/UI launcher, which NodRun does not need.
    if ! command -v opencode >/dev/null 2>&1 || [ "$ACTION" = "repair" ]; then
      curl -fsSL "$INSTALLER_URL" -o "$STATE/opencode-install.sh"
      bash "$STATE/opencode-install.sh"
    else
      echo "OpenCode is already installed; skipping reinstall."
    fi
    start_server
    ;;
  start)
    start_server
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      PID="$(cat "$PIDFILE")"
      if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
      fi
      rm -f "$PIDFILE"
    fi
    # Fallback for a server started before its PID file was written.
    pkill -f "^opencode serve --hostname 127\\.0\\.0\\.1 --port $PORT$" 2>/dev/null || true
    echo "Stop requested for OpenCode on port $PORT"
    ;;
  status)
    if api_ready; then
      curl -fsS --max-time 2 "$API_URL/global/health"
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
