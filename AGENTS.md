# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

`clawhive-hub` is an independently deployable A2A Agent Hub service. It provides agent registration, discovery (FTS5 search), WebSocket relay for NAT traversal, HTTP reverse proxy, and OIDC-based authentication. Built with Rust + axum + SQLite.

**This is NOT part of the clawhive workspace.** It is a standalone binary that depends on `a2a-rust` for A2A types and server framework.

## Protocol Version

All external HTTP endpoints comply with **A2A Protocol v1.0 RC** (tag `v1.0.0-rc`, commit `6292104`). WebSocket messages between Hub and agents use a Hub-private protocol (NOT part of A2A spec).

## Build / Test / Lint

```bash
# Build
cargo build

# Run all tests
cargo test

# Lint (zero warnings required)
cargo clippy --all-targets -- -D warnings

# Format check
cargo fmt -- --check

# Run with config
cargo run -- --config hub.toml

# Run a single test
cargo test -- test_full_proxy_flow -v

# Run tests for a specific module
cargo test ws_
```

CI runs 4 parallel jobs: check, test, clippy, fmt. `RUSTFLAGS=-Dwarnings` is set — **all warnings are errors**.

## Project Structure

```
src/
├── main.rs           # Entry point + config loading + service startup
├── config.rs         # Hub configuration model (TOML)
├── ws_server.rs      # WebSocket connection management + agent sessions
├── registry.rs       # Agent Registry (register, search, online/offline, agent_id validation)
├── router.rs         # Message routing (A2A Client → Hub → Agent via WebSocket)
├── http_proxy.rs     # HTTP → WebSocket reverse proxy (REST + JSON-RPC + SSE)
├── oidc.rs           # OIDC Provider (JWT issuance + validation, EdDSA)
├── api.rs            # Public REST API (agent search, user registration, stats)
├── db.rs             # SQLite data layer (sqlx)
└── error.rs          # Error types
migrations/           # SQLite migrations
tests/
├── ws_integration.rs
└── api_integration.rs
```

### Key Source Files

- `src/ws_server.rs` — WebSocket lifecycle: connect → register → heartbeat → relay → disconnect
- `src/http_proxy.rs` — Proxies external A2A HTTP requests to agents via WebSocket, including SSE streaming
- `src/registry.rs` — Agent CRUD + FTS5 search + `agent_id` validation
- `src/oidc.rs` — EdDSA JWT signing, OIDC Discovery, JWKS endpoint, token endpoint

## Database Schema

```sql
CREATE TABLE agents (
    id TEXT PRIMARY KEY,          -- "user/agent_id"
    user_id TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    card_json TEXT NOT NULL,      -- A2A v1.0 RC AgentCard JSON
    status TEXT NOT NULL DEFAULT 'offline',
    registered_at TEXT NOT NULL,
    last_seen_at TEXT,
    public_url TEXT,
    UNIQUE(user_id, agent_id)
);

CREATE VIRTUAL TABLE agents_fts USING fts5(
    agent_path, name, description, skills, tags
);

CREATE TABLE users (
    id TEXT PRIMARY KEY,
    display_name TEXT,
    api_key_hash TEXT NOT NULL,   -- bcrypt
    client_id TEXT UNIQUE,        -- OIDC client_id (= user_id)
    client_secret_hash TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    context_id TEXT,
    agent_id TEXT NOT NULL REFERENCES agents(agent_id),
    state TEXT NOT NULL,          -- TASK_STATE_* enum
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    data_json TEXT NOT NULL,      -- Full Task JSON
    expires_at TEXT
);
```

## agent_id Naming Rules

| Rule | Description |
|------|-------------|
| Charset | `[a-z0-9-]` (lowercase, digits, hyphens) |
| Length | 3-64 characters |
| Forbidden | Uppercase, underscore, colon, slash, dot |

Validated at: agent registration API (`POST /api/agents`) and WebSocket Register message. Non-compliant → 400 with error details.

## URL Routing

External A2A requests follow this pattern:

```
https://hub.example.com/u/{user}/{agent_id}/.well-known/agent-card.json
https://hub.example.com/u/{user}/{agent_id}/message:send
https://hub.example.com/u/{user}/{agent_id}/tasks/{id}
...
```

Hub extracts `agent_path = "{user}/{agent_id}"`, finds the WebSocket connection, and forwards.

**Special case**: `GET /.well-known/agent-card.json` is served directly from the registry (no WebSocket round-trip). Hub injects `hub_oidc` SecurityScheme into the card.

## Code Style

### Imports

Order: std → external crates → crate-local. One blank line between groups.

```rust
use std::collections::HashMap;
use std::sync::Arc;

use axum::{Router, extract::ws::WebSocket};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

use crate::config::HubConfig;
use crate::error::HubError;
```

### Error Handling

- `thiserror` for `HubError` (library-style errors with HTTP status mapping)
- `anyhow::Result` for internal orchestration code
- Never use `.unwrap()` in non-test code
- Log with `tracing::warn!` before returning errors where appropriate

### Structs and Config

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SomeConfig {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default = "default_timeout")]
    pub timeout_secs: u64,
}
```

Derive order: `Debug, Clone, Serialize, Deserialize`

### Naming

- Modules: `snake_case`
- Structs/Enums: `PascalCase`
- Functions: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`

### Logging

Use `tracing` with structured fields:

```rust
tracing::info!(
    agent_path = %agent_path,
    request_id = %request_id,
    "proxying A2A request"
);
```

**Privacy rule**: Log `request_id`, `caller`, `target_agent`, `status_code`, `latency_ms`. NEVER log message content, artifacts, Authorization headers, API keys, or JWTs.

### Tests

- Inline tests in `#[cfg(test)] mod tests { }` at bottom of each file
- Integration tests in `tests/` directory
- Test function names describe behavior: `fn agent_offline_returns_503()`
- Use `tempfile::tempdir()` for database tests

### Async

- Tokio runtime (`features = ["full"]`)
- `async_trait` for async trait methods
- `Arc<T>` for shared state across tasks

## WebSocket Protocol (Hub-Private)

Hub defines its own WebSocket message types (NOT part of A2A spec):

### Agent → Hub (`HubClientMessage`)

- `Register { card, token }` — First message after connect
- `UpdateCard { card }` — AgentCard update
- `Response { request_id, a2a_response }` — Response to proxied request
- `StreamEvent { request_id, seq, event }` — Streaming response frame
- `StreamEnd { request_id }` — Stream complete
- `Ping` — Heartbeat (every 30s)

### Hub → Agent (`HubServerMessage`)

- `Registered { public_url, agent_path }` — Registration success
- `CardUpdated` — Card update confirmed
- `Incoming { request_id, from, a2a_message }` — External request arrived
- `StreamStart { request_id, from, a2a_message }` — Streaming request
- `Error { code, message }` — Error notification
- `Pong` — Heartbeat response

Both use `#[serde(tag = "type", rename_all = "snake_case")]`.

## Security Invariants

1. **SSRF prevention**: Hub NEVER makes outbound HTTP requests to URLs from AgentCards. All forwarding goes through established WebSocket connections.
2. **No conversation storage**: Hub relays messages, never persists A2A Task content. Only metadata is logged.
3. **API key handling**: CSPRNG-generated (`sk_live_{base62}`), bcrypt-hashed, shown only once at creation.
4. **AgentCard injection**: Hub adds `hub_oidc` to `securitySchemes` via merge (never replace). Agent's existing schemes are preserved.
5. **WS session lease**: 1-hour lease, agent must renew token before expiry.

## Key Design Decisions

- **Single-instance v1**: SQLite + in-memory WS connection table. No Redis/NATS needed.
- **EdDSA (Ed25519)** for JWT: Fast, short keys. Key persisted to `HUB_JWT_KEY_FILE`.
- **OIDC standard**: `client_credentials` flow, no proprietary token protocol.
- **v1 deferred**: Push Notification, Dynamic Client Registration (RFC 7591), AgentCard signature verification (JWS+JCS), Payment (x402).

## Don'ts

- **No `unsafe`** without explicit justification
- **No `.unwrap()`** outside of tests
- **No `println!`** — use `tracing::*`
- **No suppressing clippy** with `#[allow(...)]` without a comment
- **No storing conversation content** — only metadata in logs
- **No outbound HTTP to agent URLs** — WebSocket relay only
- **No inventing auth protocols** — use OIDC/OAuth2 standards
- **No PostgreSQL in v1** — SQLite is sufficient for single-instance

## Dependencies

### Runtime

- `a2a-rust` — A2A protocol types and server framework
- `axum` (with `ws` feature) — HTTP + WebSocket server
- `tokio`, `tokio-tungstenite` — Async runtime + WebSocket
- `sqlx` (sqlite) — Database
- `serde`, `serde_json` — Serialization
- `jsonwebtoken`, `ring` — JWT signing (EdDSA)
- `bcrypt` — API key hashing
- `tracing`, `tracing-subscriber` — Logging
- `tower-http` (cors, trace) — HTTP middleware
- `uuid`, `chrono` — Utilities
- `anyhow`, `thiserror` — Error handling
- `toml` — Config parsing

## References

- [A2A Protocol Spec v1.0 RC](https://a2a-protocol.org/latest/specification/)
- [A2A Agent Discovery](https://a2a-protocol.org/latest/topics/agent-discovery/)
- [OpenID Connect Discovery](https://openid.net/specs/openid-connect-discovery-1_0.html)
- [OAuth 2.0 Client Credentials](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)
- [RFC 7519 — JWT](https://datatracker.ietf.org/doc/html/rfc7519)
- [a2a-rust](https://github.com/longzhi/a2a-rust) — A2A Rust SDK
