#!/usr/bin/env bash
# Usage: bootstrap.sh <project-name> "<description>" <target-dir>
# Example: bootstrap.sh my-api "REST API for my app" /home/user/projects
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/templates"

# ── Args ───────────────────────────────────────────────────────────────────────
if [ $# -lt 3 ]; then
    echo "Usage: $0 <project-name> <description> <target-dir>" >&2
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DESCRIPTION="$2"
TARGET_DIR="$3"

# Derive snake_case from kebab-case
PROJECT_NAME_SNAKE="${PROJECT_NAME//-/_}"
PROJECT_DB_NAME="$PROJECT_NAME_SNAKE"
PROJECT_DIR="$TARGET_DIR/$PROJECT_NAME"

echo ""
echo "=== rust-axum-bootstrap ==="
echo "  Project:     $PROJECT_NAME"
echo "  Description: $PROJECT_DESCRIPTION"
echo "  Target:      $PROJECT_DIR"
echo ""

# ── Helper: substitute placeholders in a file ──────────────────────────────────
substitute() {
    local file="$1"
    sed -i \
        -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{PROJECT_NAME_SNAKE}}|$PROJECT_NAME_SNAKE|g" \
        -e "s|{{PROJECT_DESCRIPTION}}|$PROJECT_DESCRIPTION|g" \
        -e "s|{{PROJECT_DB_NAME}}|$PROJECT_DB_NAME|g" \
        "$file"
}

# ── Helper: copy file and substitute placeholders ─────────────────────────────
copy_and_sub() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    substitute "$dst"
}

# ── Step 1: Create project directory ──────────────────────────────────────────
echo "[1/9] creating project directory..."
mkdir -p "$PROJECT_DIR"

# ── Step 2: Create Cargo.toml ─────────────────────────────────────────────────
echo "[2/9] creating Cargo.toml..."
copy_and_sub "$TEMPLATES_DIR/Cargo.toml.template" "$PROJECT_DIR/Cargo.toml"

# ── Step 3: Copy source files ─────────────────────────────────────────────────
echo "[3/9] copying source files..."

copy_and_sub "$TEMPLATES_DIR/src/main.rs"                             "$PROJECT_DIR/src/main.rs"
copy_and_sub "$TEMPLATES_DIR/src/lib.rs"                              "$PROJECT_DIR/src/lib.rs"
copy_and_sub "$TEMPLATES_DIR/src/config.rs"                           "$PROJECT_DIR/src/config.rs"
copy_and_sub "$TEMPLATES_DIR/src/db.rs"                               "$PROJECT_DIR/src/db.rs"
copy_and_sub "$TEMPLATES_DIR/src/errors.rs"                           "$PROJECT_DIR/src/errors.rs"
copy_and_sub "$TEMPLATES_DIR/src/middleware/mod.rs"                   "$PROJECT_DIR/src/middleware/mod.rs"
copy_and_sub "$TEMPLATES_DIR/src/middleware/auth.rs"                  "$PROJECT_DIR/src/middleware/auth.rs"
copy_and_sub "$TEMPLATES_DIR/src/models/mod.rs"                       "$PROJECT_DIR/src/models/mod.rs"
copy_and_sub "$TEMPLATES_DIR/src/models/user.rs"                      "$PROJECT_DIR/src/models/user.rs"
copy_and_sub "$TEMPLATES_DIR/src/routes/mod.rs"                       "$PROJECT_DIR/src/routes/mod.rs"
copy_and_sub "$TEMPLATES_DIR/src/routes/health.rs"                    "$PROJECT_DIR/src/routes/health.rs"
copy_and_sub "$TEMPLATES_DIR/src/routes/users.rs"                     "$PROJECT_DIR/src/routes/users.rs"
copy_and_sub "$TEMPLATES_DIR/src/tests/mod.rs"                        "$PROJECT_DIR/src/tests/mod.rs"
copy_and_sub "$TEMPLATES_DIR/src/tests/helpers/mod.rs"                "$PROJECT_DIR/src/tests/helpers/mod.rs"
copy_and_sub "$TEMPLATES_DIR/src/tests/helpers/db.rs"                 "$PROJECT_DIR/src/tests/helpers/db.rs"
copy_and_sub "$TEMPLATES_DIR/src/tests/helpers/auth.rs"               "$PROJECT_DIR/src/tests/helpers/auth.rs"
copy_and_sub "$TEMPLATES_DIR/src/tests/examples/mod.rs"               "$PROJECT_DIR/src/tests/examples/mod.rs"
copy_and_sub "$TEMPLATES_DIR/src/tests/examples/users_test.rs"        "$PROJECT_DIR/src/tests/examples/users_test.rs"

# ── Step 4: Copy migrations ───────────────────────────────────────────────────
echo "[4/9] copying migrations..."
mkdir -p "$PROJECT_DIR/migrations"
for f in "$TEMPLATES_DIR/migrations"/*.sql; do
    FNAME="$(basename "$f")"
    copy_and_sub "$f" "$PROJECT_DIR/migrations/$FNAME"
done

# ── Step 5: Copy scripts ──────────────────────────────────────────────────────
echo "[5/9] copying scripts..."
mkdir -p "$PROJECT_DIR/scripts"
for script in init down check watch tmux-dev deploy; do
    copy_and_sub "$TEMPLATES_DIR/scripts/${script}.sh" "$PROJECT_DIR/scripts/${script}.sh"
    chmod +x "$PROJECT_DIR/scripts/${script}.sh"
done

# ── Step 6: Create .env files ─────────────────────────────────────────────────
echo "[6/9] creating environment files..."
copy_and_sub "$TEMPLATES_DIR/env-example.txt" "$PROJECT_DIR/.env.example"

# .env.test for CI / sqlx::test macro override
cat > "$PROJECT_DIR/.env.test" << EOF
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/${PROJECT_DB_NAME}_test"
JWT_SECRET="test-secret-for-testing-only-32chars"
JWT_EXPIRY_HOURS=1
RUST_LOG=error
EOF

# ── Step 7: Generate CLAUDE.md ────────────────────────────────────────────────
echo "[7/9] generating CLAUDE.md..."
copy_and_sub "$TEMPLATES_DIR/claude-md.md" "$PROJECT_DIR/CLAUDE.md"

# ── Step 8: Create .gitignore ─────────────────────────────────────────────────
echo "[8/9] creating .gitignore..."
cat > "$PROJECT_DIR/.gitignore" << 'EOF'
/target
.env
.env.test
*.log
EOF

# ── Step 9: Verify sqlx-cli is available (informational) ─────────────────────
echo "[9/9] checking toolchain..."

if ! command -v rustup >/dev/null 2>&1; then
    echo "  ⚠ rustup not found — install from https://rustup.rs"
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "  ⚠ cargo not found — install Rust from https://rustup.rs"
else
    RUST_VER=$(cargo --version 2>/dev/null || echo "unknown")
    echo "  ✓ $RUST_VER"
fi

if ! command -v sqlx >/dev/null 2>&1; then
    echo "  ⚠ sqlx-cli not found — install with:"
    echo "      cargo install sqlx-cli --no-default-features --features rustls,postgres"
else
    echo "  ✓ $(sqlx --version 2>/dev/null || echo 'sqlx-cli')"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== bootstrap complete ==="
echo ""
echo "  Project:   $PROJECT_DIR"
echo "  Next step: cd $PROJECT_NAME && ./scripts/init.sh"
echo ""
echo "  init.sh will:"
echo "    1. Create .env from .env.example"
echo "    2. Find a free port if default (8080) is occupied"
echo "    3. Create PostgreSQL databases ($PROJECT_DB_NAME + ${PROJECT_DB_NAME}_test)"
echo "    4. Run SQLx migrations"
echo "    5. Build and start the server"
echo "    6. Verify health at /health"
echo ""
