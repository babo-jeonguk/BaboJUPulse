#!/usr/bin/env bash
# Synthetic cases for check-documentation.sh. Never uses real private data.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
output="$(mktemp)"
outside="$(dirname "$fixture")/outside-documentation-fixture.md"
alias_root="$(dirname "$fixture")/documentation-alias-$$"
scratch_dir=".scr""atch"
local_path="/ho""me/alice/notes.md"
fake_token="ghp_""abcdefghijklmnopqrstuvwxyz"
trap 'rm -rf "$fixture"; rm -f "$output" "$outside"; rm -rf "$alias_root"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

mkdir -p "$fixture/scripts" "$fixture/docs"
cp "$root/scripts/check-documentation.sh" "$fixture/scripts/check-documentation.sh"
cp "$root/scripts/check-public-content.sh" "$fixture/scripts/check-public-content.sh"
printf '%s/\n' "$scratch_dir" > "$fixture/.gitignore"
git -C "$fixture" init -q

run_checker() {
    if (cd "$fixture" && bash scripts/check-documentation.sh "$@") >"$output" 2>&1; then
        return 0
    fi
    return 1
}

write_doc() {
    local path=$1
    shift
    mkdir -p "$fixture/$(dirname "$path")"
    printf '%s\n' "$@" > "$fixture/$path"
}

assert_reject() {
    local label=$1
    local expected_rule=$2
    local path=$3
    local line=$4

    if run_checker --files "$path"; then
        fail "expected rejection: $label"
    fi

    if ! grep -Fq "rule=$expected_rule" "$output"; then
        fail "expected rule $expected_rule: $label"
    fi
    if ! grep -Fq "file=$path line=$line" "$output"; then
        fail "expected $path line $line: $label"
    fi
    if grep -Fq -- "$fixture" "$output"; then
        fail "output exposed the fixture path: $label"
    fi
}

assert_accept() {
    local label=$1
    local path=$2

    if ! run_checker --files "$path"; then
        fail "expected acceptance: $label"
    fi
    if [ -s "$output" ]; then
        fail "expected empty output for accepted document: $label"
    fi
}

write_doc "docs/other.md" \
    "# Other" \
    "" \
    "## Other section" \
    "" \
    "Body."

write_doc "docs/valid.md" \
    "# Valid" \
    "" \
    "## Section" \
    "" \
    "See [next](other.md#other-section), [self](#section), and [external](https://example.com)." \
    "" \
    "| Column | Detail |" \
    "| --- | --- |" \
    "| escaped pipe | \`a \\| b\` |" \
    "" \
    '```text' \
    "[broken](missing.md)" \
    '```' \
    "" \
    '```mermaid' \
    "graph TD" \
    "  A --> B" \
    '```' \
    "" \
    '```text' \
    "| a | b |" \
    "| --- | --- |" \
    "| 1 |" \
    '```' \
    "" \
    '````text' \
    '```' \
    "| a | b |" \
    "| --- | --- |" \
    "| 1 |" \
    '```' \
    '````' \
    "" \
    "    | a | b |" \
    "    | --- | --- |" \
    "    | 1 |" \
    "" \
    "    \`\`\`" \
    "    literal code" \
    "    [example](not-a-real-link)" \
    "" \
    "See [next again](other.md#other-section)." \
    "" \
    "The $scratch_dir/ directory is local-only."
assert_accept "valid document" "docs/valid.md"

case "${OSTYPE:-}" in
    msys*|cygwin*)
        # Git Bash may copy or junction the directory instead of creating a
        # symlink. The normal fixture already exercises the Windows path mapping.
        ;;
    *)
        if ln -s "$fixture" "$alias_root" 2>/dev/null && [ -L "$alias_root" ]; then
            if ! (cd "$alias_root" && bash scripts/check-documentation.sh --files docs/valid.md) >"$output" 2>&1; then
                fail "expected acceptance through an aliased repository root"
            fi
            if [ -s "$output" ]; then
                fail "expected empty output for an aliased repository root"
            fi
        fi
        rm -rf "$alias_root"
        ;;
esac

write_doc "docs/broken-link.md" \
    "# Broken link" \
    "" \
    "See [missing](missing.md)."
assert_reject "broken relative link" "relative-link" "docs/broken-link.md" "3"

write_doc "docs/indented-visible-link.md" \
    "# Indented visible link" \
    "" \
    "    [example](not-a-real-link)" \
    "" \
    "[broken](missing.md)."
assert_reject "visible link after indented code" "relative-link" "docs/indented-visible-link.md" "5"

write_doc "docs/broken-fragment.md" \
    "# Broken fragment" \
    "" \
    "See [next](other.md#missing-section)."
assert_reject "broken fragment" "fragment" "docs/broken-fragment.md" "3"

write_doc "docs/ignored-target.md" \
    "# Ignored target" \
    "" \
    "See [notes](../$scratch_dir/notes.md)."
mkdir -p "$fixture/$scratch_dir"
printf 'local note\n' > "$fixture/$scratch_dir/notes.md"
assert_reject "Git-ignored target" "ignored-target" "docs/ignored-target.md" "3"

write_doc "docs/local-path.md" \
    "# Local path" \
    "" \
    "See [notes]($local_path)."
assert_reject "local absolute path" "local-absolute-path" "docs/local-path.md" "3"
if grep -Fq -- "$local_path" "$output"; then
    fail "output exposed the local absolute path"
fi

write_doc "docs/outside.md" \
    "# Outside" \
    "" \
    "See [outside](../../outside-documentation-fixture.md)."
printf '# Outside\n' > "$outside"
assert_reject "outside repository" "outside-repository" "docs/outside.md" "3"

write_doc "docs/table.md" \
    "# Table" \
    "" \
    "| One | Two |" \
    "| --- | --- |" \
    "| 1 | 2 | 3 |"
assert_reject "table column count" "table-columns" "docs/table.md" "5"

write_doc "docs/fence.md" \
    "# Fence" \
    "" \
    '```text' \
    "unclosed"
assert_reject "unclosed fence" "unclosed-fence" "docs/fence.md" "4"

write_doc "docs/secret.md" \
    "# Secret" \
    "" \
    "token: $fake_token"
assert_reject "public-content violation" "github-token" "docs/secret.md" "3"

write_doc "docs/valid-second.md" \
    "# Valid second" \
    "" \
    "No links."
if run_checker --files "docs/valid.md" "docs/valid-second.md"; then
    :
else
    fail "expected acceptance for multiple files"
fi

if [ -s "$output" ]; then
    fail "expected empty output for multiple accepted documents"
fi

echo "documentation tests passed"
