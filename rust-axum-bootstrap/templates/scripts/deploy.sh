#!/usr/bin/env bash
# Production build and migration hook.
# Designed for Railway, Render, Fly.io, or any platform that runs this script pre-deploy.
set -euo pipefail

echo "[deploy] running database migrations..."
sqlx migrate run --source ./migrations

echo "[deploy] building release binary..."
cargo build --release

echo "[deploy] deploy build complete"
echo "[deploy] start with: ./target/release/{{PROJECT_NAME_SNAKE}}"
