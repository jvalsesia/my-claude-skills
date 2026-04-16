#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

ENV_FILE="$PROJECT_DIR/.env"
LOG_FILE="/tmp/{{PROJECT_NAME}}-server.log"
PID_FILE="/tmp/{{PROJECT_NAME}}-server.pid"

# ── Step 1: create .env from example ──────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    cp "$PROJECT_DIR/.env.example" "$ENV_FILE"
    echo "[init] created .env from .env.example"
fi

source "$ENV_FILE"

SERVER_PORT="${SERVER_PORT:-8080}"
PORT_RANGE="${PORT_RANGE:-8080 8090}"

# ── Step 2: find a free port if default is occupied ───────────────────────────
is_port_free() {
    ! lsof -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

if ! is_port_free "$SERVER_PORT"; then
    echo "[init] port $SERVER_PORT is occupied — searching for free port..."
    IFS=' ' read -r PORT_START PORT_END <<< "$PORT_RANGE"
    FOUND=false
    for port in $(seq "$PORT_START" "$PORT_END"); do
        if is_port_free "$port"; then
            SERVER_PORT="$port"
            FOUND=true
            break
        fi
    done
    if [ "$FOUND" = false ]; then
        echo "[init] ERROR: no free port found in range $PORT_RANGE" >&2
        exit 1
    fi
    sed -i "s/^SERVER_PORT=.*/SERVER_PORT=$SERVER_PORT/" "$ENV_FILE"
    echo "[init] assigned port $SERVER_PORT"
fi

# ── Step 3: start PostgreSQL via Docker ────────────────────────────────────────
echo "[init] starting PostgreSQL via Docker..."
docker compose up -d postgres

echo "[init] waiting for postgres to be healthy..."
RETRIES=20
until docker compose exec -T postgres pg_isready -U postgres -d {{PROJECT_DB_NAME}} >/dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [ "$RETRIES" -eq 0 ]; then
        echo "[init] ERROR: postgres did not become healthy in time" >&2
        docker compose logs postgres >&2
        exit 1
    fi
    sleep 2
done
echo "[init] postgres ready"

# ── Step 4: run migrations ─────────────────────────────────────────────────────
echo "[init] running migrations..."
if command -v sqlx >/dev/null 2>&1; then
    DATABASE_URL="${DATABASE_URL}" sqlx migrate run --source "$PROJECT_DIR/migrations"
elif cargo sqlx migrate run --source "$PROJECT_DIR/migrations" 2>/dev/null; then
    : # cargo sqlx succeeded
else
    echo "[init] ERROR: sqlx-cli not found. Install it with:" >&2
    echo "    cargo install sqlx-cli --no-default-features --features rustls,postgres" >&2
    exit 1
fi
echo "[init] migrations applied"

# ── Step 5: build the project ──────────────────────────────────────────────────
echo "[init] building project (this may take a while on first run)..."
cargo build 2>&1 | tail -5

# ── Step 6: start server ───────────────────────────────────────────────────────
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[init] server already running (pid $(cat "$PID_FILE"))"
else
    echo "[init] starting server on port $SERVER_PORT..."
    SERVER_PORT="$SERVER_PORT" \
    DATABASE_URL="$(grep '^DATABASE_URL=' "$ENV_FILE" | cut -d= -f2-)" \
    JWT_SECRET="$(grep '^JWT_SECRET=' "$ENV_FILE" | cut -d= -f2-)" \
    JWT_EXPIRY_HOURS="$(grep '^JWT_EXPIRY_HOURS=' "$ENV_FILE" | cut -d= -f2-)" \
    RUST_LOG="$(grep '^RUST_LOG=' "$ENV_FILE" | cut -d= -f2-)" \
    cargo run > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
fi

# ── Step 7: health check ───────────────────────────────────────────────────────
echo "[init] waiting for server to be ready..."
RETRIES=30
until curl -sf "http://localhost:$SERVER_PORT/health" >/dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [ "$RETRIES" -eq 0 ]; then
        echo "[init] ERROR: server did not start in time. Check logs: $LOG_FILE" >&2
        exit 1
    fi
    sleep 2
done

echo ""
echo "[init] server running at http://localhost:$SERVER_PORT"
echo "[init] logs: $LOG_FILE"
echo "[init] to stop: ./scripts/down.sh"
