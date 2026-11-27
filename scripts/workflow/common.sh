#!/usr/bin/env bash
# Shared helpers for the workflow entry points.
#
# This file is sourced, not executed. It keeps repository discovery, argument
# validation, SHA validation, worktree inspection, and Paseo workspace lookup
# in one place so the entry points cannot drift apart.
#
# Environment:
#   GH_BIN      GitHub CLI executable (default: gh)
#   PASEO_BIN   Paseo CLI executable (default: paseo)
#   GIT_BIN     Git executable (default: git)

GH_BIN="${GH_BIN:-gh}"
PASEO_BIN="${PASEO_BIN:-paseo}"
GIT_BIN="${GIT_BIN:-git}"

workflow_die() {
    printf '%s: %s\n' "${WORKFLOW_NAME:-workflow}" "$1" >&2
    exit "${2:-1}"
}

workflow_info() {
    printf '%s: %s\n' "${WORKFLOW_NAME:-workflow}" "$1"
}

workflow_require_command() {
    command -v "$1" >/dev/null 2>&1 \
        || workflow_die "required command is unavailable: $1" 2
}

workflow_require_bin() {
    local variable=$1
    local value=$2
    if [ -z "$value" ]; then
        workflow_die "required executable variable is empty: $variable" 2
    fi
    if [ "${value#/}" = "$value" ] && ! command -v "$value" >/dev/null 2>&1; then
        workflow_die "required executable is unavailable: $value" 2
    fi
}

workflow_usage_error() {
    printf '%s: %s\n' "${WORKFLOW_NAME:-workflow}" "$1" >&2
    exit 2
}

workflow_option_value() {
    local option=$1
    if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        workflow_usage_error "missing value for $option"
    fi
}

workflow_repo_root() {
    "$GIT_BIN" rev-parse --show-toplevel 2>/dev/null \
        || workflow_die "not inside a Git worktree" 2
}

workflow_require_clean_tree() {
    local root=$1
    local status
    status=$("$GIT_BIN" -C "$root" status --porcelain --untracked-files=all)
    if [ -n "$status" ]; then
        workflow_die "working tree is not clean; commit or preserve the changes before continuing" 1
    fi
}

workflow_valid_sha() {
    case "$1" in
        *[!0-9a-fA-F]*) return 1 ;;
    esac
    case "${#1}" in
        40|64) return 0 ;;
        *) return 1 ;;
    esac
}

workflow_require_sha() {
    local label=$1
    local value=$2
    if [ -z "$value" ] || ! workflow_valid_sha "$value"; then
        workflow_die "invalid $label SHA" 2
    fi
}

workflow_valid_branch() {
    case "$1" in
        feat/*|fix/*|docs/*|chore/*|test/*|refactor/*) ;;
        *) return 1 ;;
    esac
    case "$1" in
        *[!A-Za-z0-9._/-]*) return 1 ;;
        */|/*|*//*|*..*) return 1 ;;
    esac
}

workflow_require_branch() {
    local branch=$1
    if ! workflow_valid_branch "$branch"; then
        workflow_die "invalid issue branch name: $branch" 2
    fi
}

workflow_positive_integer() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        0) return 1 ;;
        *) return 0 ;;
    esac
}

workflow_github_repository() {
    local expected=${1:-}
    local actual
    actual=$("$GH_BIN" repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
        || workflow_die "could not determine the GitHub repository" 1
    if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
        workflow_die "repository mismatch: expected $expected, found $actual" 1
    fi
    printf '%s' "$actual"
}

workflow_worktree_for_branch() {
    local branch=$1
    "$GIT_BIN" worktree list --porcelain \
        | awk -v ref="refs/heads/$branch" '
            $1 == "worktree" { path = substr($0, 10) }
            $1 == "branch" && $2 == ref { print path; exit }
        '
}

workflow_main_worktree() {
    "$GIT_BIN" worktree list --porcelain \
        | awk '
            $1 == "worktree" { path = substr($0, 10) }
            $1 == "branch" && $2 == "refs/heads/main" { print path; exit }
        '
}

workflow_branch_exists() {
    local root=$1
    local branch=$2
    "$GIT_BIN" -C "$root" show-ref --verify --quiet "refs/heads/$branch"
}

workflow_remote_branch_sha() {
    local root=$1
    local branch=$2
    local output
    if ! output=$("$GIT_BIN" -C "$root" ls-remote --heads origin "refs/heads/$branch" 2>/dev/null); then
        return 2
    fi
    printf '%s\n' "$output" | awk '{ print $1; exit }'
}

workflow_normalize_path() {
    local path=$1
    if [ ! -d "$path" ]; then
        printf '%s' "$path"
        return 0
    fi
    if (cd "$path" && "$GIT_BIN" rev-parse --show-toplevel >/dev/null 2>&1); then
        (cd "$path" && "$GIT_BIN" rev-parse --show-toplevel)
    else
        (cd "$path" && pwd -P)
    fi
}

workflow_reproducible_output() {
    case "$1" in
        bin|bin/*|*/bin|*/bin/*) return 0 ;;
        obj|obj/*|*/obj|*/obj/*) return 0 ;;
        TestResults|TestResults/*|*/TestResults|*/TestResults/*) return 0 ;;
        artifacts|artifacts/*|*/artifacts|*/artifacts/*) return 0 ;;
        publish|publish/*|*/publish|*/publish/*) return 0 ;;
        *.binlog) return 0 ;;
        *) return 1 ;;
    esac
}

workflow_worktree_status() {
    local path=$1
    local tracked
    local line
    local entry
    tracked=$("$GIT_BIN" -C "$path" status --porcelain --untracked-files=all)
    if [ -n "$tracked" ]; then
        return 1
    fi
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        entry=${line#?? }
        if ! workflow_reproducible_output "$entry"; then
            return 1
        fi
    done < <("$GIT_BIN" -C "$path" status --ignored --short --untracked-files=all)
    return 0
}

workflow_remove_reproducible_output() {
    local path=$1
    local line
    local entry
    local target
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        entry=${line#?? }
        workflow_reproducible_output "$entry" || continue
        target="$path/$entry"
        if [ "$target" = "$path" ] || ! workflow_path_is_within "$path" "$target"; then
            continue
        fi
        rm -rf -- "$target"
    done < <("$GIT_BIN" -C "$path" status --ignored --short --untracked-files=all)
}

workflow_paseo_workspace_id_for_cwd() {
    local cwd=$1
    local output
    if ! output=$("$PASEO_BIN" workspace ls --json 2>/dev/null); then
        return 2
    fi
    printf '%s\n' "$output" | awk -v wanted="$cwd" '
        /"workspaceId"/ {
            value = $0
            sub(/.*"workspaceId"[[:space:]]*:[[:space:]]*"/, "", value)
            sub(/".*/, "", value)
            id = value
        }
        /"cwd"/ {
            value = $0
            sub(/.*"cwd"[[:space:]]*:[[:space:]]*"/, "", value)
            sub(/".*/, "", value)
            if (value == wanted && id != "") {
                print id
                exit
            }
        }
    '
}

workflow_paseo_workspace_exists() {
    local id=$1
    local output
    if ! output=$("$PASEO_BIN" workspace ls --json 2>/dev/null); then
        return 2
    fi
    printf '%s\n' "$output" | grep -Eq "\"workspaceId\"[[:space:]]*:[[:space:]]*\"$id\""
}

workflow_path_is_within() {
    local parent=$1
    local child=$2
    case "$child/" in
        "$parent"/*) return 0 ;;
        *) return 1 ;;
    esac
}
