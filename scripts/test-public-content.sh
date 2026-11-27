#!/usr/bin/env bash
# Synthetic cases for check-public-content.sh. Never uses real private data.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$root/scripts/check-public-content.sh"
output="$(mktemp)"
file_fixture="$(mktemp)"
tracked_root="$(mktemp -d)"
non_git_root="$(mktemp -d)"
trap 'rm -f "$output" "$file_fixture"; rm -rf "$tracked_root" "$non_git_root"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

# Load the checker's helpers without running its CLI.
source "$checker"

if [ "$(safe_label "/home/alice/notes.md")" != "notes.md" ]; then
    fail "POSIX absolute label was not reduced to a basename"
fi
if [ "$(safe_label "C:/Users/alice/notes.md")" != "notes.md" ]; then
    fail "drive-prefixed label was not reduced to a basename"
fi
if [ "$(safe_label "C:\\Users\\alice\\notes.md")" != "notes.md" ]; then
    fail "backslash drive-prefixed label was not reduced to a basename"
fi
if [ "$(safe_label "\\\\server\\share\\notes.md")" != "notes.md" ]; then
    fail "UNC label was not reduced to a basename"
fi
if [ "$(safe_label "docs/secret file.md")" != "docs/secret%20file.md" ]; then
    fail "space in a relative label was not encoded"
fi
if [ "$(safe_label "docs/notes.md")" != "docs/notes.md" ]; then
    fail "tracked relative label was changed unexpectedly"
fi
if [ "$(safe_label "file:///home/alice/notes.md")" != "notes.md" ]; then
    fail "file URL label was not reduced to a basename"
fi
if [ "$(safe_label " ../alice/notes.md")" != "notes.md" ]; then
    fail "leading-space relative label was not reduced to a basename"
fi
if [ "$(safe_label "~/notes.md")" != "notes.md" ]; then
    fail "tilde label was not reduced to a basename"
fi
if [ "$(safe_label "../alice/notes.md")" != "notes.md" ]; then
    fail "parent-relative label was not reduced to a basename"
fi

run_checker() {
    local text=$1

    if printf '%s\n' "$text" | "$checker" >"$output" 2>&1; then
        return 0
    fi
    return 1
}

is_safe_line() {
    local line=$1
    local file_label

    if [ "$line" = "public-content: prohibited content detected" ]; then
        return 0
    fi

    file_label=$(printf '%s\n' "$line" \
        | sed -n 's/^public-content: rule=[a-z-][a-z-]* file=\([^ ]*\) line=[0-9][0-9]*$/\1/p')

    if [ -z "$file_label" ]; then
        return 1
    fi

    case "$file_label" in
        /*|[A-Za-z]:[\\/]*|\\\\*|//*|*://*|~*|../*|..\\*)
            return 1
            ;;
    esac

    return 0
}

assert_safe_output() {
    local label=$1
    local expected_rule=$2
    local sensitive=$3
    local line

    while IFS= read -r line; do
        if is_safe_line "$line"; then
            continue
        fi
        fail "unsafe checker output shape: $label"
    done < "$output"

    if [ -n "$expected_rule" ] && ! grep -Fq "rule=$expected_rule" "$output"; then
        fail "expected rule $expected_rule: $label"
    fi

    if [ -n "$sensitive" ] && grep -Fq -- "$sensitive" "$output"; then
        fail "output leaked the sensitive fixture: $label"
    fi
}

check_reject() {
    local label=$1
    local expected_rule=$2
    local sensitive=$3
    local text=$4

    if run_checker "$text"; then
        fail "expected rejection: $label"
    fi

    assert_safe_output "$label" "$expected_rule" "$sensitive"
}

check_reject_at_line() {
    local label=$1
    local expected_rule=$2
    local sensitive=$3
    local text=$4
    local expected_line=$5

    check_reject "$label" "$expected_rule" "$sensitive" "$text"

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

    if [ -s "$output" ]; then
        fail "expected empty output for accepted text: $label"
    fi
}

if is_safe_line "token: ghp_abcdefghijklmnopqrstuvwxyz"; then
    fail "safe-output allowlist accepted a raw secret line"
fi
if is_safe_line "public-content: rule=github-token file=stdin"; then
    fail "safe-output allowlist accepted a line without a line number"
fi
if is_safe_line "public-content: rule=home-directory-path file=/home/alice/notes.md line=1"; then
    fail "safe-output allowlist accepted a POSIX absolute file label"
fi
if is_safe_line "public-content: rule=home-directory-path file=C:/Users/alice/notes.md line=1"; then
    fail "safe-output allowlist accepted a drive-prefixed file label"
fi
if is_safe_line "public-content: rule=tilde-home-path file=~/notes.md line=1"; then
    fail "safe-output allowlist accepted a tilde file label"
fi
if is_safe_line "public-content: rule=home-directory-path file=../alice/notes.md line=1"; then
    fail "safe-output allowlist accepted a parent-relative file label"
fi
if is_safe_line "public-content: rule=file-url file=file:///home/alice/notes.md line=1"; then
    fail "safe-output allowlist accepted a file URL label"
fi
if ! is_safe_line "public-content: rule=github-token file=stdin line=1"; then
    fail "safe-output allowlist rejected a valid rule line"
fi
if ! is_safe_line "public-content: prohibited content detected"; then
    fail "safe-output allowlist rejected the summary line"
fi

check_reject "scratch artifact" "scratch-artifact" ".scratch/task/plan.md" "See .scratch/task/plan.md for details."
check_reject "scratch windows artifact" "scratch-artifact" '.scratch\task\plan.md' 'See .scratch\task\plan.md for details.'
check_reject "home path" "home-directory-path" "/home/alice/project/notes.md" "See /home/alice/project/notes.md."
check_reject "home path after equals" "home-directory-path" "/home/alice/project/notes.md" "path=/home/alice/project/notes.md"
check_reject "home path in brackets" "home-directory-path" "/home/alice/project/notes.md" "[/home/alice/project/notes.md]"
check_reject "home path after comma" "home-directory-path" "/home/alice/project/notes.md" "x,/home/alice/project/notes.md"
check_reject "home path without file" "home-directory-path" "/home/alice" "See /home/alice for details."
check_reject "macOS home path" "home-directory-path" "/Users/alice/project/notes.md" "See /Users/alice/project/notes.md."
check_reject "root home path" "home-directory-path" "/root/project/notes.md" "See /root/project/notes.md."
check_reject "windows path" "windows-user-path" 'C:\Users\alice\notes.md' 'See C:\Users\alice\notes.md.'
check_reject "windows slash path" "windows-user-path" "C:/Users/alice/notes.md" "See C:/Users/alice/notes.md."
check_reject "mounted windows user path" "windows-user-path" "/mnt/c/Users/alice/notes.md" "See /mnt/c/Users/alice/notes.md."
check_reject "tilde path" "tilde-home-path" "~/project/notes.md" "See ~/project/notes.md."
check_reject "tilde path without file" "tilde-home-path" "~/project" "See ~/project for details."
check_reject "tilde path after equals" "tilde-home-path" "~/project/notes.md" "root=~/project/notes.md"
check_reject "file URL" "file-url" "file:///tmp/notes.md" "See file:///tmp/notes.md."
check_reject "wsl UNC path" "wsl-unc-path" '\\wsl$\Ubuntu\home\alice\notes.md' 'See \\wsl$\Ubuntu\home\alice\notes.md.'
check_reject "wsl localhost UNC path" "wsl-unc-path" '\\wsl.localhost\Ubuntu\home\alice\notes.md' 'See \\wsl.localhost\Ubuntu\home\alice\notes.md.'
check_reject_at_line "line number" "home-directory-path" "/home/alice/notes.md" $'first line\nsecond line\nSee /home/alice/notes.md.' "3"
check_reject "github token" "github-token" "ghp_abcdefghijklmnopqrstuvwxyz" "token: ghp_abcdefghijklmnopqrstuvwxyz"
check_reject "github fine-grained token" "github-token" "github_pat_abcdefghijklmnopqrstuvwxyz" "token: github_pat_abcdefghijklmnopqrstuvwxyz"
check_reject "openai key" "openai-key" "sk-abcdefghijklmnopqrstuvwxyz" "token: sk-abcdefghijklmnopqrstuvwxyz"
check_reject "openai project key" "openai-key" "sk-proj-abcdefghijklmnopqrstuvwxyz" "token: sk-proj-abcdefghijklmnopqrstuvwxyz"
check_reject "openai service-account key" "openai-key" "sk-svcacct-abcdefghijklmnopqrstuvwxyz" "token: sk-svcacct-abcdefghijklmnopqrstuvwxyz"
check_reject "openai admin key" "openai-key" "sk-admin-abcdefghijklmnopqrstuvwxyz" "token: sk-admin-abcdefghijklmnopqrstuvwxyz"
check_reject "openai none-scope key" "openai-key" "sk-None-abcdefghijklmnopqrstuvwxyz" "token: sk-None-abcdefghijklmnopqrstuvwxyz"
check_reject "anthropic key" "openai-key" "sk-ant-abcdefghijklmnopqrstuvwxyz" "token: sk-ant-abcdefghijklmnopqrstuvwxyz"
check_reject "slack token" "slack-token" "xoxb-abcdefghijklmnop" "token: xoxb-abcdefghijklmnop"
check_reject "aws access key" "aws-access-key" "AKIAABCDEFGHIJKLMNOP" "token: AKIAABCDEFGHIJKLMNOP"
check_reject "google api key" "google-api-key" "AIzaabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ" "token: AIzaabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ"
check_reject "jwt" "jwt" "eyJabcdefghijk.abcdefghijk.abcdefghijk" "token: eyJabcdefghijk.abcdefghijk.abcdefghijk"
check_reject "private key" "private-key" "BEGIN PRIVATE KEY" "-----BEGIN PRIVATE KEY-----"
check_accept "scratch convention" "The .scratch/ directory is local-only."
check_accept "scratch word without slash" "The .scratch directory is local-only."
check_accept "tracked documentation" "See docs/development.md for setup."
check_accept "public URL" "See https://example.com/home/alice/project."
check_accept "public URL with users" "See https://example.com/Users/alice/project."
check_accept "short token-like text" "token: ghp_short"
check_accept "redacted token placeholder" "token: ghp_<redacted>"
check_accept "benign hyphenated prose" "task-oriented-workflow-with-review-gates"
check_accept "benign sk prefix" "Use sk-learn-machine-learning-for-this"

printf 'See /home/alice/notes.md\n' > "$file_fixture"
if "$checker" --files "$file_fixture" >"$output" 2>&1; then
    fail "expected rejection for a file outside the repository"
fi
assert_safe_output "file outside repository" "home-directory-path" "/home/alice/notes.md"
if grep -Fq -- "$(dirname "$file_fixture")" "$output"; then
    fail "output exposed the file's local directory"
fi
if ! grep -Fq "file=$(basename "$file_fixture")" "$output"; then
    fail "expected the safe file basename in the report"
fi

mkdir -p "$tracked_root/scripts" "$tracked_root/docs"
cp "$checker" "$tracked_root/scripts/check-public-content.sh"
printf 'token: ghp_abcdefghijklmnopqrstuvwxyz\n' > "$tracked_root/docs/secret file.md"
git -C "$tracked_root" init -q
git -C "$tracked_root" add "docs/secret file.md"
if (cd "$tracked_root" && bash scripts/check-public-content.sh --tracked) >"$output" 2>&1; then
    fail "expected rejection in tracked-file mode"
fi
assert_safe_output "tracked space filename" "github-token" "ghp_abcdefghijklmnopqrstuvwxyz"
if ! grep -Fq "file=docs/secret%20file.md line=1" "$output"; then
    fail "expected the tracked path and line in the report"
fi

mkdir -p "$non_git_root/scripts"
cp "$checker" "$non_git_root/scripts/check-public-content.sh"
printf 'See .scratch/task/plan.md\n' > "$non_git_root/notes.md"
set +e
(cd "$non_git_root" && bash scripts/check-public-content.sh --tracked) >"$output" 2>&1
status=$?
set -e
if [ "$status" -ne 2 ]; then
    fail "expected a scan error outside a Git repository, got $status"
fi
if grep -Fq -- ".scratch/task/plan.md" "$output"; then
    fail "scan error output leaked the fixture text"
fi
if ! grep -Fq "could not scan tracked files" "$output"; then
    fail "expected a safe scan-error message"
fi

case "${OSTYPE:-}" in
    msys*|cygwin*)
        ;;
    *)
        binary_fixture="$tracked_root/binary.dat"
        printf 'abc\0token: ghp_abcdefghijklmnopqrstuvwxyz\n' > "$binary_fixture"
        set +e
        "$checker" --files "$binary_fixture" >"$output" 2>&1
        status=$?
        set -e
        if [ "$status" -ne 2 ]; then
            fail "expected a scan error for binary input, got $status"
        fi
        if grep -Fq "ghp_abcdefghijklmnopqrstuvwxyz" "$output"; then
            fail "binary scan error output leaked the fixture text"
        fi

        drive_root="$tracked_root/drive-root"
        mkdir -p "$drive_root/scripts" "$drive_root/C:/Users/alice"
        cp "$checker" "$drive_root/scripts/check-public-content.sh"
        printf 'See C:/Users/alice/notes.md\n' > "$drive_root/C:/Users/alice/notes.md"
        if (cd "$drive_root" && bash scripts/check-public-content.sh --files "C:/Users/alice/notes.md") >"$output" 2>&1; then
            fail "expected rejection for a drive-prefixed path"
        fi
        assert_safe_output "windows drive path" "home-directory-path" "C:/Users/alice/notes.md"
        if grep -Fq -- "C:/Users/alice" "$output"; then
            fail "output exposed the drive-prefixed path"
        fi
        if ! grep -Fq "file=notes.md" "$output"; then
            fail "expected the safe basename for the drive-prefixed path"
        fi
        ;;
esac

echo "public-content tests passed"
