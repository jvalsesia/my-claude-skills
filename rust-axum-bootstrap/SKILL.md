---
name: rust-axum-bootstrap
description: Scaffold a production-ready Rust/Axum REST API project with PostgreSQL, JWT auth, validation, structured logging, and integration test infrastructure.
triggers:
  - bootstrap a rust api
  - scaffold a rust axum project
  - new rust backend
  - setup rust axum
  - create axum app from scratch
  - new project
---

# rust-axum-bootstrap

## What this skill does

Scaffolds a new production-ready Rust/Axum REST API project with:
- Axum web framework with typed routing
- PostgreSQL via SQLx with versioned migrations
- JWT authentication middleware
- Request validation via the `validator` crate
- Structured logging via `tracing`
- Integration test infrastructure (sqlx::test macro)
- Operational scripts: init, down, check, watch, tmux-dev, deploy
- Generated CLAUDE.md with project-specific guidance

## When to invoke

Trigger this skill when the user asks to:
- "bootstrap a rust api"
- "scaffold a rust axum project"
- "new rust backend"
- "setup rust axum"
- "create axum app from scratch"
- "new project" (when Rust/Axum context is implied)

## Workflow

### Step 1 — Gather project info

Ask the user for exactly three things:

```
1. Project name (kebab-case, e.g. my-api)
2. Short description (one line)
3. Target parent directory (absolute path where the project folder will be created)
```

Do not ask for anything else. Fill in all other decisions from the template defaults.

### Step 2 — Run bootstrap script

```bash
<skill-path>/scripts/bootstrap.sh <project-name> "<description>" <target-dir>
```

Where `<skill-path>` is the absolute path to this skill directory.

Example:
```bash
/home/user/.claude/skills/rust-axum-bootstrap/scripts/bootstrap.sh my-api "My REST API" /home/user/projects
```

### Step 3 — Report results

After the script completes, tell the user:

1. The project was created at `<target-dir>/<project-name>/`
2. Run `cd <project-name> && ./scripts/init.sh` to initialize the environment, database, and start the server
3. The `CLAUDE.md` inside the project explains all conventions
4. Suggest starting the first feature (e.g. "what's the first endpoint you'd like to add?")

## Placeholder substitution

The bootstrap script replaces these placeholders in every copied file:

| Placeholder | Replaced with |
|---|---|
| `{{PROJECT_NAME}}` | kebab-case project name (e.g. `my-api`) |
| `{{PROJECT_NAME_SNAKE}}` | snake_case project name (e.g. `my_api`) |
| `{{PROJECT_DESCRIPTION}}` | one-line description |
| `{{PROJECT_DB_NAME}}` | snake_case name (same as `PROJECT_NAME_SNAKE`) |

DB names follow the pattern:
- Dev: `{{PROJECT_DB_NAME}}`
- Test: `{{PROJECT_DB_NAME}}_test`

## Rules for this skill

- Never hardcode ports — always read `SERVER_PORT` from `.env`
- All scripts use portable path resolution relative to `BASH_SOURCE[0]`
- All scripts are idempotent (safe to run multiple times)
- Migrations live in `migrations/` and are applied with `sqlx migrate run`
- Tests use the `sqlx::test` macro which manages isolated test databases automatically
- Never modify `Cargo.lock` — let cargo manage it
