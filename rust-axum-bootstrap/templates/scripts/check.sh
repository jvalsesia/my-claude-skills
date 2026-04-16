#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

ENV_FILE="$PROJECT_DIR/.env"
PID_FILE="/tmp/{{PROJECT_NAME}}-server.pid"
FIX=false

[ "${1:-}" = "--fix" ] && FIX=true

STATUS=0
print_ok()      { echo "  ✓ $1"; }
print_pending() { echo "  ✗ PENDING  $1"; STATUS=1; }
print_degraded(){ echo "  ✗ DEGRADED $1"; STATUS=1; }
print_warn()    { echo "  ⚠ WARNING  $1"; }

echo ""
echo "=== {{PROJECT_NAME}} status ==="
echo ""

# ── Check .env ─────────────────────────────────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    print_ok ".env exists"
else
    print_pending ".env missing — run ./scripts/init.sh"
    if [ "$FIX" = true ]; then
        cp "$PROJECT_DIR/.env.example" "$ENV_FILE"
        echo "    → created .env from .env.example"
    fi
fi

# ── Check DATABASE_URL ─────────────────────────────────────────────────────────
if [ -f "$ENV_FILE" ] && grep -q '^DATABASE_URL=' "$ENV_FILE"; then
    DB_URL="$(grep '^DATABASE_URL=' "$ENV_FILE" | cut -d= -f2-)"
    if [ -n "$DB_URL" ]; then
        print_ok "DATABASE_URL configured"
    else
        print_pending "DATABASE_URL is empty"
    fi
else
    print_pending "DATABASE_URL not set in .env"
fi

# ── Check Docker containers ────────────────────────────────────────────────────
if command -v docker >/dev/null 2>&1; then
    if docker compose ps --status running 2>/dev/null | grep -q "postgres"; then
        print_ok "postgres container running"
    else
        print_pending "postgres container not running — run ./scripts/init.sh"
        if [ "$FIX" = true ]; then
            echo "    → starting postgres..."
            docker compose up -d postgres
        fi
    fi
else
    print_warn "docker not found — cannot check container status"
fi

# ── Check server ───────────────────────────────────────────────────────────────
SERVER_PORT="8080"
if [ -f "$ENV_FILE" ]; then
    SERVER_PORT="$(grep '^SERVER_PORT=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' || echo 8080)"
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SERVER_PORT/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_ok "server running and healthy on port $SERVER_PORT"
    else
        print_degraded "process running but /health returned $HTTP_CODE"
        if [ "$FIX" = true ]; then
            echo "    → restarting server..."
            "$PROJECT_DIR/scripts/down.sh"
            "$PROJECT_DIR/scripts/init.sh"
        fi
    fi
else
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SERVER_PORT/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_ok "server running (no pid file, but port $SERVER_PORT responds)"
    else
        print_pending "server not running on port $SERVER_PORT"
        if [ "$FIX" = true ]; then
            echo "    → starting server..."
            "$PROJECT_DIR/scripts/init.sh"
        fi
    fi
fi

# ── Check migrations ───────────────────────────────────────────────────────────
if [ -f "$ENV_FILE" ] && command -v sqlx >/dev/null 2>&1; then
    DB_URL="$(grep '^DATABASE_URL=' "$ENV_FILE" | cut -d= -f2-)"
    PENDING_MIGRATIONS=$(DATABASE_URL="$DB_URL" sqlx migrate info --source "$PROJECT_DIR/migrations" 2>/dev/null | grep -c "pending" || echo "0")
    if [ "$PENDING_MIGRATIONS" -eq 0 ]; then
        print_ok "all migrations applied"
    else
        print_pending "$PENDING_MIGRATIONS pending migration(s)"
        if [ "$FIX" = true ]; then
            echo "    → running migrations..."
            DATABASE_URL="$DB_URL" sqlx migrate run --source "$PROJECT_DIR/migrations"
        fi
    fi
fi

echo ""
exit $STATUS
