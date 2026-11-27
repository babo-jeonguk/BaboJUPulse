#!/usr/bin/env bash
# Verify a merge, clean up safely, and report the exact final state.
#
#   cleanup.sh inspect --pr N [options]
#       Read-only inspection of merge ancestry, remote branch, local main,
#       workspace, worktree, and local branch.
#
#   cleanup.sh execute --pr N [options]
#       Perform every cleanup step that is safe. Dirty worktrees, unmerged
#       branches, fork branches, and diverged main are retained and reported.
#       Any ignored content retains the worktree unless --remove-build-output
#       explicitly requests removal of known reproducible output. Repeating a
#       completed step is safe.
#
# Options:
#   --verified-sha <sha>       Require this reviewed head to equal the PR head.
#   --branch <name>            Make the PR head branch explicit; must match.
#   --workspace-id <id>        Paseo workspace to archive.
#   --worktree <path>          Issue worktree to remove; must have the PR branch.
#   --main-worktree <path>     Worktree that has main checked out.
#   --remove-build-output      Explicitly remove known reproducible output
#                              (bin, obj, TestResults, .binlog) before worktree
#                              removal. Without this flag, any ignored content
#                              retains the worktree.
#   --repository <owner/name>  Require this GitHub repository.
#
# Run from a worktree that will remain after the issue worktree is removed.
# Exit codes: 0 clean, 1 blocked or failed, 2 usage error.
set -euo pipefail

WORKFLOW_NAME=cleanup
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$script_dir/common.sh"

usage() {
    sed -n '2,28p' "${BASH_SOURCE[0]}"
}

pr=""
verified_sha=""
branch=""
workspace_id=""
worktree=""
main_worktree=""
repository=""
remove_build_output=no
blocked=0

block() {
    printf 'cleanup: blocked=%s\n' "$1" >&2
    blocked=1
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --pr) workflow_option_value "$@"; pr=$2; shift 2 ;;
            --verified-sha) workflow_option_value "$@"; verified_sha=$2; shift 2 ;;
            --branch) workflow_option_value "$@"; branch=$2; shift 2 ;;
            --workspace-id) workflow_option_value "$@"; workspace_id=$2; shift 2 ;;
            --worktree) workflow_option_value "$@"; worktree=$2; shift 2 ;;
            --main-worktree) workflow_option_value "$@"; main_worktree=$2; shift 2 ;;
            --remove-build-output) remove_build_output=yes; shift ;;
            --repository) workflow_option_value "$@"; repository=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done
    workflow_positive_integer "$pr" || workflow_usage_error "--pr must be a positive integer"
    if [ -n "$verified_sha" ]; then
        workflow_require_sha "--verified-sha" "$verified_sha"
    fi
    if [ -n "$workspace_id" ]; then
        case "$workspace_id" in
            wks_*[!A-Za-z0-9_]*|wks_) workflow_usage_error "--workspace-id must be wks_ followed by letters, digits, or underscore" ;;
            wks_*) ;;
            *) workflow_usage_error "--workspace-id must start with wks_" ;;
        esac
    fi
}

normalize_path() {
    workflow_normalize_path "$1"
}

worktree_registered() {
    local root=$1
    local path=$2
    "$GIT_BIN" -C "$root" worktree list --porcelain \
        | awk '$1 == "worktree" { print substr($0, 10) }' \
        | grep -Fxq -- "$path"
}

load_pr() {
    workflow_require_bin GH_BIN "$GH_BIN"
    local actual_repository
    actual_repository="$(workflow_github_repository "$repository")"

    local record
    record=$("$GH_BIN" pr view "$pr" \
        --json number,state,mergedAt,mergeCommit,headRefName,headRefOid,headRepositoryOwner,headRepository,baseRefName,url \
        --jq '[.number, .state, (.mergedAt // ""), (.mergeCommit.oid // ""), .headRefName, .headRefOid, (.headRepositoryOwner.login // ""), (.headRepository.name // ""), .baseRefName, (.url // "")] | join("\u001f")' 2>/dev/null) \
        || workflow_die "could not read pull request #$pr" 1

    IFS=$'\x1f' read -r pr_number pr_state merged_at merge_sha pr_branch pr_head head_owner head_repo base_ref pr_url <<< "$record"
    if [ -z "$branch" ]; then
        branch=$pr_branch
    fi
    if [ "$branch" = "main" ] || [ "$branch" = "$base_ref" ]; then
        workflow_die "refusing to clean up the default or base branch" 1
    fi
    if [ "$branch" != "$pr_branch" ]; then
        workflow_die "--branch must match the PR head branch" 1
    fi
    if [ -n "$verified_sha" ] && [ "$pr_head" != "$verified_sha" ]; then
        workflow_die "the supplied verified SHA does not match the PR head" 1
    fi

    printf 'cleanup: repository=%s\n' "$actual_repository"
    printf 'cleanup: pr=%s state=%s url=%s\n' "$pr_number" "$pr_state" "$pr_url"
    printf 'cleanup: base=%s head=%s\n' "$base_ref" "$pr_branch"
    printf 'cleanup: merge_commit=%s merged_at=%s\n' "$merge_sha" "$merged_at"

    if [ "$pr_state" != "MERGED" ]; then
        workflow_die "pull request #$pr is not merged" 1
    fi
    if [ "$base_ref" != "main" ]; then
        workflow_die "pull request #$pr does not target main" 1
    fi
    if ! workflow_valid_sha "$merge_sha"; then
        workflow_die "pull request #$pr has no usable merge commit" 1
    fi

    if [ "$actual_repository" = "$head_owner/$head_repo" ]; then
        same_repository=yes
    else
        same_repository=no
    fi
    printf 'cleanup: same_repository=%s\n' "$same_repository"
}

root=""
same_repository=no
pr_number=""
pr_state=""
merged_at=""
merge_sha=""
pr_branch=""
pr_head=""
head_owner=""
head_repo=""
base_ref=""
pr_url=""

verify_merge() {
    root="$(workflow_repo_root)"
    cd "$root"
    "$GIT_BIN" fetch origin --prune >/dev/null 2>&1 \
        || workflow_die "could not refresh origin" 1
    "$GIT_BIN" cat-file -e "$merge_sha^{commit}" 2>/dev/null \
        || block "merge_commit_not_available"
    "$GIT_BIN" merge-base --is-ancestor "$merge_sha" origin/main \
        || block "merge_commit_not_on_main"
    if [ -n "$verified_sha" ]; then
        "$GIT_BIN" merge-base --is-ancestor "$verified_sha" origin/main \
            || block "verified_sha_not_on_main"
    fi
    if [ "$blocked" -eq 0 ]; then
        printf 'cleanup: merge_ancestry=verified\n'
    fi
}

remote_step() {
    local remote_sha
    if ! remote_sha="$(workflow_remote_branch_sha "$root" "$branch")"; then
        block "remote_branch_query_failed"
        return 0
    fi
    if [ -z "$remote_sha" ]; then
        printf 'cleanup: remote_branch=absent\n'
        return 0
    fi
    printf 'cleanup: remote_branch=present sha=%s\n' "$remote_sha"

    if [ "$same_repository" != yes ]; then
        printf 'cleanup: remote_branch=retained reason=external_fork\n'
        return 0
    fi

    "$GIT_BIN" -C "$root" fetch origin "refs/heads/$branch:refs/remotes/origin/$branch" >/dev/null 2>&1 \
        || { block "remote_branch_fetch_failed"; return 0; }
    if ! "$GIT_BIN" -C "$root" merge-base --is-ancestor "refs/remotes/origin/$branch" origin/main; then
        printf 'cleanup: remote_branch=retained reason=commits_not_merged\n'
        return 0
    fi

    printf 'cleanup: remote_branch=delete_candidate\n'
    if [ "$MODE" = inspect ]; then
        return 0
    fi

    if ! "$GIT_BIN" -C "$root" push \
        --force-with-lease="refs/heads/$branch:$remote_sha" \
        origin --delete "$branch" >/dev/null 2>&1; then
        block "remote_branch_delete_failed"
        return 0
    fi
    if ! "$GIT_BIN" -C "$root" fetch origin --prune >/dev/null 2>&1; then
        printf 'cleanup: warning=remote_tracking_refresh_failed\n'
    fi
    local remaining
    if ! remaining="$(workflow_remote_branch_sha "$root" "$branch")"; then
        block "remote_branch_verify_failed"
        return 0
    fi
    if [ -n "$remaining" ]; then
        block "remote_branch_still_present"
        return 0
    fi
    printf 'cleanup: remote_branch=deleted\n'
}

main_step() {
    local path=${main_worktree:-$(workflow_main_worktree)}
    if [ -z "$path" ]; then
        printf 'cleanup: local_main=absent reason=no_main_worktree\n'
        return 0
    fi
    path="$(normalize_path "$path")"
    if [ ! -d "$path" ]; then
        printf 'cleanup: local_main=absent path_missing=yes\n'
        return 0
    fi
    if [ -n "$("$GIT_BIN" -C "$path" rev-parse --show-prefix 2>/dev/null)" ]; then
        block "local_main_worktree_not_root"
        return 0
    fi
    if [ "$("$GIT_BIN" -C "$path" branch --show-current)" != "main" ]; then
        block "local_main_worktree_not_main"
        return 0
    fi
    if [ -n "$("$GIT_BIN" -C "$path" status --porcelain --untracked-files=all)" ]; then
        block "local_main_dirty"
        return 0
    fi
    if ! "$GIT_BIN" -C "$path" merge-base --is-ancestor HEAD origin/main; then
        block "local_main_diverged"
        return 0
    fi

    local current
    current=$("$GIT_BIN" -C "$path" rev-parse HEAD)
    if [ "$current" = "$("$GIT_BIN" -C "$root" rev-parse origin/main)" ]; then
        printf 'cleanup: local_main=unchanged sha=%s\n' "$current"
        return 0
    fi
    if [ "$MODE" = inspect ]; then
        printf 'cleanup: local_main=fast_forward_candidate from=%s\n' "$current"
        return 0
    fi
    if ! "$GIT_BIN" -C "$path" merge --ff-only origin/main >/dev/null 2>&1; then
        block "local_main_fast_forward_failed"
        return 0
    fi
    current=$("$GIT_BIN" -C "$path" rev-parse HEAD)
    if [ "$current" != "$("$GIT_BIN" -C "$root" rev-parse origin/main)" ]; then
        block "local_main_not_synchronized"
        return 0
    fi
    printf 'cleanup: local_main=synchronized sha=%s\n' "$current"
}

archive_workspace() {
    local status=0
    if workflow_paseo_workspace_exists "$workspace_id"; then
        status=0
    else
        status=$?
        if [ "$status" -eq 1 ]; then
            printf 'cleanup: workspace=absent\n'
            return 0
        fi
        block "workspace_query_failed"
        return 1
    fi

    if ! "$PASEO_BIN" workspace archive "$workspace_id" >/dev/null 2>&1; then
        block "workspace_archive_failed"
        return 1
    fi

    if workflow_paseo_workspace_exists "$workspace_id"; then
        block "workspace_still_present"
        return 1
    else
        status=$?
        if [ "$status" -ne 1 ]; then
            block "workspace_verify_failed"
            return 1
        fi
    fi
    printf 'cleanup: workspace=archived\n'
    return 0
}

workspace_step() {
    local registered
    registered="$(workflow_worktree_for_branch "$branch")"
    local path=${worktree:-$registered}
    if [ -z "$registered" ] && { [ -z "$worktree" ] || [ ! -e "$worktree" ]; }; then
        printf 'cleanup: worktree=absent\n'
        if [ -z "$workspace_id" ]; then
            printf 'cleanup: workspace=absent\n'
            return 0
        fi
        local status=0
        if workflow_paseo_workspace_exists "$workspace_id"; then
            status=0
        else
            status=$?
            if [ "$status" -eq 1 ]; then
                printf 'cleanup: workspace=absent\n'
                return 0
            fi
            block "workspace_query_failed"
            return 0
        fi
        printf 'cleanup: workspace=present id=%s\n' "$workspace_id"
        if [ "$MODE" = inspect ]; then
            printf 'cleanup: workspace=archive_candidate\n'
            return 0
        fi
        archive_workspace
        return 0
    fi
    if [ -z "$path" ]; then
        printf 'cleanup: worktree=absent\n'
        printf 'cleanup: workspace=absent\n'
        return 0
    fi
    if [ -d "$path" ] && [ -n "$("$GIT_BIN" -C "$path" rev-parse --show-prefix 2>/dev/null)" ]; then
        block "worktree_path_not_root"
        return 0
    fi
    path="$(normalize_path "$path")"
    printf 'cleanup: worktree=present path=%s\n' "$path"
    local cwd
    cwd="$(workflow_normalize_path "$PWD")"
    if workflow_path_is_within "$path" "$cwd"; then
        block "cleanup_running_inside_target_worktree"
        return 0
    fi

    if ! worktree_registered "$root" "$path"; then
        printf 'cleanup: worktree=retained reason=not_a_registered_worktree\n'
        return 0
    fi

    local worktree_branch
    worktree_branch=$("$GIT_BIN" -C "$path" branch --show-current)
    if [ "$worktree_branch" != "$branch" ]; then
        block "worktree_branch_mismatch"
        return 0
    fi

    if ! workflow_worktree_status "$path" "$remove_build_output"; then
        block "worktree_has_local_content"
        return 0
    fi

    if [ -z "$workspace_id" ] && command -v "$PASEO_BIN" >/dev/null 2>&1; then
        if ! workspace_id="$(workflow_paseo_workspace_id_for_cwd "$path")"; then
            block "workspace_query_failed"
            return 0
        fi
    fi
    if [ -n "$workspace_id" ]; then
        local workspace_status=0
        if workflow_paseo_workspace_exists "$workspace_id"; then
            workspace_status=0
        else
            workspace_status=$?
            if [ "$workspace_status" -eq 2 ]; then
                block "workspace_query_failed"
                return 0
            fi
            if command -v "$PASEO_BIN" >/dev/null 2>&1; then
                local detected
                if ! detected="$(workflow_paseo_workspace_id_for_cwd "$path")"; then
                    block "workspace_query_failed"
                    return 0
                fi
                if [ -n "$detected" ] && [ "$detected" != "$workspace_id" ]; then
                    block "workspace_id_mismatch"
                    return 0
                fi
            fi
            printf 'cleanup: workspace=absent id=%s\n' "$workspace_id"
            workspace_id=""
        fi
    fi
    if [ -n "$workspace_id" ]; then
        local workspace_cwd
        if ! workspace_cwd="$(workflow_paseo_workspace_cwd "$workspace_id")"; then
            block "workspace_query_failed"
            return 0
        fi
        if [ -z "$workspace_cwd" ]; then
            block "workspace_cwd_missing"
            return 0
        fi
        if [ "$(workflow_normalize_path "$workspace_cwd")" != "$path" ]; then
            block "workspace_cwd_mismatch"
            return 0
        fi
        printf 'cleanup: workspace=present id=%s\n' "$workspace_id"
    else
        printf 'cleanup: workspace=absent\n'
    fi

    if [ "$MODE" = inspect ]; then
        printf 'cleanup: worktree=remove_candidate\n'
        if [ -n "$workspace_id" ]; then
            printf 'cleanup: workspace=archive_candidate\n'
        fi
        return 0
    fi

    if [ -n "$workspace_id" ]; then
        archive_workspace || return 0
    fi

    if ! "$GIT_BIN" -C "$root" worktree prune >/dev/null 2>&1; then
        printf 'cleanup: warning=worktree_prune_failed\n'
    fi
    if worktree_registered "$root" "$path"; then
        if [ "$remove_build_output" = yes ]; then
            workflow_remove_reproducible_output "$path"
        fi
        if ! "$GIT_BIN" -C "$root" worktree remove "$path" >/dev/null 2>&1; then
            block "worktree_remove_failed"
            return 0
        fi
    fi
    if ! "$GIT_BIN" -C "$root" worktree prune >/dev/null 2>&1; then
        printf 'cleanup: warning=worktree_prune_failed\n'
    fi

    if worktree_registered "$root" "$path"; then
        block "worktree_still_registered"
        return 0
    fi
    if [ -e "$path" ]; then
        printf 'cleanup: worktree=retained reason=directory_still_present\n'
        return 0
    fi
    printf 'cleanup: worktree=removed\n'
}

branch_step() {
    if ! workflow_branch_exists "$root" "$branch"; then
        printf 'cleanup: local_branch=absent\n'
        return 0
    fi
    if [ -n "$(workflow_worktree_for_branch "$branch")" ]; then
        if [ "$MODE" = inspect ]; then
            printf 'cleanup: local_branch=delete_candidate_after_worktree_removal\n'
            return 0
        fi
        printf 'cleanup: local_branch=retained reason=checked_out_in_worktree\n'
        return 0
    fi
    if ! "$GIT_BIN" -C "$root" merge-base --is-ancestor "$branch" origin/main; then
        printf 'cleanup: local_branch=retained reason=commits_not_merged\n'
        return 0
    fi
    if [ "$MODE" = inspect ]; then
        printf 'cleanup: local_branch=delete_candidate\n'
        return 0
    fi
    if ! "$GIT_BIN" -C "$root" branch -d "$branch" >/dev/null 2>&1; then
        block "local_branch_delete_failed"
        return 0
    fi
    if workflow_branch_exists "$root" "$branch"; then
        block "local_branch_still_present"
        return 0
    fi
    printf 'cleanup: local_branch=deleted\n'
}

run() {
    load_pr
    verify_merge
    if [ "$blocked" -eq 1 ]; then
        printf 'cleanup: result=blocked\n' >&2
        return 1
    fi
    remote_step
    main_step
    workspace_step
    branch_step

    if [ "$blocked" -eq 1 ]; then
        printf 'cleanup: result=blocked\n' >&2
        return 1
    fi
    printf 'cleanup: result=pass\n'
}

main() {
    [ "$#" -gt 0 ] || { usage; exit 2; }
    local command=$1
    shift
    case "$command" in
        inspect)
            MODE=inspect
            parse_args "$@"
            run
            ;;
        execute)
            MODE=execute
            parse_args "$@"
            run
            ;;
        -h|--help|help) usage ;;
        *) workflow_usage_error "unknown command: $command" ;;
    esac
}

main "$@"
