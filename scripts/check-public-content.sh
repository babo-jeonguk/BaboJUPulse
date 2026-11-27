#!/usr/bin/env bash
# Reject local-only references and obvious secrets in content that may be published.
# Usage:
#   scripts/check-public-content.sh                 # read stdin
#   scripts/check-public-content.sh --files <path>  # scan files
#   scripts/check-public-content.sh --tracked       # scan all tracked text files
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# A bare `.scratch/` mention is allowed; a concrete artifact path is not.
patterns=(
    '\.scratch/[A-Za-z0-9_.-]+'
    '/home/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+'
    '/Users/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+'
    'C:\\Users\\[A-Za-z0-9._-]+'
    'C:/Users/[A-Za-z0-9._-]+'
    '~/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+'
    '\\\\wsl\$\\[A-Za-z0-9._-]+'
    'file://'
    'ghp_[A-Za-z0-9]{20,}'
    'gho_[A-Za-z0-9]{20,}'
    'github_pat_[A-Za-z0-9_]{20,}'
    'sk-[A-Za-z0-9]{20,}'
    'xox[baprs]-[A-Za-z0-9-]{10,}'
    'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY'
)
combined="$(IFS='|'; echo "${patterns[*]}")"

scan_file() {
    local label=$1
    local file=$2
    local output
    local status

    set +e
    output=$(grep -nE "$combined" "$file")
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        printf '%s\n' "$output" >&2
        echo "public-content: prohibited local reference or secret in $label" >&2
        return 1
    fi
    if [ "$status" -ne 1 ]; then
        echo "public-content: could not scan $label" >&2
        return 2
    fi
}

scan_tracked() {
    local output
    local status

    set +e
    output=$(git grep -I -n -E "$combined" -- . \
        ':(exclude)scripts/check-public-content.sh' \
        ':(exclude)scripts/test-public-content.sh')
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        printf '%s\n' "$output" >&2
        echo "public-content: prohibited local reference or secret in tracked files" >&2
        return 1
    fi
    if [ "$status" -ne 1 ]; then
        echo "public-content: could not scan tracked files" >&2
        return 2
    fi
}

mode="${1:-stdin}"
case "$mode" in
    --tracked)
        scan_tracked
        ;;
    --files)
        shift
        if [ "$#" -eq 0 ]; then
            echo "usage: $0 --files <path>..." >&2
            exit 2
        fi
        for file in "$@"; do
            scan_file "$file" "$file"
        done
        ;;
    stdin)
        temp="$(mktemp)"
        trap 'rm -f "$temp"' EXIT
        cat > "$temp"
        scan_file "stdin" "$temp"
        ;;
    *)
        echo "usage: $0 [--tracked | --files <path>...]" >&2
        exit 2
        ;;
esac
