#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LOG_FILE="/tmp/{{PROJECT_NAME}}-server.log"

if [ "${1:-}" = "--ps" ]; then
    watch -n1 "ps aux | grep -E '{{PROJECT_NAME_SNAKE}}|cargo' | grep -v grep || echo 'no processes found'"
else
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo "[watch] log file not found: $LOG_FILE"
        echo "[watch] server may not be running. Start with ./scripts/init.sh"
    fi
fi
