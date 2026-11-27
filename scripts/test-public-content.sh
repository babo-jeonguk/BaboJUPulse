#!/usr/bin/env bash
# Synthetic cases for check-public-content.sh. Never uses real private data.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$root/scripts/check-public-content.sh"
output="$(mktemp)"
file_fixture="$(mktemp)"
trap 'rm -f "$output" "$file_fixture"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

run_checker() {
    local text=$1

    if printf '%s\n' "$text" | "$checker" >"$output" 2>&1; then
        return 0
    fi
    return 1
}

check_reject() {
    local label=$1
    local text=$2

    if run_checker "$text"; then
        fail "expected rejection: $label"
    fi

    if ! grep -q 'public-content: rule=' "$output"; then
        fail "missing safe rule report: $label"
    fi

    if grep -Fq -- "$text" "$output"; then
        fail "output leaked the fixture text: $label"
    fi
}

check_reject_at_line() {
    local label=$1
    local text=$2
    local expected_line=$3

    check_reject "$label" "$text"

    if ! grep -Fq "line=$expected_line" "$output"; then
        fail "expected line $expected_line in safe report: $label"
    fi
}

check_accept() {
    local label=$1
    local text=$2

    if ! run_checker "$text"; then
        fail "expected acceptance: $label"
    fi
}

check_reject "scratch artifact" "See .scratch/task/plan.md for details."
check_reject "scratch windows artifact" "See .scratch\\task\\plan.md for details."
check_reject "home path" "See /home/alice/project/notes.md."
check_reject "macOS home path" "See /Users/alice/project/notes.md."
check_reject "root home path" "See /root/project/notes.md."
check_reject "windows path" 'See C:\Users\alice\notes.md.'
check_reject "windows slash path" "See C:/Users/alice/notes.md."
check_reject "tilde path" "See ~/project/notes.md."
check_reject "file URL" "See file:///tmp/notes.md."
check_reject "wsl UNC path" 'See \\wsl$\Ubuntu\home\alice\notes.md.'
check_reject_at_line "line number" $'first line\nsecond line\nSee /home/alice/notes.md.' "3"
check_reject "github token" "token: ghp_abcdefghijklmnopqrstuvwxyz"
check_reject "github fine-grained token" "token: github_pat_abcdefghijklmnopqrstuvwxyz"
check_reject "openai key" "token: sk-abcdefghijklmnopqrstuvwxyz"
check_reject "slack token" "token: xoxb-abcdefghijklmnop"
check_reject "aws access key" "token: AKIAABCDEFGHIJKLMNOP"
check_reject "google api key" "token: AIzaabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ"
check_reject "jwt" "token: eyJabcdefghijk.abcdefghijk.abcdefghijk"
check_reject "private key" "-----BEGIN PRIVATE KEY-----"
check_accept "scratch convention" "The .scratch/ directory is local-only."
check_accept "scratch word without slash" "The .scratch directory is local-only."
check_accept "tracked documentation" "See docs/development.md for setup."
check_accept "public URL" "See https://example.com/home/alice/project."
check_accept "short token-like text" "token: ghp_short"
check_accept "redacted token placeholder" "token: ghp_<redacted>"

printf 'See /home/alice/notes.md\n' > "$file_fixture"
if "$checker" --files "$file_fixture" >"$output" 2>&1; then
    fail "expected rejection for a file outside the repository"
fi
if grep -Fq -- "$(dirname "$file_fixture")" "$output"; then
    fail "output exposed the file's local directory"
fi
if grep -Fq -- "/home/alice/notes.md" "$output"; then
    fail "output leaked the file fixture text"
fi
if ! grep -Fq "file=$(basename "$file_fixture")" "$output"; then
    fail "expected the safe file basename in the report"
fi

echo "public-content tests passed"
