# my-claude-skills

A personal collection of Claude Code skills — reusable, invocable workflows that extend Claude's capabilities for specific, repeatable tasks.

## Why this is a good idea

### The problem with prompting from scratch

Every time you start a new project or repeat a complex task, you either type the same long instructions again, paste from a notes file, or settle for a generic result. That friction compounds over time and breaks your flow.

### Skills solve this

A Claude skill is a self-contained workflow: a `SKILL.md` file that tells Claude exactly what to ask, what to run, and what to produce — plus any scripts and templates it needs. Once defined, it's invoked by natural language triggers like "bootstrap a rust api" and Claude handles the rest.

### What you gain

| Without skills | With skills |
|---|---|
| Repeat long prompts every time | One trigger phrase |
| Inconsistent project structure | Identical, opinionated scaffolding every time |
| Decisions scattered across notes | Decisions encoded in version-controlled templates |
| Knowledge lives in your head | Knowledge lives in the repo |

### It compounds

Each skill you write captures a decision you already made: which libraries, which folder layout, which scripts, which conventions. Future-you (and future collaborators) don't re-derive those decisions — they just trigger the skill and get a production-ready starting point.

### It's just files

Skills are Markdown + shell scripts. No framework, no dependency, no lock-in. They live in git, travel with you across machines, and are easy to update when your standards evolve.

---

## Skills in this repo

### `rust-axum-bootstrap`

Scaffolds a production-ready Rust/Axum REST API with PostgreSQL, JWT auth, request validation, structured logging, and an integration test infrastructure — from a single trigger phrase.

**Triggers:** "bootstrap a rust api", "scaffold a rust axum project", "new rust backend"

**What you get:**
- Axum typed routing + SQLx migrations
- JWT authentication middleware
- `validator` crate for request validation
- `tracing` structured logging
- `sqlx::test` integration test infrastructure
- Operational scripts: `init`, `watch`, `deploy`, `tmux-dev`
- A generated `CLAUDE.md` with project-specific conventions

---

## Installation

Claude Code does not support installing skills directly from a GitHub URL — you need to clone this repo and copy the skills into the right directory manually.

**Personal install** (available across all your projects):

```bash
git clone https://github.com/jvalsesia/my-claude-skills /tmp/my-claude-skills
cp -r /tmp/my-claude-skills/rust-axum-bootstrap ~/.claude/skills/
```

**Project install** (available only in the current project):

```bash
git clone https://github.com/jvalsesia/my-claude-skills /tmp/my-claude-skills
cp -r /tmp/my-claude-skills/rust-axum-bootstrap .claude/skills/
```

| Location | Scope |
|---|---|
| `~/.claude/skills/<skill>/` | All your projects |
| `.claude/skills/<skill>/` | Current project only |

Changes to existing skills take effect immediately. If you create the `.claude/skills/` directory for the first time, restart Claude Code to pick it up.

---

## How to use

Once installed, invoke any skill by typing its trigger phrase in a conversation — no slash command needed. Claude detects the intent and runs the skill automatically.

To add a new skill: create a subdirectory with a `SKILL.md` describing the workflow and any supporting scripts or templates.
