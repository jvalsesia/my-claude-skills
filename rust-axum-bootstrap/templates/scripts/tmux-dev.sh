#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="{{PROJECT_NAME}}"

if ! command -v tmux >/dev/null 2>&1; then
    echo "[tmux] tmux not found. Install it with: sudo apt install tmux  or  brew install tmux"
    exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[tmux] session '$SESSION' already exists — attaching"
    tmux attach -t "$SESSION"
    exit 0
fi

tmux new-session -d -s "$SESSION" -x 220 -y 50

# Top pane: server logs
tmux send-keys -t "$SESSION" "cd $PROJECT_DIR && ./scripts/watch.sh" Enter

# Bottom pane: process monitor (30% height)
tmux split-window -t "$SESSION" -v -p 30
tmux send-keys -t "$SESSION" "cd $PROJECT_DIR && ./scripts/watch.sh --ps" Enter

# Select top pane
tmux select-pane -t "$SESSION:0.0"

echo "[tmux] session '$SESSION' created"
echo "[tmux] attach with: tmux attach -t $SESSION"
tmux attach -t "$SESSION"
