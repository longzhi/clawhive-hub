#!/usr/bin/env bash
set -euo pipefail

echo "[check] cargo fmt --all -- --check"
cargo fmt --all -- --check

echo "[check] cargo clippy --all-targets -- -D warnings"
cargo clippy --all-targets -- -D warnings

echo "[check] cargo test"
cargo test
