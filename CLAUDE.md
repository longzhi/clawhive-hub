# CLAUDE.md

Read AGENTS.md first — it contains the full project context, code style, and conventions.

## Quick Reference

- **Language**: Rust, edition 2021
- **Type**: Binary crate (standalone service)
- **Database**: SQLite (sqlx)
- **Protocol**: A2A v1.0 RC external endpoints; Hub-private WebSocket protocol
- **Depends on**: `a2a-rust` for A2A types

## Before Every Change

```bash
cargo fmt -- --check
cargo clippy --all-targets -- -D warnings
cargo test
```

All three must pass. CI treats warnings as errors.

## Critical Rules

1. Hub is a **message relay** — never store A2A conversation content
2. Never make outbound HTTP requests to agent URLs (SSRF invariant)
3. External HTTP endpoints must comply with A2A v1.0 RC spec
4. WebSocket protocol is Hub-private — tagged with `#[serde(tag = "type", rename_all = "snake_case")]`
5. JWT signing uses EdDSA (Ed25519) — key persisted to `HUB_JWT_KEY_FILE`
6. API keys: `sk_live_{base62}`, bcrypt-hashed, shown only once
7. Never use `.unwrap()` outside tests
8. Never log message content, artifacts, Authorization headers, or credentials

## Design Doc

The full design specification is at:
`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian-vault/Projects/clawhive/research/clawhive-hub-design.md`

This document contains complete module designs, SQL schemas, API specs, and implementation notes.
