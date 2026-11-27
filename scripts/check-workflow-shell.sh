#!/usr/bin/env bash
# Static-check the workflow scripts with ShellCheck.
#
# Compatible version: ShellCheck 0.11.0 (tested). The script requires 0.9.0 or
# newer because it enables the optional check-extra-masked-returns check, which
# reports SC2310/SC2312 for conditionally invoked commands whose exit status is
# masked. Other optional ShellCheck style checks are not part of this gate.
#
# Usage: bash scripts/check-workflow-shell.sh
# Exit codes: 0 clean, 1 findings, 2 missing or incompatible dependency.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

if ! command -v shellcheck >/dev/null 2>&1; then
    printf 'check-workflow-shell: required command is unavailable: shellcheck\n' >&2
    exit 2
fi

version="$(shellcheck --version | awk '/^version:/ { print $2; exit }')"
minimum="0.9.0"
if [ "$(printf '%s\n%s\n' "$minimum" "$version" | sort -V | head -n 1)" != "$minimum" ]; then
    printf 'check-workflow-shell: ShellCheck %s or newer is required; found %s\n' \
        "$minimum" "$version" >&2
    exit 2
fi

files=(
    scripts/workflow/common.sh
    scripts/workflow/cleanup.sh
    scripts/workflow/merge.sh
    scripts/workflow/validate.sh
    scripts/workflow/workspace.sh
    scripts/test-workflow.sh
)

printf 'check-workflow-shell: shellcheck=%s\n' "$version"
shellcheck --version | sed -n '/^version:/p'
shellcheck --external-sources --enable=check-extra-masked-returns "${files[@]}"
printf 'check-workflow-shell: result=pass\n'
