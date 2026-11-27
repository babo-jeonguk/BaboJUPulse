#!/usr/bin/env bash
# Reject local-only references and obvious secrets in content that may be published.
# Failure output is limited to a rule identifier, a safe file label, and a line
# number. The matching text is never printed.
# Usage:
#   scripts/check-public-content.sh                 # read stdin
#   scripts/check-public-content.sh --files <path>  # scan files
#   scripts/check-public-content.sh --tracked       # scan all tracked text files
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# Keep rule identifiers stable: they are safe to print and useful in CI logs.
rule_ids=(
    "scratch-artifact"
    "home-directory-path"
    "windows-user-path"
    "tilde-home-path"
    "wsl-unc-path"
    "file-url"
    "github-token"
    "openai-key"
    "slack-token"
    "aws-access-key"
    "google-api-key"
    "jwt"
    "private-key"
)

# A bare `.scratch/` mention is allowed; a concrete artifact path is not.
rule_patterns=(
    '\.scratch[\\/][A-Za-z0-9_.*?$+{}-]+'
    '(^|[[:space:]"(<`])/(home|Users|root)/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+'
    '[A-Za-z]:[\\/]+Users[\\/]+[A-Za-z0-9._-]+'
    '(^|[[:space:]"(<`])~/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+'
    '\\\\wsl(\.localhost)?[$]\\[A-Za-z0-9._-]+'
    'file://'
    'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'
    'sk-[A-Za-z0-9]{20,}'
    'xox[baprs]-[A-Za-z0-9-]{10,}'
    'AKIA[0-9A-Z]{16}'
    'AIza[0-9A-Za-z_-]{35}'
    'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
    'BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY'
)

report_match() {
    printf 'public-content: rule=%s file=%s line=%s\n' "$1" "$2" "$3" >&2
}

safe_label() {
    local path=$1

    case "$path" in
        "$root"/*)
            printf '%s' "${path#"$root"/}"
            ;;
        /*)
            basename -- "$path"
            ;;
        *)
            printf '%s' "$path"
            ;;
    esac
}

scan_file() {
    local label=$1
    local file=$2
    local found=0
    local index
    local code
    local lines
    local line

    for index in "${!rule_ids[@]}"; do
        set +e
        lines=$(grep -nE -- "${rule_patterns[index]}" "$file" 2>/dev/null \
            | cut -d: -f1 \
            | sort -n -u)
        code=$?
        set -e

        if [ "$code" -eq 2 ]; then
            echo "public-content: could not scan file=$label rule=${rule_ids[index]}" >&2
            return 2
        fi

        if [ -n "$lines" ]; then
            while IFS= read -r line; do
                report_match "${rule_ids[index]}" "$label" "$line"
            done <<< "$lines"
            found=1
        fi
    done

    if [ "$found" -eq 1 ]; then
        return 1
    fi
}

scan_tracked() {
    local found=0
    local index
    local code
    local matches
    local location
    local path
    local line

    for index in "${!rule_ids[@]}"; do
        set +e
        matches=$(git grep -I -n -E -- "${rule_patterns[index]}" -- . \
            ':(exclude)scripts/check-public-content.sh' \
            ':(exclude)scripts/test-public-content.sh' 2>/dev/null \
            | cut -d: -f1,2)
        code=$?
        set -e

        if [ "$code" -eq 2 ]; then
            echo "public-content: could not scan tracked files for rule=${rule_ids[index]}" >&2
            return 2
        fi

        if [ -n "$matches" ]; then
            while IFS= read -r location; do
                path=${location%:*}
                line=${location##*:}
                report_match "${rule_ids[index]}" "$path" "$line"
            done <<< "$matches"
            found=1
        fi
    done

    if [ "$found" -eq 1 ]; then
        return 1
    fi
}

finish() {
    local code=$1

    if [ "$code" -eq 1 ]; then
        echo "public-content: prohibited content detected" >&2
        exit 1
    fi
    if [ "$code" -eq 2 ]; then
        exit 2
    fi
}

mode="${1:-stdin}"
case "$mode" in
    --tracked)
        scan_tracked || finish $?
        ;;
    --files)
        shift
        if [ "$#" -eq 0 ]; then
            echo "usage: $0 --files <path>..." >&2
            exit 2
        fi

        result=0
        for file in "$@"; do
            code=0
            scan_file "$(safe_label "$file")" "$file" || code=$?
            if [ "$code" -eq 2 ]; then
                exit 2
            fi
            if [ "$code" -eq 1 ]; then
                result=1
            fi
        done
        finish "$result"
        ;;
    stdin)
        temp="$(mktemp)"
        trap 'rm -f "$temp"' EXIT
        cat > "$temp"
        code=0
        scan_file "stdin" "$temp" || code=$?
        finish "$code"
        ;;
    *)
        echo "usage: $0 [--tracked | --files <path>...]" >&2
        exit 2
        ;;
esac
