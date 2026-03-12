# clawhive-hub

[![CI](https://github.com/longzhi/clawhive-hub/actions/workflows/ci.yml/badge.svg)](https://github.com/longzhi/clawhive-hub/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue.svg)](LICENSE-MIT)

An A2A Agent Hub service that provides agent registration, discovery, WebSocket relay, HTTP proxy, and OIDC-based authentication. Enables agents behind NAT/firewalls to be accessible via standard A2A HTTP endpoints.

## What It Does

- **WebSocket relay** — Agents connect outbound to Hub via WebSocket. Hub assigns a public URL and relays A2A requests.
- **Agent registry** — Registration, search (FTS5), and online/offline status tracking.
- **HTTP reverse proxy** — External A2A clients hit standard HTTP endpoints on Hub; Hub forwards to agents via WebSocket.
- **OIDC Provider** — Issues JWTs via `client_credentials` flow for agent-to-agent authentication.
- **SSE streaming proxy** — Full support for streaming A2A responses through the Hub.

## How It Works

```
External A2A Client ──HTTP──► Hub ──WebSocket──► Your Agent (behind NAT)
                              │
                              ├── Agent Registry (who's online, what they can do)
                              ├── OIDC Provider (issues JWT for agent auth)
                              └── REST API (search, browse agents)
```

From the external client's perspective, Hub is a standard A2A HTTP endpoint. The client has no idea the agent is behind a NAT.

## Quick Start

### From Source

```bash
git clone https://github.com/longzhi/clawhive-hub.git
cd clawhive-hub
cargo build --release

# Run with default config
./target/release/clawhive-hub

# Or with a config file
./target/release/clawhive-hub --config hub.toml
```

### Docker

```bash
docker run -d \
  -p 3002:3002 \
  -v hub-data:/data \
  -e HUB_PUBLIC_URL=https://hub.example.com \
  ghcr.io/longzhi/clawhive-hub:latest
```

## Configuration

```toml
# hub.toml
[server]
host = "0.0.0.0"
port = 3002
public_url = "https://hub.example.com"

[database]
url = "sqlite:///data/hub.db"

[websocket]
ping_interval_secs = 30
timeout_secs = 90
max_message_size = 10_485_760   # 10MB

[oidc]
issuer = "https://hub.example.com"
token_expiry_secs = 3600
jwt_key_file = "/data/jwt_key"

[proxy]
request_timeout_secs = 60
stream_idle_timeout_secs = 300

[rate_limit]
oauth_token_per_ip_per_min = 5
register_per_ip_per_hour = 3
```

## API Overview

### Agent Registration

Agents connect via WebSocket and register with their AgentCard:

```
ws://hub.example.com/ws
→ {"type": "register", "card": {...}, "token": "sk_live_..."}
← {"type": "registered", "publicUrl": "https://hub.example.com/u/alice/my-agent", "agentPath": "alice/my-agent"}
```

### A2A Proxy Endpoints

Standard A2A endpoints, proxied to the agent via WebSocket:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/u/{user}/{agent}/.well-known/agent-card.json` | Agent discovery (from registry) |
| POST | `/u/{user}/{agent}/message:send` | Send message |
| POST | `/u/{user}/{agent}/message:stream` | Send message (SSE streaming) |
| GET | `/u/{user}/{agent}/tasks/{id}` | Get task |
| GET | `/u/{user}/{agent}/tasks` | List tasks |
| POST | `/u/{user}/{agent}/tasks/{id}:cancel` | Cancel task |
| GET | `/u/{user}/{agent}/tasks/{id}:subscribe` | Subscribe to task (SSE) |
| POST | `/u/{user}/{agent}/jsonrpc` | JSON-RPC endpoint |

### REST API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/agents?q={query}&status=online` | Search agents |
| GET | `/api/agents/{user}/{agent_id}` | Get agent details |
| GET | `/api/users/{user}/agents` | List user's agents |
| POST | `/api/users/register` | Register user (get API key) |
| GET | `/api/stats` | Hub statistics |
| GET | `/healthz` | Liveness check |
| GET | `/readyz` | Readiness check |

### OIDC Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/.well-known/openid-configuration` | OIDC Discovery |
| GET | `/.well-known/jwks.json` | JWK Set (public keys) |
| POST | `/oauth/token` | Token endpoint (client_credentials) |

## Architecture

```
src/
├── main.rs           # Entry point, config loading, service startup
├── config.rs         # Hub configuration model
├── ws_server.rs      # WebSocket connection management + agent sessions
├── registry.rs       # Agent Registry (registration, search, online/offline)
├── router.rs         # Message routing (Agent A → Hub → Agent B)
├── http_proxy.rs     # HTTP → WebSocket reverse proxy
├── oidc.rs           # OIDC Provider (JWT issuance + validation)
├── api.rs            # Public REST API
├── db.rs             # SQLite data layer
└── error.rs          # Error types
```

### Key Design Decisions

- **SQLite** for storage (v1 is single-instance; PostgreSQL when scaling to multi-node)
- **EdDSA (Ed25519)** for JWT signing (fast, short keys)
- **No conversation storage** — Hub only relays messages, never stores A2A content
- **OIDC standard** — No proprietary token protocol
- **A2A v1.0 RC** — All external HTTP endpoints comply with the A2A protocol spec

### Security

- **SSRF invariant**: Hub never uses URLs from AgentCards as proxy targets — all forwarding goes through established WebSocket connections
- **API keys**: CSPRNG-generated, bcrypt-hashed, `sk_live_{base62}` format
- **Rate limiting**: Per-IP on `/oauth/token` and `/api/users/register`; per-user on proxy and search endpoints
- **WS session lease**: 1-hour lease with token renewal

## Deployment

| Mode | Use Case | Description |
|------|----------|-------------|
| **Hosted** | Out of the box | We operate it, users register and go |
| **Self-hosted** | Enterprise/privacy | `docker-compose up` to run your own |
| **No Hub** | Agent has public IP | Direct A2A connections, no Hub needed |

## Related Projects

- [a2a-rust](https://github.com/longzhi/a2a-rust) — Rust SDK for A2A protocol (this project depends on it)
- [clawhive](https://github.com/longzhi/clawhive) — Multi-agent AI platform with A2A integration
- [A2A Protocol](https://a2a-protocol.org/) — Google's Agent-to-Agent protocol specification

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT License ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
