#!/usr/bin/env bash
# Run repository quality gates and collect review ranges.
#
#   validate.sh full
#       Restore, format, build, test, repository-policy tests, documentation,
#       public-content checks, and workflow-script tests.
#
#   validate.sh docs
#       Documentation and public-content checks only.
#
#   validate.sh targeted [--restore] [--format] [--build] [--test]
#                        [--policy] [--docs] [--public-content] [--workflow]
#       Run only the named checks. At least one check is required.
#
#   validate.sh range --base <sha> --head <sha>
#       Refresh origin, verify both commits and their ancestry, and print the
#       review range, commit count, and diffstat.
#
# Every result names the repository, commit, and dirty state. Validation fails
# with exit 3 if HEAD or the working tree changes while checks run, because the
# result may no longer describe the inspected commit.
#
# Exit codes: 0 passed, 1 failed check, 2 usage error, 3 concurrent change.
set -euo pipefail

WORKFLOW_NAME=validate
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/workflow/common.sh
source "$script_dir/common.sh"
root="$(workflow_repo_root)"

usage() {
    sed -n '2,21p' "${BASH_SOURCE[0]}"
}

failed=0

run_check() {
    local name=$1
    shift
    printf 'validate: check=%s result=running\n' "$name"
    local code=0
    set +e
    ( set -e; "$@" )
    code=$?
    set -e
    if [ "$code" -eq 0 ]; then
        printf 'validate: check=%s result=pass\n' "$name"
        return 0
    fi
    printf 'validate: check=%s result=fail exit=%s\n' "$name" "$code"
    failed=1
    return 0
}

check_restore() {
    "$DOTNET_BIN" restore BaboJUPulse.slnx
}

check_format() {
    "$DOTNET_BIN" format BaboJUPulse.slnx --verify-no-changes --no-restore
}

check_build() {
    "$DOTNET_BIN" build BaboJUPulse.slnx -c Release --no-restore -warnaserror
}

check_test() {
    "$DOTNET_BIN" test BaboJUPulse.slnx -c Release --no-build --no-restore \
        -- RunConfiguration.TreatNoTestsAsError=true
}

check_policy() {
    "$DOTNET_BIN" test tests/BaboJUPulse.ArchitectureTests/BaboJUPulse.ArchitectureTests.csproj \
        -c Release --no-build --no-restore \
        --filter "Category=RepositoryPolicy" \
        -- RunConfiguration.TreatNoTestsAsError=true
}

check_docs() {
    bash scripts/test-check-documentation.sh \
        && bash scripts/check-documentation.sh
}

check_public_content() {
    bash scripts/test-public-content.sh \
        && bash scripts/check-public-content.sh --tracked
}

check_workflow() {
    workflow_require_command jq
    bash scripts/check-workflow-shell.sh
    bash scripts/test-workflow.sh
}

STATE_HEAD=""
STATE_DIRTY=""

capture_state() {
    cd "$root"
    local head
    local dirty
    local status
    if ! head=$("$GIT_BIN" rev-parse HEAD 2>/dev/null); then
        workflow_die "could not read HEAD" 1
    fi
    if ! status=$("$GIT_BIN" status --porcelain --untracked-files=all 2>/dev/null); then
        workflow_die "could not read the working tree status" 1
    fi
    if [ -n "$status" ]; then
        dirty=yes
    else
        dirty=no
    fi
    STATE_HEAD=$head
    STATE_DIRTY=$dirty
    printf 'validate: repository=%s\n' "$root"
    printf 'validate: commit=%s\n' "$head"
    printf 'validate: dirty=%s\n' "$dirty"
    printf 'validate: mode=%s\n' "$MODE"
}

state_unchanged() {
    local expected_head=$1
    local expected_dirty=$2
    local head
    local dirty
    local status
    if ! head=$("$GIT_BIN" rev-parse HEAD 2>/dev/null); then
        printf 'validate: could not read HEAD after the checks\n' >&2
        return 1
    fi
    if ! status=$("$GIT_BIN" status --porcelain --untracked-files=all 2>/dev/null); then
        printf 'validate: could not read the working tree status after the checks\n' >&2
        return 1
    fi
    if [ -n "$status" ]; then
        dirty=yes
    else
        dirty=no
    fi
    if [ "$head" != "$expected_head" ] || [ "$dirty" != "$expected_dirty" ]; then
        printf 'validate: concurrent change detected; repeat validation on the current commit\n' >&2
        printf 'validate: expected_commit=%s expected_dirty=%s actual_commit=%s actual_dirty=%s\n' \
            "$expected_head" "$expected_dirty" "$head" "$dirty" >&2
        return 1
    fi
    return 0
}

run_checks() {
    cd "$root"
    capture_state
    local head=$STATE_HEAD
    local dirty=$STATE_DIRTY

    local check
    for check in "$@"; do
        case "$check" in
            restore) run_check restore check_restore ;;
            format) run_check format check_format ;;
            build) run_check build check_build ;;
            test) run_check test check_test ;;
            policy) run_check policy check_policy ;;
            docs) run_check docs check_docs ;;
            public-content) run_check public-content check_public_content ;;
            workflow) run_check workflow check_workflow ;;
            *) workflow_usage_error "unknown check: $check" ;;
        esac
    done

    if ! state_unchanged "$head" "$dirty"; then
        exit 3
    fi

    if [ "$failed" -eq 1 ]; then
        printf 'validate: result=fail\n' >&2
        exit 1
    fi
    printf 'validate: result=pass\n'
}

all_checks=(restore format build test policy docs public-content workflow)

selected=()

parse_targeted() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --restore) selected+=(restore); shift ;;
            --format) selected+=(format); shift ;;
            --build) selected+=(build); shift ;;
            --test) selected+=(test); shift ;;
            --policy) selected+=(policy); shift ;;
            --docs) selected+=(docs); shift ;;
            --public-content) selected+=(public-content); shift ;;
            --workflow) selected+=(workflow); shift ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done
    if [ "${#selected[@]}" -eq 0 ]; then
        workflow_usage_error "targeted requires at least one check flag"
    fi
}

run_range() {
    local base=""
    local head=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --base) workflow_option_value "$@"; base=$2; shift 2 ;;
            --head) workflow_option_value "$@"; head=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done
    workflow_require_sha "--base" "$base"
    workflow_require_sha "--head" "$head"

    cd "$root"
    if "$GIT_BIN" remote get-url origin >/dev/null 2>&1; then
        "$GIT_BIN" fetch origin --prune >/dev/null 2>&1 \
            || workflow_die "could not refresh origin" 1
    fi

    "$GIT_BIN" cat-file -e "$base^{commit}" 2>/dev/null \
        || workflow_die "base commit is not available locally" 1
    "$GIT_BIN" cat-file -e "$head^{commit}" 2>/dev/null \
        || workflow_die "head commit is not available locally" 1
    "$GIT_BIN" merge-base --is-ancestor "$base" "$head" \
        || workflow_die "base is not an ancestor of head" 1

    local commits
    local base_sha
    local head_sha
    local current_commit
    commits=$("$GIT_BIN" rev-list --count "$base..$head")
    base_sha=$("$GIT_BIN" rev-parse "$base^{commit}")
    head_sha=$("$GIT_BIN" rev-parse "$head^{commit}")
    current_commit=$("$GIT_BIN" rev-parse HEAD)
    printf 'validate: repository=%s\n' "$root"
    printf 'validate: base_sha=%s\n' "$base_sha"
    printf 'validate: head_sha=%s\n' "$head_sha"
    printf 'validate: commits=%s\n' "$commits"
    printf 'validate: current_commit=%s\n' "$current_commit"
    printf 'validate: diffstat_begin\n'
    "$GIT_BIN" diff --stat "$base...$head"
    printf 'validate: diffstat_end\n'
    printf 'validate: result=pass\n'
}

main() {
    [ "$#" -gt 0 ] || { usage; exit 2; }
    local command=$1
    shift
    case "$command" in
        full)
            [ "$#" -eq 0 ] || workflow_usage_error "full takes no arguments"
            MODE=full
            DOTNET_BIN="${DOTNET_BIN:-dotnet}"
            workflow_require_bin DOTNET_BIN "$DOTNET_BIN"
            run_checks "${all_checks[@]}"
            ;;
        docs)
            [ "$#" -eq 0 ] || workflow_usage_error "docs takes no arguments"
            MODE=docs
            DOTNET_BIN="${DOTNET_BIN:-dotnet}"
            run_checks docs public-content
            ;;
        targeted)
            MODE=targeted
            parse_targeted "$@"
            DOTNET_BIN="${DOTNET_BIN:-dotnet}"
            local check
            for check in "${selected[@]}"; do
                case "$check" in
                    restore|format|build|test|policy)
                        workflow_require_bin DOTNET_BIN "$DOTNET_BIN"
                        ;;
                esac
            done
            run_checks "${selected[@]}"
            ;;
        range)
            MODE=range
            run_range "$@"
            ;;
        -h|--help|help) usage ;;
        *) workflow_usage_error "unknown command: $command" ;;
    esac
}

main "$@"
