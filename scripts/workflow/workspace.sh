#!/usr/bin/env bash
# Prepare and verify an issue-specific workspace without assuming that a shell
# process can call the agent's Paseo MCP tools.
#
#   workspace.sh prepare --issue N --branch <type>/<name> [options]
#       Read-only preflight. Refreshes origin/main, verifies the repository and
#       issue, detects an existing branch or worktree, and prints the parameters
#       for the Paseo workspace operation. It never creates a workspace.
#
#   workspace.sh verify --issue N --branch <type>/<name> --base <sha> [options]
#       Verifies the Git worktree that the Paseo operation produced.
#
# Options:
#   --repository <owner/name>  Require this GitHub repository.
#   --slug <slug>              Worktree slug (default: branch suffix).
#   --path <path>              Worktree path for verify (default: current).
#
# Exit codes: 0 ready/verified, 1 blocked or unsafe state, 2 usage error.
set -euo pipefail

WORKFLOW_NAME=workspace
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
source "$script_dir/common.sh"

usage() {
    sed -n '2,19p' "${BASH_SOURCE[0]}"
}

prepare() {
    local issue=""
    local branch=""
    local repository=""
    local slug=""
    local path="${PWD}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --issue) workflow_option_value "$@"; issue=$2; shift 2 ;;
            --branch) workflow_option_value "$@"; branch=$2; shift 2 ;;
            --repository) workflow_option_value "$@"; repository=$2; shift 2 ;;
            --slug) workflow_option_value "$@"; slug=$2; shift 2 ;;
            --path) workflow_option_value "$@"; path=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done

    workflow_positive_integer "$issue" || workflow_usage_error "--issue must be a positive integer"
    workflow_require_branch "$branch"
    workflow_require_bin GH_BIN "$GH_BIN"

    local root
    root="$(cd "$path" && workflow_repo_root)"
    cd "$root"

    local actual_repository
    actual_repository="$(workflow_github_repository "$repository")"

    local issue_record number state title url labels
    issue_record=$("$GH_BIN" issue view "$issue" --repo "$actual_repository" \
        --json number,state,title,url,labels \
        --jq '[.number, .state, .title, .url, ([.labels[].name] | join(","))] | join("\u001f")' 2>/dev/null) \
        || workflow_die "could not read issue #$issue" 1
    IFS=$'\x1f' read -r number state title url labels <<< "$issue_record"

    if [ "$state" != "OPEN" ]; then
        workflow_die "issue #$issue is not open" 1
    fi

    local worktree
    worktree="$(workflow_worktree_for_branch "$branch")"
    local local_branch=no
    local remote_sha=""
    if workflow_branch_exists "$root" "$branch"; then
        local_branch=yes
    fi
    remote_sha="$(workflow_remote_branch_sha "$root" "$branch")" \
        || workflow_die "could not query the remote branch" 1

    local existing=no
    if [ -n "$worktree" ] || [ "$local_branch" = yes ] || [ -n "$remote_sha" ]; then
        existing=yes
    fi

    case ",$labels," in
        *,ready-for-agent,*|*,ready-for-human,*) ;;
        *)
            if [ "$existing" = no ]; then
                workflow_die "issue #$issue has no readiness label; complete triage before implementation" 1
            fi
            workflow_info "warning: issue #$issue no longer has a readiness label; reusing an existing branch"
            ;;
    esac

    if [ -z "$slug" ]; then
        slug=${branch#*/}
    fi
    case "$slug" in
        ''|*[!A-Za-z0-9._-]*) workflow_usage_error "--slug must contain only letters, digits, dot, underscore, or hyphen" ;;
    esac

    workflow_require_bin GIT_BIN "$GIT_BIN"
    "$GIT_BIN" fetch origin main >/dev/null 2>&1 \
        || workflow_die "could not fetch origin/main" 1
    local base_sha
    base_sha=$("$GIT_BIN" rev-parse origin/main)

    local action
    local mode
    local requires_tracking=no
    local clean=unknown
    local workspace_id=""

    if [ -n "$worktree" ]; then
        action=reuse
        mode=checkout-branch
        if workflow_worktree_status "$worktree"; then
            clean=yes
        else
            clean=no
        fi
        if ! workspace_id="$(workflow_paseo_workspace_id_for_cwd "$worktree")"; then
            workspace_id=""
            workflow_info "warning: could not query Paseo workspaces"
        fi
        if [ "$clean" = no ]; then
            workflow_info "warning: existing worktree has uncommitted, untracked, or ignored content"
        fi
    elif [ "$local_branch" = yes ]; then
        action=attach
        mode=checkout-branch
    elif [ -n "$remote_sha" ]; then
        action=create
        mode=checkout-branch
        requires_tracking=yes
    else
        action=create
        mode=branch-off
    fi

    printf 'workspace: repository=%s\n' "$actual_repository"
    printf 'workspace: issue=%s state=%s\n' "$number" "$state"
    printf 'workspace: issue_title=%s\n' "$title"
    printf 'workspace: issue_url=%s\n' "$url"
    printf 'workspace: base_sha=%s\n' "$base_sha"
    printf 'workspace: branch=%s\n' "$branch"
    printf 'workspace: slug=%s\n' "$slug"
    printf 'workspace: action=%s\n' "$action"
    printf 'workspace: mode=%s\n' "$mode"
    printf 'workspace: existing_worktree=%s\n' "${worktree:-none}"
    printf 'workspace: existing_workspace=%s\n' "${workspace_id:-none}"
    printf 'workspace: requires_tracking_branch=%s\n' "$requires_tracking"
    printf 'workspace: worktree_clean=%s\n' "$clean"

    if [ "$existing" = yes ] && [ "$action" = reuse ]; then
        workflow_info "reuse the existing worktree; do not create another workspace for this issue"
    elif [ "$existing" = yes ]; then
        workflow_info "a branch exists without a worktree; attach or track it instead of branching from origin/main"
    fi

    return 0
}

verify() {
    local issue=""
    local branch=""
    local base=""
    local repository=""
    local path="${PWD}"

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --issue) workflow_option_value "$@"; issue=$2; shift 2 ;;
            --branch) workflow_option_value "$@"; branch=$2; shift 2 ;;
            --base) workflow_option_value "$@"; base=$2; shift 2 ;;
            --repository) workflow_option_value "$@"; repository=$2; shift 2 ;;
            --path) workflow_option_value "$@"; path=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done

    workflow_positive_integer "$issue" || workflow_usage_error "--issue must be a positive integer"
    workflow_require_branch "$branch"
    workflow_require_sha "--base" "$base"
    workflow_require_bin GH_BIN "$GH_BIN"

    local root
    root="$(cd "$path" && workflow_repo_root)"
    local worktree_root
    worktree_root="$(workflow_normalize_path "$path")"
    if [ -n "$("$GIT_BIN" -C "$path" rev-parse --show-prefix)" ]; then
        workflow_die "--path must be the root of the worktree, not a subdirectory" 1
    fi

    local actual_repository
    actual_repository="$(workflow_github_repository "$repository")"

    local state
    state=$("$GH_BIN" issue view "$issue" --repo "$actual_repository" --json state --jq .state 2>/dev/null) \
        || workflow_die "could not read issue #$issue" 1
    if [ "$state" != "OPEN" ]; then
        workflow_die "issue #$issue is not open" 1
    fi

    local current_branch
    current_branch=$("$GIT_BIN" -C "$root" branch --show-current)
    if [ "$current_branch" != "$branch" ]; then
        workflow_die "worktree branch is '$current_branch', expected '$branch'" 1
    fi

    "$GIT_BIN" -C "$root" cat-file -e "$base^{commit}" 2>/dev/null \
        || workflow_die "base commit is not available locally" 1
    "$GIT_BIN" -C "$root" merge-base --is-ancestor "$base" HEAD \
        || workflow_die "worktree is not based on the prepared commit" 1

    "$GIT_BIN" fetch origin main >/dev/null 2>&1 \
        || workflow_die "could not fetch origin/main" 1
    "$GIT_BIN" -C "$root" merge-base --is-ancestor origin/main HEAD \
        || workflow_die "worktree does not contain current origin/main" 1

    workflow_require_clean_tree "$root"

    printf 'workspace: verified=yes\n'
    printf 'workspace: repository=%s\n' "$actual_repository"
    printf 'workspace: issue=%s\n' "$issue"
    printf 'workspace: branch=%s\n' "$branch"
    printf 'workspace: base_sha=%s\n' "$base"
    printf 'workspace: head_sha=%s\n' "$("$GIT_BIN" -C "$root" rev-parse HEAD)"
    printf 'workspace: path=%s\n' "$worktree_root"
}

main() {
    [ "$#" -gt 0 ] || { usage; exit 2; }
    local command=$1
    shift
    case "$command" in
        prepare) prepare "$@" ;;
        verify) verify "$@" ;;
        -h|--help|help) usage ;;
        *) workflow_usage_error "unknown command: $command" ;;
    esac
}

main "$@"
