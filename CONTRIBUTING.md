# Contributing to clawhive-hub

Thank you for your interest in contributing to clawhive-hub! This document provides guidelines for contributors.

## Code of Conduct

Be respectful, inclusive, and constructive. We're all here to build a great A2A Hub together.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/clawhive-hub.git`
3. Add upstream remote: `git remote add upstream https://github.com/longzhi/clawhive-hub.git`
4. Create a branch: `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites

- Rust 1.75+ (install via [rustup](https://rustup.rs/))
- Git
- SQLite 3.x (usually pre-installed on most systems)

### Build & Test

```bash
cargo build
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt --all
```

All four must pass before submitting a PR. CI treats all warnings as errors.

### Running Locally

```bash
# With default settings
cargo run

# With a config file
cargo run -- --config hub.toml

# With environment variables
HUB_PUBLIC_URL=http://localhost:3002 cargo run
```

## Making Changes

1. **Check existing issues** — see if someone is already working on it
2. **Create an issue first** — for significant changes, discuss before coding
3. **Keep changes focused** — one feature or fix per PR
4. **Write tests** — especially integration tests for WebSocket and proxy flows
5. **Update documentation** — doc comments for public items

### Security-Sensitive Areas

Extra care is required when modifying:

- **`ws_server.rs`** — WebSocket connection management (authentication, session lifecycle)
- **`http_proxy.rs`** — HTTP proxy (must NOT make outbound requests to agent URLs)
- **`oidc.rs`** — JWT signing and validation (key management, token claims)
- **`api.rs`** — User registration (API key generation, rate limiting)

### Code Style

See [AGENTS.md](AGENTS.md) for detailed code conventions. Key points:

- `tracing` for logging (never `println!`)
- Never store or log A2A conversation content
- `thiserror` for error types
- No `.unwrap()` outside tests
- Derive order: `Debug, Clone, Serialize, Deserialize`

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks |

### Scopes

| Scope | Area |
|-------|------|
| `ws` | WebSocket server |
| `proxy` | HTTP reverse proxy |
| `registry` | Agent registry |
| `oidc` | OIDC/JWT authentication |
| `api` | REST API |
| `db` | Database/migrations |

### Examples

```
feat(ws): add WebSocket session lease renewal
fix(proxy): handle agent disconnect during SSE stream
test(oidc): add JWT claim validation tests
docs(readme): add Docker deployment instructions
```

## Pull Request Process

1. **Update your branch** with the latest upstream changes:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Ensure all checks pass**:
   ```bash
   cargo test
   cargo clippy --all-targets -- -D warnings
   cargo fmt --all -- --check
   ```

3. **Create the PR** with a clear title and description

4. **Fill out the PR template** completely — especially the Security Considerations section

5. **Respond to review feedback** promptly

## Testing Guidelines

### WebSocket Integration Tests

Test the full WebSocket lifecycle:

```rust
#[tokio::test]
async fn test_agent_register_and_proxy() {
    // 1. Start Hub
    // 2. Agent connects via WebSocket and registers
    // 3. External client sends HTTP request to Hub
    // 4. Verify Hub forwards via WebSocket
    // 5. Agent responds
    // 6. Verify external client gets correct response
}
```

### HTTP Proxy Tests

Test standard A2A endpoint proxying:

```rust
#[tokio::test]
async fn test_agent_offline_returns_503() {
    // Agent registered but disconnected → 503
}
```

### OIDC Tests

Test the full authentication flow:

```rust
#[tokio::test]
async fn test_oidc_client_credentials_flow() {
    // Register user → get client_credentials → request JWT → verify claims
}
```

## Reporting Security Issues

**Do NOT open a public issue for security vulnerabilities.**

Use [GitHub Security Advisories](https://github.com/longzhi/clawhive-hub/security/advisories/new) to report security issues privately.

## Questions?

- Open a [Discussion](https://github.com/longzhi/clawhive-hub/discussions)
- Check existing [Issues](https://github.com/longzhi/clawhive-hub/issues)
