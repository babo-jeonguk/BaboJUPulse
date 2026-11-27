#!/usr/bin/env bash
# Synthetic cases for check-public-content.sh. Never uses real private data.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$root/scripts/check-public-content.sh"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

check_reject() {
    local label=$1
    local text=$2

    if printf '%s\n' "$text" | "$checker" >"$output" 2>&1; then
        echo "FAIL: expected rejection: $label" >&2
        cat "$output" >&2
        exit 1
    fi
}

check_accept() {
    local label=$1
    local text=$2

    if ! printf '%s\n' "$text" | "$checker" >"$output" 2>&1; then
        echo "FAIL: expected acceptance: $label" >&2
        cat "$output" >&2
        exit 1
    fi
}

check_reject "scratch artifact" "See .scratch/task/plan.md for details."
check_reject "home path" "See /home/alice/project/notes.md."
check_reject "windows path" "See C:\\Users\\alice\\notes.md."
check_reject "windows slash path" "See C:/Users/alice/notes.md."
check_reject "tilde path" "See ~/project/notes.md."
check_reject "github token" "token: ghp_abcdefghijklmnopqrstuvwxyz"
check_reject "private key" "-----BEGIN PRIVATE KEY-----"
check_accept "scratch convention" "The .scratch/ directory is local-only."
check_accept "tracked documentation" "See docs/development.md for setup."
check_accept "public URL" "See https://example.com/docs."

echo "public-content tests passed"
