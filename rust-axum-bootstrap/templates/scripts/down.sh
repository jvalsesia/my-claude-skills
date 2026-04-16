#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

ENV_FILE="$PROJECT_DIR/.env"
PID_FILE="/tmp/{{PROJECT_NAME}}-server.pid"
LOG_FILE="/tmp/{{PROJECT_NAME}}-server.log"

FORCE=false
CLEAN=false

for arg in "$@"; do
    case $arg in
        --force) FORCE=true ;;
        --clean) CLEAN=true ;;
    esac
done

# ── Stop server process ────────────────────────────────────────────────────────
stop_server() {
    if [ -f "$PID_FILE" ]; then
        PID="$(cat "$PID_FILE")"
        if kill -0 "$PID" 2>/dev/null; then
            echo "[down] stopping server (pid $PID)..."
            kill "$PID" 2>/dev/null || true
            sleep 1
            kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null || true
            echo "[down] server stopped"
        else
            echo "[down] server was not running"
        fi
        rm -f "$PID_FILE"
    else
        # Fallback: kill by port
        if [ -f "$ENV_FILE" ]; then
            SERVER_PORT="$(grep '^SERVER_PORT=' "$ENV_FILE" | cut -d= -f2- | tr -d '"')"
        fi
        SERVER_PORT="${SERVER_PORT:-8080}"
        PID="$(lsof -iTCP:"$SERVER_PORT" -sTCP:LISTEN -t 2>/dev/null || true)"
        if [ -n "$PID" ]; then
            echo "[down] stopping process on port $SERVER_PORT (pid $PID)..."
            kill "$PID" 2>/dev/null || true
            echo "[down] stopped"
        else
            echo "[down] nothing running on port $SERVER_PORT"
        fi
    fi
}

if [ "$FORCE" = true ]; then
    stop_server
    echo "[down] killing orphan cargo/test processes..."
    pkill -f "cargo run" 2>/dev/null || true
    pkill -f "{{PROJECT_NAME_SNAKE}}" 2>/dev/null || true
    echo "[down] done"
else
    stop_server
fi

if [ "$CLEAN" = true ]; then
    echo "[down] cleaning build artifacts and config..."
    rm -f "$ENV_FILE"
    rm -f "$LOG_FILE"
    cargo clean 2>/dev/null || true
    echo "[down] cleaned .env, logs, and target/"
fi
