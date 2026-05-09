#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-/mnt/c/Users/ASUS/Code/temporary_assignment}"
BACKEND_DIR="${BACKEND_DIR:-$REPO_ROOT/backend}"
AGENTS_DIR="${AGENTS_DIR:-$REPO_ROOT/agents}"
STATE_DIR="${STATE_DIR:-$HOME/.trashbounty}"
LOG_DIR="$STATE_DIR/logs"
PID_DIR="$STATE_DIR/pids"
AGENTS_VENV="${AGENTS_VENV:-$STATE_DIR/agents-venv}"

BACKEND_PID_FILE="$PID_DIR/backend.pid"
AGENTS_PID_FILE="$PID_DIR/agents.pid"
TUNNEL_PID_FILE="$PID_DIR/cloudflared.pid"

BACKEND_LOG="$LOG_DIR/backend.log"
AGENTS_LOG="$LOG_DIR/agents.log"
TUNNEL_LOG="$LOG_DIR/cloudflared.log"

DEFAULT_BACKEND_PORT="8080"
BACKEND_PORT="${BACKEND_PORT:-$DEFAULT_BACKEND_PORT}"
BACKEND_HEALTH_URL="${BACKEND_HEALTH_URL:-http://127.0.0.1:${BACKEND_PORT}/v1/health}"
AGENTS_HEALTH_URL="${AGENTS_HEALTH_URL:-http://127.0.0.1:8000/health}"
PUBLIC_HEALTH_URL="${PUBLIC_HEALTH_URL:-https://trashbounty.kiryuken.my.id/v1/health}"

TUNNEL_NAME="${TUNNEL_NAME:-go-api}"
TUNNEL_CONFIG="${TUNNEL_CONFIG:-$HOME/.cloudflared/config.yml}"
START_TUNNEL="${START_TUNNEL:-true}"

USE_COLOR=false
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  USE_COLOR=true
fi

if [[ "$USE_COLOR" == "true" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET=''
  C_BOLD=''
  C_DIM=''
  C_BLUE=''
  C_CYAN=''
  C_GREEN=''
  C_YELLOW=''
  C_RED=''
fi

usage() {
  cat <<'EOF'
Usage: start-services.sh <command>

Commands:
  start     Start backend, agents, and optional Cloudflare tunnel
  stop      Stop services that were started by this script
  restart   Restart services that were started by this script
  status    Show service status and health
  logs      Show log file locations and the last few lines

Environment overrides:
  REPO_ROOT, BACKEND_DIR, AGENTS_DIR, AGENTS_VENV, BACKEND_PORT
  BACKEND_HEALTH_URL, AGENTS_HEALTH_URL, PUBLIC_HEALTH_URL
  TUNNEL_NAME, TUNNEL_CONFIG, START_TUNNEL

BACKEND_PORT defaults to 8080 for repo-tracked local startup.
Use BACKEND_PORT=8081 only as an explicit tunnel-only local override.
EOF
}

paint() {
  local color="$1"
  shift
  printf '%s%s%s' "$color" "$*" "$C_RESET"
}

banner() {
  printf '\n%s\n' "$(paint "$C_CYAN$C_BOLD" '=====================================')"
  printf '%s\n' "$(paint "$C_CYAN$C_BOLD" '  TrashBounty Service Orchestrator  ')"
  printf '%s\n' "$(paint "$C_CYAN$C_BOLD" '=====================================')"
  printf '%s\n' "$(paint "$C_DIM" "repo: $REPO_ROOT")"
  printf '%s\n' "$(paint "$C_DIM" "backend port: $BACKEND_PORT | tunnel: $START_TUNNEL")"
}

section() {
  printf '\n%s\n' "$(paint "$C_BLUE$C_BOLD" "== $* ==")"
}

status_line() {
  local name="$1"
  local state="$2"
  local detail="${3:-}"
  local color="$C_RED"

  case "$state" in
    managed|running|healthy)
      color="$C_GREEN"
      ;;
    external|disabled)
      color="$C_CYAN"
      ;;
    warning)
      color="$C_YELLOW"
      ;;
  esac

  printf '%s%-12s%s %s' "$C_BOLD" "$name" "$C_RESET" "$(paint "$color" "$state")"
  if [[ -n "$detail" ]]; then
    printf ' %s' "$(paint "$C_DIM" "$detail")"
  fi
  printf '\n'
}

show_endpoints() {
  section "Endpoints"
  printf '%s\n' "$(paint "$C_DIM" "backend : $BACKEND_HEALTH_URL")"
  printf '%s\n' "$(paint "$C_DIM" "agents  : $AGENTS_HEALTH_URL")"
  if [[ "$START_TUNNEL" == "true" ]]; then
    printf '%s\n' "$(paint "$C_DIM" "public  : $PUBLIC_HEALTH_URL")"
  fi
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
  printf '[%s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

fail() {
  printf '[%s] ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
  exit 1
}

ensure_dirs() {
  mkdir -p "$LOG_DIR" "$PID_DIR"
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "Command '$cmd' tidak ditemukan"
}

port_in_use() {
  local port="$1"
  python3 - "$port" <<'PY'
import socket
import sys

port = int(sys.argv[1])
sock = socket.socket()
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

try:
    sock.bind(("0.0.0.0", port))
except OSError:
    raise SystemExit(0)
finally:
    sock.close()

raise SystemExit(1)
PY
}

pid_is_running() {
  local pid_file="$1"

  [[ -f "$pid_file" ]] || return 1

  local pid
  pid="$(<"$pid_file")"
  [[ -n "$pid" ]] || return 1

  kill -0 "$pid" 2>/dev/null
}

cleanup_pid_file() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]] && ! pid_is_running "$pid_file"; then
    rm -f "$pid_file"
  fi
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local attempts="${3:-30}"

  local i
  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS --connect-timeout 1 --max-time 2 "$url" >/dev/null 2>&1; then
      log "$label sehat di $url"
      return 0
    fi
    sleep 1
  done

  return 1
}

start_process() {
  local label="$1"
  local pid_file="$2"
  local log_file="$3"
  local command="$4"

  ensure_dirs
  cleanup_pid_file "$pid_file"

  nohup bash -lc "$command" >>"$log_file" 2>&1 &
  local pid=$!
  echo "$pid" >"$pid_file"
  sleep 1

  if ! kill -0 "$pid" 2>/dev/null; then
    warn "$label gagal start. Cek log: $log_file"
    return 1
  fi

  log "$label dijalankan dengan PID $pid"
}

stop_process() {
  local label="$1"
  local pid_file="$2"

  cleanup_pid_file "$pid_file"

  if ! [[ -f "$pid_file" ]]; then
    log "$label tidak dikelola oleh script ini"
    return 0
  fi

  local pid
  pid="$(<"$pid_file")"

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    for _ in {1..10}; do
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
      warn "$label masih hidup, kirim SIGKILL"
      kill -9 "$pid" 2>/dev/null || true
    fi
    log "$label dihentikan"
  fi

  rm -f "$pid_file"
}

ensure_agents_venv() {
  require_cmd python3

  if [[ ! -d "$AGENTS_VENV" ]]; then
    log "Membuat virtualenv agents di $AGENTS_VENV"
    python3 -m venv "$AGENTS_VENV"
  fi

  if ! "$AGENTS_VENV/bin/python" - <<'PY' >/dev/null 2>&1
import fastapi
import httpx
import telegram
import uvicorn
from dotenv import load_dotenv
PY
  then
    log "Menginstal dependency agents"
    "$AGENTS_VENV/bin/pip" install -r "$AGENTS_DIR/requirements.txt"
  fi
}

backend_running_external() {
  if curl -fsS --connect-timeout 1 --max-time 2 "$BACKEND_HEALTH_URL" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

agents_running_external() {
  if curl -fsS --connect-timeout 1 --max-time 2 "$AGENTS_HEALTH_URL" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

tunnel_running_external() {
  if pgrep -af "cloudflared.*tunnel.*run.*$TUNNEL_NAME" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

start_backend() {
  require_cmd go
  require_cmd python3

  if [[ "$BACKEND_PORT" == "8081" ]]; then
    log "Menggunakan BACKEND_PORT=8081 sebagai override tunnel-only lokal"
  fi

  if pid_is_running "$BACKEND_PID_FILE"; then
    log "Backend sudah dijalankan oleh script ini"
    return 0
  fi

  if backend_running_external; then
    log "Backend sudah aktif di luar script ini"
    return 0
  fi

  if port_in_use "$BACKEND_PORT"; then
    fail "Port $BACKEND_PORT sudah dipakai proses lain dan tidak merespons sebagai backend Trash Bounty. Hentikan proses itu atau set BACKEND_PORT secara eksplisit; script tidak akan pindah port otomatis."
  fi

  start_process \
    "Backend" \
    "$BACKEND_PID_FILE" \
    "$BACKEND_LOG" \
    "cd '$BACKEND_DIR' && export PORT='$BACKEND_PORT' && exec go run ./cmd/server"

  wait_for_http "$BACKEND_HEALTH_URL" "Backend" 45 || {
    tail -n 40 "$BACKEND_LOG" >&2 || true
    fail "Backend tidak sehat setelah start"
  }
}

start_agents() {
  ensure_agents_venv

  if pid_is_running "$AGENTS_PID_FILE"; then
    log "Agents sudah dijalankan oleh script ini"
    return 0
  fi

  if agents_running_external; then
    log "Agents sudah aktif di luar script ini"
    return 0
  fi

  start_process \
    "Agents" \
    "$AGENTS_PID_FILE" \
    "$AGENTS_LOG" \
    "source '$AGENTS_VENV/bin/activate' && cd '$AGENTS_DIR' && exec python main.py"

  wait_for_http "$AGENTS_HEALTH_URL" "Agents" 45 || {
    tail -n 40 "$AGENTS_LOG" >&2 || true
    fail "Agents tidak sehat setelah start"
  }
}

start_tunnel() {
  if [[ "$START_TUNNEL" != "true" ]]; then
    log "Cloudflare tunnel dilewati karena START_TUNNEL=$START_TUNNEL"
    return 0
  fi

  require_cmd cloudflared

  [[ -f "$TUNNEL_CONFIG" ]] || fail "Config cloudflared tidak ditemukan di $TUNNEL_CONFIG"

  if pid_is_running "$TUNNEL_PID_FILE"; then
    log "Cloudflare tunnel sudah dijalankan oleh script ini"
    return 0
  fi

  if tunnel_running_external; then
    log "Cloudflare tunnel '$TUNNEL_NAME' sudah aktif di luar script ini"
    return 0
  fi

  start_process \
    "Cloudflare tunnel" \
    "$TUNNEL_PID_FILE" \
    "$TUNNEL_LOG" \
    "exec cloudflared tunnel --config '$TUNNEL_CONFIG' run '$TUNNEL_NAME'"

  sleep 5
  if ! pid_is_running "$TUNNEL_PID_FILE"; then
    tail -n 40 "$TUNNEL_LOG" >&2 || true
    fail "Cloudflare tunnel gagal start"
  fi

  if [[ -n "$PUBLIC_HEALTH_URL" ]]; then
    if curl -fsS --connect-timeout 2 --max-time 5 "$PUBLIC_HEALTH_URL" >/dev/null 2>&1; then
      log "Tunnel merespons di $PUBLIC_HEALTH_URL"
    else
      warn "Tunnel hidup tapi health publik belum merespons: $PUBLIC_HEALTH_URL"
    fi
  fi
}

show_status() {
  cleanup_pid_file "$BACKEND_PID_FILE"
  cleanup_pid_file "$AGENTS_PID_FILE"
  cleanup_pid_file "$TUNNEL_PID_FILE"

  section "Service Status"

  if pid_is_running "$BACKEND_PID_FILE"; then
    status_line "Backend" "managed" "pid $(<"$BACKEND_PID_FILE")"
  elif backend_running_external; then
    status_line "Backend" "external"
  else
    status_line "Backend" "stopped"
  fi

  if pid_is_running "$AGENTS_PID_FILE"; then
    status_line "Agents" "managed" "pid $(<"$AGENTS_PID_FILE")"
  elif agents_running_external; then
    status_line "Agents" "external"
  else
    status_line "Agents" "stopped"
  fi

  if [[ "$START_TUNNEL" == "true" ]]; then
    if pid_is_running "$TUNNEL_PID_FILE"; then
      status_line "Cloudflare" "managed" "pid $(<"$TUNNEL_PID_FILE")"
    elif tunnel_running_external; then
      status_line "Cloudflare" "external"
    else
      status_line "Cloudflare" "stopped"
    fi
  else
    status_line "Cloudflare" "disabled" "START_TUNNEL=$START_TUNNEL"
  fi
}

show_logs() {
  ensure_dirs
  section "Log Tails"
  log "Backend log: $BACKEND_LOG"
  tail -n 20 "$BACKEND_LOG" 2>/dev/null || true
  echo
  log "Agents log: $AGENTS_LOG"
  tail -n 20 "$AGENTS_LOG" 2>/dev/null || true
  echo
  log "Cloudflare log: $TUNNEL_LOG"
  tail -n 20 "$TUNNEL_LOG" 2>/dev/null || true
}

start_all() {
  banner
  section "Boot"
  log "Resolved backend port: $BACKEND_PORT"
  start_backend
  start_agents
  start_tunnel
  show_status
  show_endpoints
}

stop_all() {
  banner
  section "Shutdown"
  stop_process "Cloudflare tunnel" "$TUNNEL_PID_FILE"
  stop_process "Agents" "$AGENTS_PID_FILE"
  stop_process "Backend" "$BACKEND_PID_FILE"
  show_status
}

main() {
  local command="${1:-status}"

  case "$command" in
    start)
      start_all
      ;;
    stop)
      stop_all
      ;;
    restart)
      stop_all
      start_all
      ;;
    status)
      banner
      show_status
      show_endpoints
      ;;
    logs)
      banner
      show_logs
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"