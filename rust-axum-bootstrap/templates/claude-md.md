# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Quick start

```bash
./scripts/init.sh        # initialize env, databases, run migrations, start server
./scripts/check.sh       # verify everything is healthy
./scripts/check.sh --fix # auto-fix common issues
./scripts/down.sh        # stop the server
./scripts/watch.sh       # tail server logs
./scripts/tmux-dev.sh    # open a tmux dev session (logs + process monitor)
```

## Tech stack

| Layer | Tool | Version |
|---|---|---|
| Web framework | Axum | 0.8 |
| Async runtime | Tokio | 1 |
| Database | PostgreSQL | 14+ |
| SQL toolkit | SQLx | 0.8 |
| Authentication | JWT (jsonwebtoken) | 9 |
| Password hashing | bcrypt | 0.16 |
| Validation | validator | 0.18 |
| Serialization | serde + serde_json | 1 |
| Logging | tracing + tracing-subscriber | 0.1 / 0.3 |
| CORS / Middleware | tower-http | 0.6 |
| Test framework | sqlx::test + axum-test | built-in / 15 |

## Project structure

```
src/
├── main.rs              # entry point — loads config, connects DB, runs migrations, starts server
├── lib.rs               # app() factory — composes router + middleware + shared state
├── config.rs            # Config struct — reads all values from environment variables
├── db.rs                # database pool setup and migration runner
├── errors.rs            # AppError enum with automatic HTTP response conversion
├── middleware/
│   ├── mod.rs
│   └── auth.rs          # JWT extractor — AuthUser from Bearer token
├── models/
│   ├── mod.rs
│   └── user.rs          # User model, DTOs (CreateUserDto, LoginDto), response types
├── routes/
│   ├── mod.rs
│   ├── health.rs        # GET /health — liveness + database connectivity check
│   └── users.rs         # POST /users/register, POST /users/login, GET /users/me, GET /users/:id
└── tests/
    ├── mod.rs
    ├── helpers/
    │   ├── mod.rs
    │   ├── db.rs        # create_test_user, create_test_admin
    │   └── auth.rs      # test_token, bearer helpers
    └── examples/
        ├── mod.rs
        └── users_test.rs  # example integration tests
migrations/
└── 20240101000000_create_users.sql
```

## Environment variables

All config is read from `.env` (development). Never hardcode these values.

| Variable | Default | Description |
|---|---|---|
| `SERVER_PORT` | `8080` | port to listen on |
| `DATABASE_URL` | — | PostgreSQL connection string for dev |
| `DATABASE_URL_TEST` | — | PostgreSQL connection string for tests |
| `JWT_SECRET` | — | secret key for JWT signing (min 32 chars in prod) |
| `JWT_EXPIRY_HOURS` | `24` | JWT token lifetime |
| `RUST_LOG` | `info` | log level filter (e.g. `debug`, `{{PROJECT_NAME_SNAKE}}=trace`) |

## Database

**Dev database:** `{{PROJECT_DB_NAME}}`
**Test database:** `{{PROJECT_DB_NAME}}_test`

### Managing migrations

```bash
# Apply pending migrations
DATABASE_URL="..." sqlx migrate run --source ./migrations

# Create a new migration
sqlx migrate add <name>

# Check migration status
sqlx migrate info --source ./migrations

# Revert last migration (only if reversible)
sqlx migrate revert --source ./migrations
```

### Migration file conventions

- Files live in `migrations/` with format: `<timestamp>_<name>.sql`
- Prefer additive migrations (add columns/tables) over destructive ones
- Always add `IF NOT EXISTS` and `IF EXISTS` guards for idempotency
- For column removal: use soft deletion pattern first (`deleted_at`)
- The `update_updated_at_column()` trigger auto-maintains `updated_at` on all tables

### Writing queries

Use SQLx compile-time checked queries where possible:

```rust
// Compile-time checked (requires DATABASE_URL at build time)
let user = sqlx::query_as!(User, "SELECT * FROM users WHERE id = $1", id)
    .fetch_optional(&pool).await?;

// Runtime queries (more flexible, used in templates)
let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
    .bind(id)
    .fetch_optional(&pool).await?;
```

## Authentication

Routes requiring authentication use `AuthUser` as an extractor:

```rust
async fn protected(auth: AuthUser, State(state): State<AppState>) -> AppResult<Json<Value>> {
    // auth.user_id — Uuid
    // auth.email   — String
    Ok(Json(json!({ "user_id": auth.user_id })))
}
```

`AuthUser` reads the `Authorization: Bearer <token>` header and returns `401` if missing or invalid.

## Error handling

All handlers return `AppResult<T>` (alias for `Result<T, AppError>`). `AppError` variants automatically map to HTTP status codes:

| Variant | HTTP Status |
|---|---|
| `NotFound` | 404 |
| `Unauthorized` | 401 |
| `Forbidden` | 403 |
| `BadRequest(msg)` | 400 |
| `Conflict(msg)` | 409 |
| `Internal(err)` | 500 (logged) |
| `Database(err)` | 500 (logged) |

```rust
return Err(AppError::NotFound);
return Err(AppError::BadRequest("email is invalid".to_string()));
```

## Validation

Use the `validator` crate with `#[derive(Validate)]` on DTOs:

```rust
#[derive(Deserialize, Validate)]
pub struct CreatePostDto {
    #[validate(length(min = 1, max = 200))]
    pub title: String,
}

// In the handler:
dto.validate().map_err(|e| AppError::BadRequest(e.to_string()))?;
```

## Testing

Tests use the `#[sqlx::test]` macro which:
- Creates a fresh isolated database per test function
- Runs all migrations automatically
- Drops the database after the test completes

```bash
cargo test                    # run all tests
cargo test users              # run tests matching "users"
cargo test -- --nocapture     # show println output
```

**Test pattern for route handlers:**
```rust
#[sqlx::test(migrations = "./migrations")]
async fn test_my_endpoint(pool: PgPool) {
    let server = TestServer::new(app(pool, test_config())).unwrap();

    let res = server.post("/endpoint").json(&json!({ ... })).await;
    res.assert_status_ok();
}
```

**Important:** `sqlx::test` uses `DATABASE_URL` (not `DATABASE_URL_TEST`) to create test databases. It appends a unique suffix automatically. Set `DATABASE_URL` in `.env` and ensure the PostgreSQL user has `CREATEDB` privileges.

## Logging

Use structured tracing macros — never `println!`:

```rust
tracing::info!(user_id = %id, "user logged in");
tracing::warn!("suspicious activity detected");
tracing::error!(error = %e, "database query failed");
```

Control log level via `RUST_LOG`:
- `RUST_LOG=debug` — all debug output
- `RUST_LOG={{PROJECT_NAME_SNAKE}}=trace,tower_http=debug` — module-specific levels

## Scripts reference

| Script | Usage | Description |
|---|---|---|
| `init.sh` | `./scripts/init.sh` | Create .env, ensure DBs, run migrations, build, start server, health check |
| `down.sh` | `./scripts/down.sh` | Stop server gracefully |
| `down.sh --force` | `./scripts/down.sh --force` | Kill server + orphan cargo processes |
| `down.sh --clean` | `./scripts/down.sh --clean` | Remove .env, logs, and `target/` |
| `check.sh` | `./scripts/check.sh` | Show status of env, database, server, migrations |
| `check.sh --fix` | `./scripts/check.sh --fix` | Auto-fix: restart degraded server, apply pending migrations |
| `watch.sh` | `./scripts/watch.sh` | Tail server logs |
| `watch.sh --ps` | `./scripts/watch.sh --ps` | Live process monitor |
| `tmux-dev.sh` | `./scripts/tmux-dev.sh` | Open tmux session: logs (top) + processes (bottom) |
| `deploy.sh` | `./scripts/deploy.sh` | Run migrations + `cargo build --release` |

## Rules

- **Never run `cargo run` directly** — use `./scripts/init.sh` which sets all env vars
- **Never hardcode values** from `.env` — always read from `config.rs` via `env::var`
- **Never skip migrations** — always apply via `sqlx migrate run` or `init.sh`
- **Always ask before adding dependencies** — run `cargo add <crate>` only when confirmed
- **After schema changes:** add a new migration file, never edit existing ones
- **Soft deletes only:** set `deleted_at = NOW()`, never `DELETE FROM users`
- **All queries filter `WHERE deleted_at IS NULL`** unless intentionally querying deleted records
