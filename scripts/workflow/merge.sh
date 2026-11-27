#!/usr/bin/env bash
# Inspect merge readiness and, only on explicit request, merge a pull request.
#
#   merge.sh inspect --pr N --verified-sha <sha> [options]
#       Read-only. Fails unless the current PR head equals the verified SHA,
#       the PR is open, mergeable, targets main, and every required check
#       passes. The verified SHA is never replaced with a freshly fetched value.
#
#   merge.sh execute --pr N --verified-sha <sha> [options]
#       Repeats the inspection, then merges with the original verified SHA as
#       --match-head-commit. Does not bypass branch protection or admin rules.
#
# Options:
#   --repository <owner/name>  Require this GitHub repository.
#   --require-check <name>     Add a required check name (repeatable; the default
#                              set is build and documentation).
#   --allow-missing-check <name>
#                              Explicitly allow a missing non-mandatory check.
#                              Use only when its unavailability is recorded and a
#                              local equivalent was verified; a failing check or
#                              the mandatory build check is never allowed.
#   --delete-branch            Also request branch deletion. Prefer cleanup.sh,
#                              which verifies merge ancestry first.
#
# Exit codes: 0 ready/merged, 1 blocked or failed, 2 usage error.
set -euo pipefail

WORKFLOW_NAME=merge
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$script_dir/common.sh"

usage() {
    sed -n '2,25p' "${BASH_SOURCE[0]}"
}

pr=""
verified_sha=""
repository=""
delete_branch=no
require_checks=(build documentation)
allow_missing_checks=()
mandatory_checks=(build)

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --pr) workflow_option_value "$@"; pr=$2; shift 2 ;;
            --verified-sha) workflow_option_value "$@"; verified_sha=$2; shift 2 ;;
            --repository) workflow_option_value "$@"; repository=$2; shift 2 ;;
            --require-check) workflow_option_value "$@"; require_checks+=("$2"); shift 2 ;;
            --allow-missing-check) workflow_option_value "$@"; allow_missing_checks+=("$2"); shift 2 ;;
            --delete-branch) delete_branch=yes; shift ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done
    workflow_positive_integer "$pr" || workflow_usage_error "--pr must be a positive integer"
    workflow_require_sha "--verified-sha" "$verified_sha"
    local check
    for check in "${require_checks[@]}"; do
        [ -n "$check" ] || workflow_usage_error "--require-check needs a name"
    done
    for check in "${allow_missing_checks[@]}"; do
        local mandatory
        for mandatory in "${mandatory_checks[@]}"; do
            if [ "$check" = "$mandatory" ]; then
                workflow_usage_error "--allow-missing-check may not cover the mandatory $mandatory check"
            fi
        done
    done
}

evaluate() {
    workflow_require_bin GH_BIN "$GH_BIN"
    local actual_repository
    actual_repository="$(workflow_github_repository "$repository")"

    local record
    record=$("$GH_BIN" pr view "$pr" \
        --json number,state,isDraft,baseRefName,headRefOid,headRefName,headRepositoryOwner,headRepository,mergeable,mergeStateStatus,url \
        --jq '[.number, .state, .isDraft, .baseRefName, .headRefOid, .headRefName, (.headRepositoryOwner.login // ""), (.headRepository.name // ""), (.mergeable // ""), (.mergeStateStatus // ""), (.url // "")] | join("\u001f")' 2>/dev/null) \
        || workflow_die "could not read pull request #$pr" 1

    local number state is_draft base_ref head_sha head_ref head_owner head_repo mergeable merge_state url
    IFS=$'\x1f' read -r number state is_draft base_ref head_sha head_ref head_owner head_repo mergeable merge_state url <<< "$record"

    printf 'merge: repository=%s\n' "$actual_repository"
    printf 'merge: pr=%s state=%s draft=%s url=%s\n' "$number" "$state" "$is_draft" "$url"
    printf 'merge: base=%s head=%s\n' "$base_ref" "$head_ref"
    printf 'merge: verified_sha=%s\n' "$verified_sha"
    printf 'merge: head_sha=%s\n' "$head_sha"
    printf 'merge: head_matches=%s\n' "$([ "$head_sha" = "$verified_sha" ] && printf yes || printf no)"
    printf 'merge: mergeable=%s merge_state=%s\n' "$mergeable" "$merge_state"

    local blocked=0
    if [ "$state" != "OPEN" ]; then
        printf 'merge: condition=state result=fail\n' >&2
        blocked=1
    fi
    if [ "$is_draft" != "false" ]; then
        printf 'merge: condition=draft result=fail\n' >&2
        blocked=1
    fi
    if [ "$base_ref" != "main" ]; then
        printf 'merge: condition=base result=fail expected=main\n' >&2
        blocked=1
    fi
    if [ "$head_sha" != "$verified_sha" ]; then
        printf 'merge: condition=verified_sha result=fail; return to review and verification\n' >&2
        blocked=1
    fi
    if [ "$mergeable" != "MERGEABLE" ]; then
        printf 'merge: condition=mergeable result=fail\n' >&2
        blocked=1
    fi
    case "$merge_state" in
        CLEAN|UNSTABLE|HAS_HOOKS) ;;
        *)
            printf 'merge: condition=merge_state result=fail value=%s\n' "$merge_state" >&2
            blocked=1
            ;;
    esac
    if [ "$delete_branch" = yes ] && [ "$actual_repository" != "$head_owner/$head_repo" ]; then
        printf 'merge: condition=same_repository result=fail; a fork branch must not be deleted by the merge\n' >&2
        blocked=1
    fi

    local checks_output
    local checks_code=0
    local checks_readable=1
    set +e
    checks_output=$("$GH_BIN" pr checks "$pr" --json name,state,bucket \
        --jq '.[] | [.name, .state, .bucket] | join("\u001f")' 2>/dev/null)
    checks_code=$?
    set -e
    if [ "$checks_code" -ne 0 ] && [ "$checks_code" -ne 8 ]; then
        printf 'merge: condition=checks result=fail; could not read checks (exit %s)\n' "$checks_code" >&2
        blocked=1
        checks_readable=0
        checks_output=""
    fi

    local check
    for check in "${require_checks[@]}"; do
        local matched=0
        local passed=0
        local check_state
        local check_bucket
        while IFS=$'\x1f' read -r check_name check_state check_bucket; do
            [ -n "$check_name" ] || continue
            if [ "$check_name" = "$check" ]; then
                matched=1
                if [ "$check_bucket" = "pass" ]; then
                    passed=1
                else
                    printf 'merge: check=%s state=%s bucket=%s result=fail\n' "$check" "$check_state" "$check_bucket" >&2
                    blocked=1
                fi
            fi
        done <<< "$checks_output"
        if [ "$matched" -eq 0 ]; then
            local allowed=0
            local candidate
            for candidate in "${allow_missing_checks[@]}"; do
                if [ "$candidate" = "$check" ]; then
                    allowed=1
                fi
            done
            if [ "$checks_readable" -ne 1 ]; then
                printf 'merge: check=%s result=unverified\n' "$check" >&2
                blocked=1
            elif [ "$allowed" -eq 1 ]; then
                printf 'merge: check=%s result=allowed-missing\n' "$check"
            else
                printf 'merge: check=%s result=missing\n' "$check" >&2
                blocked=1
            fi
        elif [ "$passed" -eq 1 ]; then
            printf 'merge: check=%s result=pass\n' "$check"
        fi
    done

    if [ "$blocked" -eq 1 ]; then
        printf 'merge: result=blocked\n' >&2
        return 1
    fi
    printf 'merge: result=ready\n'
    return 0
}

main() {
    [ "$#" -gt 0 ] || { usage; exit 2; }
    local command=$1
    shift
    case "$command" in
        inspect)
            parse_args "$@"
            evaluate
            ;;
        execute)
            parse_args "$@"
            evaluate || exit 1
            local args=(pr merge "$pr" --merge --match-head-commit "$verified_sha")
            if [ "$delete_branch" = yes ]; then
                args+=(--delete-branch)
            fi
            if ! "$GH_BIN" "${args[@]}"; then
                printf 'merge: result=failed\n' >&2
                exit 1
            fi
            local state
            state=$("$GH_BIN" pr view "$pr" --json state --jq .state 2>/dev/null) \
                || workflow_die "merge command succeeded but the PR state could not be read" 1
            if [ "$state" != "MERGED" ]; then
                printf 'merge: result=unverified state=%s\n' "$state" >&2
                exit 1
            fi
            printf 'merge: result=merged verified_sha=%s\n' "$verified_sha"
            ;;
        -h|--help|help) usage ;;
        *) workflow_usage_error "unknown command: $command" ;;
    esac
}

main "$@"
