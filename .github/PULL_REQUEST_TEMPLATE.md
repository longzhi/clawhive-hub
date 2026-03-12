## Summary

<!-- Brief description of what this PR does -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation (changes to documentation only)
- [ ] Refactor (code change that neither fixes a bug nor adds a feature)
- [ ] Test (adding or updating tests)

## Related Issues

<!-- Link to related issues: Fixes #123, Closes #456 -->

## Changes Made

<!-- Detailed list of changes -->

- 
- 

## Security Considerations

<!-- If this touches auth, WebSocket, proxy, or data handling -->

- [ ] No new outbound HTTP requests to agent-provided URLs (SSRF invariant)
- [ ] No conversation content stored or logged
- [ ] Sensitive data (API keys, JWTs) not logged
- [ ] N/A — no security-related changes

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing performed
- [ ] WebSocket flow tested end-to-end

<details>
<summary>Test output</summary>

```
cargo test output here
```

</details>

## Checklist

- [ ] My code follows the project's code style (see AGENTS.md)
- [ ] I have run `cargo fmt --all`
- [ ] I have run `cargo clippy --all-targets -- -D warnings`
- [ ] I have run `cargo test`
- [ ] I have added doc comments for new public items
- [ ] My commit messages follow [conventional commits](https://www.conventionalcommits.org/)
