#!/usr/bin/env bash
# Verify a merge, clean up safely, and report the exact final state.
#
#   cleanup.sh inspect --pr N [options]
#       Read-only inspection of merge ancestry, repository identity, remote
#       branch, local main, local branch, workspace, worktree, and agents.
#
#   cleanup.sh execute --pr N [options]
#       Perform every cleanup step that is safe. Unmerged local branches,
#       dirty worktrees, fork branches, unrelated or ongoing agents, and
#       diverged main are retained and reported. Any ignored content retains
#       the worktree unless --remove-build-output explicitly requests removal
#       of content that is fully reproducible build output. Repeating a
#       completed step is safe.
#
# Options:
#   --verified-sha <sha>       Require this reviewed head to equal the PR head.
#   --branch <name>            Make the PR head branch explicit; must match.
#   --workspace-id <id>        Paseo workspace to archive; its worktree, branch,
#                              and agents must be verified before archiving.
#   --worktree <path>          Issue worktree to remove; must have the PR branch.
#   --main-worktree <path>     Worktree that has main checked out in this repo.
#   --remove-build-output      Explicitly remove known reproducible output
#                              (generated files under bin, obj, TestResults,
#                              and top-level .binlog files). Mixed or
#                              unrecognized content is retained, and the
#                              worktree is not removed.
#   --repository <owner/name>  Require this GitHub repository.
#
# Run from a worktree that will remain after the issue worktree is removed.
# Exit codes: 0 clean, 1 blocked or failed, 2 usage error.
set -euo pipefail

WORKFLOW_NAME=cleanup
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$script_dir/common.sh"

usage() {
    sed -n '2,31p' "${BASH_SOURCE[0]}"
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
local_branch_state=absent
local_branch_merged=yes

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
    local actual_repository=$1
    local record
    record=$("$GH_BIN" pr view "$pr" --repo "$actual_repository" \
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
    "$GIT_BIN" -C "$root" fetch origin --prune >/dev/null 2>&1 \
        || workflow_die "could not refresh origin" 1
    if ! "$GIT_BIN" -C "$root" rev-parse --verify origin/main >/dev/null 2>&1; then
        block "origin_main_not_available"
        return 0
    fi
    "$GIT_BIN" -C "$root" cat-file -e "$merge_sha^{commit}" 2>/dev/null \
        || block "merge_commit_not_available"
    "$GIT_BIN" -C "$root" merge-base --is-ancestor "$merge_sha" origin/main \
        || block "merge_commit_not_on_main"
    if [ -n "$verified_sha" ]; then
        "$GIT_BIN" -C "$root" merge-base --is-ancestor "$verified_sha" origin/main \
            || block "verified_sha_not_on_main"
    fi
    if [ "$blocked" -eq 0 ]; then
        printf 'cleanup: merge_ancestry=verified\n'
    fi
}

branch_preflight() {
    if ! workflow_branch_exists "$root" "$branch"; then
        local_branch_state=absent
        local_branch_merged=yes
        return 0
    fi
    local_branch_state=present
    local tip
    if ! tip=$("$GIT_BIN" -C "$root" rev-parse --verify "refs/heads/$branch^{commit}" 2>/dev/null); then
        printf 'cleanup: local_branch=present sha=unreadable\n'
        block "local_branch_tip_unreadable"
        local_branch_merged=no
        return 0
    fi
    printf 'cleanup: local_branch=present sha=%s\n' "$tip"
    if ! "$GIT_BIN" -C "$root" merge-base --is-ancestor "$tip" origin/main; then
        block "local_branch_commits_not_merged"
        local_branch_merged=no
        return 0
    fi
    local_branch_merged=yes
    printf 'cleanup: local_branch_ancestry=merged\n'
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
    local fetched_sha
    if ! fetched_sha=$("$GIT_BIN" -C "$root" rev-parse --verify "refs/remotes/origin/$branch^{commit}" 2>/dev/null); then
        block "remote_branch_fetch_failed"
        return 0
    fi
    if [ "$fetched_sha" != "$remote_sha" ]; then
        block "remote_branch_changed_before_verification"
        return 0
    fi
    if ! "$GIT_BIN" -C "$root" merge-base --is-ancestor "$remote_sha" origin/main; then
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

main_identity_preflight() {
    local path=${main_worktree:-$(workflow_main_worktree)}
    if [ -z "$path" ]; then
        return 0
    fi
    if [ ! -d "$path" ]; then
        if [ -n "$main_worktree" ]; then
            block "local_main_worktree_missing"
        fi
        return 0
    fi
    if [ -n "$("$GIT_BIN" -C "$path" rev-parse --show-prefix 2>/dev/null)" ]; then
        block "local_main_worktree_not_root"
        return 0
    fi
    path="$(normalize_path "$path")"
    if [ ! -d "$path" ]; then
        if [ -n "$main_worktree" ]; then
            block "local_main_worktree_missing"
        fi
        return 0
    fi
    local root_common main_common
    if ! root_common="$(workflow_git_common_dir "$root")"; then
        block "repository_identity_unverified"
        return 0
    fi
    if ! main_common="$(workflow_git_common_dir "$path")"; then
        block "local_main_repository_unverified"
        return 0
    fi
    if [ "$root_common" != "$main_common" ]; then
        block "local_main_repository_mismatch"
    fi
}

main_step() {
    local path=${main_worktree:-$(workflow_main_worktree)}
    if [ -z "$path" ]; then
        printf 'cleanup: local_main=absent reason=no_main_worktree\n'
        return 0
    fi
    if [ -d "$path" ] && [ -n "$("$GIT_BIN" -C "$path" rev-parse --show-prefix 2>/dev/null)" ]; then
        block "local_main_worktree_not_root"
        return 0
    fi
    path="$(normalize_path "$path")"
    if [ ! -d "$path" ]; then
        if [ -n "$main_worktree" ]; then
            block "local_main_worktree_missing"
        else
            printf 'cleanup: local_main=absent path_missing=yes\n'
        fi
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

workspace_record() {
    local id=$1
    local record
    local status=0
    record="$(workflow_paseo_workspace_record "$id")" || status=$?
    if [ "$status" -ne 0 ]; then
        return "$status"
    fi
    printf '%s' "$record"
}

local_branch_ancestry_merged() {
    local tip
    if ! tip=$("$GIT_BIN" -C "$root" rev-parse --verify "refs/heads/$branch^{commit}" 2>/dev/null); then
        return 1
    fi
    "$GIT_BIN" -C "$root" merge-base --is-ancestor "$tip" origin/main
}

workspace_agent_safety() {
    local id=$1
    local path=$2
    local agents
    local status=0
    agents="$(workflow_paseo_agents)" || status=$?
    if [ "$status" -ne 0 ]; then
        block "workspace_agent_query_failed"
        return 1
    fi
    local agent_id agent_status agent_cwd agent_workspace agent_name
    local agent_path in_target
    while IFS=$'\x1f' read -r agent_id agent_status agent_cwd agent_workspace agent_name; do
        [ -n "$agent_id" ] || continue
        agent_path=""
        if [ -n "$agent_cwd" ]; then
            agent_path="$(workflow_normalize_path "$agent_cwd")"
        fi
        in_target=no
        if [ -n "$agent_path" ] && workflow_path_is_within "$path" "$agent_path"; then
            in_target=yes
        fi
        if [ "$agent_workspace" = "$id" ]; then
            if [ -z "$agent_path" ]; then
                block "workspace_agent_cwd_missing"
                return 1
            fi
            if [ "$in_target" != yes ]; then
                block "workspace_agent_unrelated"
                return 1
            fi
            case "$agent_status" in
                idle|closed|done|error|failed|cancelled|archived) ;;
                *)
                    block "workspace_agent_ongoing"
                    return 1
                    ;;
            esac
        elif [ "$in_target" = yes ]; then
            block "workspace_agent_other_workspace"
            return 1
        fi
    done <<< "$agents"
    return 0
}

verify_workspace_for_archive() {
    local id=$1
    local expected=$2
    local allow_missing=$3
    local record
    local status=0
    record="$(workspace_record "$id")" || status=$?
    if [ "$status" -eq 1 ]; then
        printf 'cleanup: workspace=absent id=%s\n' "$id"
        return 1
    fi
    if [ "$status" -ne 0 ]; then
        block "workspace_query_failed"
        return 1
    fi

    local record_id record_cwd record_project record_isolation
    IFS=$'\x1f' read -r record_id record_cwd record_project record_isolation <<< "$record"
    if [ "$record_id" != "$id" ]; then
        block "workspace_record_mismatch"
        return 1
    fi
    if [ -z "$record_cwd" ]; then
        block "workspace_cwd_missing"
        return 1
    fi
    local normalized_cwd
    normalized_cwd="$(normalize_path "$record_cwd")"
    if [ "$normalized_cwd" != "$expected" ]; then
        block "workspace_cwd_mismatch"
        return 1
    fi

    if [ -d "$expected" ]; then
        if [ -n "$("$GIT_BIN" -C "$expected" rev-parse --show-prefix 2>/dev/null)" ]; then
            block "workspace_worktree_not_root"
            return 1
        fi
        local worktree_common root_common
        if ! worktree_common="$(workflow_git_common_dir "$expected")"; then
            block "workspace_repository_unverified"
            return 1
        fi
        if ! root_common="$(workflow_git_common_dir "$root")"; then
            block "repository_identity_unverified"
            return 1
        fi
        if [ "$worktree_common" != "$root_common" ]; then
            block "workspace_repository_mismatch"
            return 1
        fi
        local worktree_branch
        if ! worktree_branch=$("$GIT_BIN" -C "$expected" branch --show-current); then
            block "workspace_branch_unreadable"
            return 1
        fi
        if [ "$worktree_branch" != "$branch" ]; then
            block "workspace_branch_mismatch"
            return 1
        fi
        if ! worktree_registered "$root" "$expected"; then
            block "workspace_worktree_not_registered"
            return 1
        fi
        if ! workflow_worktree_status "$expected" "$remove_build_output"; then
            block "worktree_has_local_content"
            return 1
        fi
    else
        if [ "$allow_missing" != yes ]; then
            block "workspace_ownership_unverifiable"
            return 1
        fi
        local registered_branch
        if ! registered_branch="$(workflow_worktree_branch_registered "$root" "$expected")"; then
            block "workspace_ownership_unverifiable"
            return 1
        fi
        if [ -z "$registered_branch" ]; then
            block "workspace_ownership_unverifiable"
            return 1
        fi
        if [ "$registered_branch" != "$branch" ]; then
            block "workspace_branch_mismatch"
            return 1
        fi
    fi

    workspace_agent_safety "$id" "$expected" || return 1
    if ! local_branch_ancestry_merged; then
        block "local_branch_commits_not_merged"
        return 1
    fi
    printf 'cleanup: workspace=present id=%s\n' "$id"
    return 0
}

archive_workspace() {
    local id=$1
    local expected=$2
    if ! verify_workspace_for_archive "$id" "$expected" yes; then
        return 1
    fi
    if ! "$PASEO_BIN" workspace archive "$id" >/dev/null 2>&1; then
        block "workspace_archive_failed"
        return 1
    fi

    local status=0
    workflow_paseo_workspace_exists "$id" || status=$?
    if [ "$status" -eq 0 ]; then
        block "workspace_still_present"
        return 1
    fi
    if [ "$status" -ne 1 ]; then
        block "workspace_verify_failed"
        return 1
    fi
    printf 'cleanup: workspace=archived\n'
    return 0
}

workspace_absent_step() {
    local id=$1
    local status=0
    workflow_paseo_workspace_exists "$id" || status=$?
    if [ "$status" -eq 1 ]; then
        printf 'cleanup: workspace=absent id=%s\n' "$id"
        return 0
    fi
    if [ "$status" -ne 0 ]; then
        block "workspace_query_failed"
        return 0
    fi
    printf 'cleanup: workspace=present id=%s\n' "$id"
    block "workspace_ownership_unverifiable"
    return 0
}

workspace_step() {
    local registered
    registered="$(workflow_worktree_for_branch "$branch")"
    local path=${worktree:-$registered}

    if [ "$local_branch_state" = present ] && [ "$local_branch_merged" != yes ]; then
        printf 'cleanup: worktree=retained reason=local_branch_commits_not_merged\n'
        printf 'cleanup: workspace=retained reason=local_branch_commits_not_merged\n'
        return 0
    fi

    if [ -n "$registered" ] && [ -n "$worktree" ]; then
        if [ "$(normalize_path "$worktree")" != "$(normalize_path "$registered")" ]; then
            block "worktree_path_mismatch"
            return 0
        fi
    fi

    if [ -z "$path" ]; then
        printf 'cleanup: worktree=absent\n'
        if [ -z "$workspace_id" ]; then
            printf 'cleanup: workspace=absent\n'
            return 0
        fi
        workspace_absent_step "$workspace_id"
        return 0
    fi

    if [ ! -e "$path" ]; then
        printf 'cleanup: worktree=absent path=%s\n' "$path"
        if [ -z "$workspace_id" ]; then
            printf 'cleanup: workspace=absent\n'
            return 0
        fi
        path="$(normalize_path "$path")"
        local absent_status=0
        workflow_paseo_workspace_exists "$workspace_id" || absent_status=$?
        if [ "$absent_status" -eq 1 ]; then
            printf 'cleanup: workspace=absent id=%s\n' "$workspace_id"
            "$GIT_BIN" -C "$root" worktree prune >/dev/null 2>&1 \
                || printf 'cleanup: warning=worktree_prune_failed\n'
            return 0
        fi
        if [ "$absent_status" -ne 0 ]; then
            block "workspace_query_failed"
            return 0
        fi
        if ! verify_workspace_for_archive "$workspace_id" "$path" yes; then
            return 0
        fi
        if [ "$MODE" = inspect ]; then
            printf 'cleanup: workspace=archive_candidate\n'
            return 0
        fi
        archive_workspace "$workspace_id" "$path" || return 0
        if ! "$GIT_BIN" -C "$root" worktree prune >/dev/null 2>&1; then
            printf 'cleanup: warning=worktree_prune_failed\n'
        fi
        printf 'cleanup: worktree=absent reason=directory_missing\n'
        return 0
    fi

    if [ -d "$path" ] && [ -n "$("$GIT_BIN" -C "$path" rev-parse --show-prefix 2>/dev/null)" ]; then
        block "worktree_path_not_root"
        return 0
    fi
    path="$(normalize_path "$path")"
    printf 'cleanup: worktree=present path=%s\n' "$path"
    local cwd
    cwd="$(normalize_path "$PWD")"
    if workflow_path_is_within "$path" "$cwd"; then
        block "cleanup_running_inside_target_worktree"
        return 0
    fi

    if ! worktree_registered "$root" "$path"; then
        printf 'cleanup: worktree=retained reason=not_a_registered_worktree\n'
        if [ -n "$workspace_id" ]; then
            block "worktree_not_registered"
        fi
        return 0
    fi

    local root_common worktree_common
    if ! root_common="$(workflow_git_common_dir "$root")"; then
        block "repository_identity_unverified"
        return 0
    fi
    if ! worktree_common="$(workflow_git_common_dir "$path")"; then
        block "worktree_repository_unverified"
        return 0
    fi
    if [ "$root_common" != "$worktree_common" ]; then
        block "worktree_repository_mismatch"
        return 0
    fi

    local worktree_branch
    if ! worktree_branch=$("$GIT_BIN" -C "$path" branch --show-current); then
        block "worktree_branch_unreadable"
        return 0
    fi
    if [ "$worktree_branch" != "$branch" ]; then
        block "worktree_branch_mismatch"
        return 0
    fi

    if ! workflow_worktree_status "$path" "$remove_build_output"; then
        block "worktree_has_local_content"
        return 0
    fi

    local detected=""
    if command -v "$PASEO_BIN" >/dev/null 2>&1; then
        if ! detected="$(workflow_paseo_workspace_id_for_cwd "$path")"; then
            block "workspace_query_failed"
            return 0
        fi
    fi
    if [ -n "$workspace_id" ] && [ -n "$detected" ] && [ "$detected" != "$workspace_id" ]; then
        block "workspace_id_mismatch"
        return 0
    fi
    if [ -z "$workspace_id" ]; then
        workspace_id=$detected
    fi
    if [ -n "$workspace_id" ]; then
        local workspace_status=0
        workflow_paseo_workspace_exists "$workspace_id" || workspace_status=$?
        if [ "$workspace_status" -eq 1 ]; then
            printf 'cleanup: workspace=absent id=%s\n' "$workspace_id"
            workspace_id=""
        elif [ "$workspace_status" -ne 0 ]; then
            block "workspace_query_failed"
            return 0
        fi
    fi
    if [ -n "$workspace_id" ]; then
        if ! verify_workspace_for_archive "$workspace_id" "$path" no; then
            return 0
        fi
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
        archive_workspace "$workspace_id" "$path" || return 0
    fi

    if ! "$GIT_BIN" -C "$root" worktree prune >/dev/null 2>&1; then
        printf 'cleanup: warning=worktree_prune_failed\n'
    fi
    if worktree_registered "$root" "$path"; then
        if ! local_branch_ancestry_merged; then
            block "local_branch_commits_not_merged"
            return 0
        fi
        if [ -d "$path" ]; then
            if ! workflow_worktree_status "$path" "$remove_build_output"; then
                block "worktree_has_local_content"
                return 0
            fi
            if [ "$remove_build_output" = yes ]; then
                workflow_remove_reproducible_output "$path"
            fi
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
        block "worktree_directory_still_present"
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
        block "local_branch_checked_out"
        return 0
    fi
    local tip
    if ! tip=$("$GIT_BIN" -C "$root" rev-parse --verify "refs/heads/$branch^{commit}" 2>/dev/null); then
        printf 'cleanup: local_branch=retained reason=tip_unreadable\n'
        block "local_branch_tip_unreadable"
        return 0
    fi
    if ! "$GIT_BIN" -C "$root" merge-base --is-ancestor "$tip" origin/main; then
        printf 'cleanup: local_branch=retained reason=commits_not_merged\n'
        block "local_branch_commits_not_merged"
        return 0
    fi
    if [ "$MODE" = inspect ]; then
        printf 'cleanup: local_branch=delete_candidate\n'
        return 0
    fi
    if [ "$blocked" -eq 1 ]; then
        printf 'cleanup: local_branch=retained reason=cleanup_blocked\n'
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
    root="$(workflow_repo_root)"
    cd "$root"
    local actual_repository
    actual_repository="$(workflow_verify_repository_identity "$root" "$repository")"
    repository=$actual_repository
    load_pr "$actual_repository"
    verify_merge
    if [ "$blocked" -eq 1 ]; then
        printf 'cleanup: result=blocked\n' >&2
        return 1
    fi
    branch_preflight
    if [ "$local_branch_state" = present ] && [ "$local_branch_merged" != yes ]; then
        printf 'cleanup: worktree=retained reason=local_branch_commits_not_merged\n'
        printf 'cleanup: workspace=retained reason=local_branch_commits_not_merged\n'
    fi
    main_identity_preflight
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
