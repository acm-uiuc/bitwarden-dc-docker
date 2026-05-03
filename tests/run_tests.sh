#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v bats &>/dev/null; then
    echo "bats not found — install it: https://github.com/bats-core/bats-core"
    echo "  npm install -g bats   OR   brew install bats-core"
    exit 1
fi

echo "=== Unit tests ==="
bats "$TESTS_DIR/unit/"

echo ""
echo "=== Integration tests (requires Docker) ==="
bats "$TESTS_DIR/integration/"
