#!/usr/bin/env bash
# Run repository quality gates and collect review ranges.
#
#   validate.sh full
#       Restore, format, build, test, repository-policy tests, documentation,
#       public-content checks, workflow ShellCheck, and workflow-script tests.
#       Requires a clean committed working tree.
#
#   validate.sh slice [--csharp] [--config] [--workflow] [--docs]
#       Validate a completed slice using the selected change profiles. Each
#       profile selects its required gates; public content is always included.
#       C#: format, build, test. Configuration: restore, format, build, test,
#       policy. Workflow shell: ShellCheck and workflow tests. Documentation:
#       documentation checks. Repeat or combine profiles for a mixed change.
#       An omitted profile for an obvious staged path type is rejected.
#
#   validate.sh docs
#       Documentation and public-content checks only.
#
#   validate.sh targeted [--restore] [--format] [--build] [--test]
#                        [--policy] [--docs] [--public-content] [--workflow]
#       Run only the named checks for iteration. At least one check is
#       required. This mode is not slice-completion evidence.
#
#   validate.sh checkpoint --head <sha> --tree <tree> [--commit <sha>]
#       Verify that the committed checkpoint matches the validated snapshot,
#       descends from the validated starting HEAD, and has a clean worktree.
#
#   validate.sh range --base <sha> --head <sha>
#       Refresh origin, verify both commits and their ancestry, and print the
#       review range, commit count, and diffstat.
#
# Checks run in a fixed order and are deduplicated. Tests and policy checks
# require a successful fresh build in the same run; build requires restore.
# A failed prerequisite skips its dependent checks instead of running stale
# binaries. Every result names the repository, commit, and dirty state.
# Validation fails with exit 3 if HEAD or the working tree changes while checks
# run, because the result may no longer describe the inspected commit.
#
# Exit codes: 0 passed, 1 failed or invalid state, 2 usage error, 3 concurrent
# change.
set -euo pipefail

WORKFLOW_NAME=validate
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/workflow/common.sh
source "$script_dir/common.sh"
root="$(workflow_repo_root)"

usage() {
    sed -n '2,40p' "${BASH_SOURCE[0]}"
}

failed=0
failed_checks=""
skipped_checks=""

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
    failed_checks="$failed_checks $name"
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
STATE_TREE=""

capture_state() {
    cd "$root"
    local head
    local dirty
    local status
    local tree=""
    local snapshot=""
    local diff_status
    local staged_status
    local untracked
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

    if [ "$MODE" = slice ]; then
        if ! tree=$("$GIT_BIN" write-tree 2>/dev/null); then
            workflow_die "could not read the staged snapshot" 1
        fi
        diff_status=0
        "$GIT_BIN" diff --quiet -- 2>/dev/null || diff_status=$?
        case "$diff_status" in
            0) ;;
            1)
                workflow_die \
                    "slice validation requires the worktree to match the index; stage the intended slice" 1
                ;;
            *)
                workflow_die "could not compare the worktree with the index" 1
                ;;
        esac
        if ! untracked=$("$GIT_BIN" ls-files --others --exclude-standard 2>/dev/null); then
            workflow_die "could not list non-ignored untracked files" 1
        fi
        if [ -n "$untracked" ]; then
            workflow_die \
                "slice validation requires no non-ignored untracked files; stage or remove them" 1
        fi
        staged_status=0
        "$GIT_BIN" diff --cached --quiet -- 2>/dev/null || staged_status=$?
        case "$staged_status" in
            0) snapshot=clean ;;
            1) snapshot=staged ;;
            *) workflow_die "could not read the staged snapshot" 1 ;;
        esac
    fi

    if [ "$MODE" = full ] && [ "$dirty" = yes ]; then
        workflow_die "full validation requires a clean committed working tree" 1
    fi
    STATE_HEAD=$head
    STATE_DIRTY=$dirty
    STATE_TREE=$tree
    printf 'validate: repository=%s\n' "$root"
    printf 'validate: commit=%s\n' "$head"
    printf 'validate: dirty=%s\n' "$dirty"
    printf 'validate: mode=%s\n' "$MODE"
    if [ "$MODE" = slice ]; then
        printf 'validate: index_tree=%s\n' "$tree"
        printf 'validate: snapshot=%s\n' "$snapshot"
    fi
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

slice_state_unchanged() {
    local expected_head=$1
    local expected_tree=$2
    local head
    local tree
    local diff_status
    local untracked
    if ! head=$("$GIT_BIN" rev-parse HEAD 2>/dev/null); then
        printf 'validate: could not read HEAD after the checks\n' >&2
        return 1
    fi
    if ! tree=$("$GIT_BIN" write-tree 2>/dev/null); then
        printf 'validate: could not read the staged snapshot after the checks\n' >&2
        return 1
    fi
    diff_status=0
    "$GIT_BIN" diff --quiet -- 2>/dev/null || diff_status=$?
    if [ "$diff_status" -gt 1 ]; then
        printf 'validate: could not compare the worktree with the index after the checks\n' >&2
        return 1
    fi
    if ! untracked=$("$GIT_BIN" ls-files --others --exclude-standard 2>/dev/null); then
        printf 'validate: could not list untracked files after the checks\n' >&2
        return 1
    fi
    if [ "$head" != "$expected_head" ] \
        || [ "$tree" != "$expected_tree" ] \
        || [ "$diff_status" -ne 0 ] \
        || [ -n "$untracked" ]; then
        local unstaged=no
        local untracked_state=no
        if [ "$diff_status" -ne 0 ]; then
            unstaged=yes
        fi
        if [ -n "$untracked" ]; then
            untracked_state=yes
        fi
        printf 'validate: concurrent change detected; repeat validation on the current snapshot\n' >&2
        printf 'validate: expected_commit=%s expected_tree=%s actual_commit=%s actual_tree=%s unstaged=%s untracked=%s\n' \
            "$expected_head" "$expected_tree" "$head" "$tree" "$unstaged" "$untracked_state" >&2
        return 1
    fi
    return 0
}

list_contains() {
    case " $1 " in
        *" $2 "*) return 0 ;;
        *) return 1 ;;
    esac
}

prerequisite_of() {
    case "$1" in
        format|build) printf 'restore' ;;
        test|policy) printf 'build' ;;
        *) printf '' ;;
    esac
}

run_checks() {
    cd "$root"
    capture_state
    local head=$STATE_HEAD
    local dirty=$STATE_DIRTY

    local check
    local prerequisite
    local reason
    for check in "$@"; do
        prerequisite="$(prerequisite_of "$check")"
        if [ -n "$prerequisite" ]; then
            if list_contains "$failed_checks" "$prerequisite"; then
                reason=failed
            elif list_contains "$skipped_checks" "$prerequisite"; then
                reason=skipped
            else
                reason=""
            fi
            if [ -n "$reason" ]; then
                printf 'validate: check=%s result=skipped reason=prerequisite-%s-%s\n' \
                    "$check" "$prerequisite" "$reason"
                skipped_checks="$skipped_checks $check"
                failed=1
                continue
            fi
        fi
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

    if [ "$MODE" = slice ]; then
        if ! slice_state_unchanged "$head" "$STATE_TREE"; then
            exit 3
        fi
    elif ! state_unchanged "$head" "$dirty"; then
        exit 3
    fi

    if [ "$failed" -eq 1 ]; then
        printf 'validate: result=fail\n' >&2
        exit 1
    fi
    printf 'validate: result=pass\n'
}

canonical_checks=(restore format build test policy docs public-content workflow)
selected_checks=""
required_profiles=""
ordered_checks=()

add_selected() {
    local check=$1
    if ! list_contains "$selected_checks" "$check"; then
        selected_checks="$selected_checks $check"
    fi
}

expand_prerequisites() {
    local changed=1
    while [ "$changed" -eq 1 ]; do
        changed=0
        if list_contains "$selected_checks" format \
            || list_contains "$selected_checks" build \
            || list_contains "$selected_checks" test \
            || list_contains "$selected_checks" policy; then
            if ! list_contains "$selected_checks" restore; then
                add_selected restore
                changed=1
            fi
        fi
        if list_contains "$selected_checks" test \
            || list_contains "$selected_checks" policy; then
            if ! list_contains "$selected_checks" build; then
                add_selected build
                changed=1
            fi
        fi
    done
}

order_selected() {
    ordered_checks=()
    local check
    for check in "${canonical_checks[@]}"; do
        if list_contains "$selected_checks" "$check"; then
            ordered_checks+=("$check")
        fi
    done
}

parse_targeted() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --restore) add_selected restore; shift ;;
            --format) add_selected format; shift ;;
            --build) add_selected build; shift ;;
            --test) add_selected test; shift ;;
            --policy) add_selected policy; shift ;;
            --docs) add_selected docs; shift ;;
            --public-content) add_selected public-content; shift ;;
            --workflow) add_selected workflow; shift ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done
    if [ -z "$selected_checks" ]; then
        workflow_usage_error "targeted requires at least one check flag"
    fi
    expand_prerequisites
    order_selected
}

add_required_profile() {
    local profile=$1
    if ! list_contains "$required_profiles" "$profile"; then
        required_profiles="$required_profiles $profile"
    fi
}

classify_staged_profiles() {
    local paths
    local path
    required_profiles=""
    if ! paths=$("$GIT_BIN" -C "$root" diff --cached --name-only -- 2>/dev/null); then
        workflow_die "could not read the staged paths for slice profile validation" 1
    fi
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        case "$path" in
            *.cs) add_required_profile csharp ;;
        esac
        case "$path" in
            scripts/workflow/*.sh|scripts/test-workflow.sh|scripts/check-workflow-shell.sh)
                add_required_profile workflow
                ;;
        esac
        case "$path" in
            *.md) add_required_profile docs ;;
        esac
        case "$path" in
            .github/workflows/*|*.props|*.targets|*.csproj|*.slnx|global.json|.editorconfig|\
            BannedSymbols.txt|CodeMetricsConfig.txt|NuGet.config|.config/dotnet-tools.json)
                add_required_profile config
                ;;
        esac
    done <<< "$paths"
}

parse_slice() {
    local profiles=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --csharp|--config|--workflow|--docs)
                if ! list_contains "$profiles" "${1#--}"; then
                    profiles="$profiles ${1#--}"
                fi
                shift
                ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done
    if [ -z "$profiles" ]; then
        workflow_usage_error \
            "slice requires at least one profile: --csharp, --config, --workflow, or --docs"
    fi

    classify_staged_profiles
    local missing=""
    local profile
    for profile in csharp config workflow docs; do
        if list_contains "$required_profiles" "$profile" \
            && ! list_contains "$profiles" "$profile"; then
            missing="$missing --$profile"
        fi
    done
    if [ -n "$missing" ]; then
        workflow_usage_error "staged changes require missing profile(s):$missing"
    fi

    for profile in csharp config workflow docs; do
        list_contains "$profiles" "$profile" || continue
        case "$profile" in
            csharp)
                add_selected format
                add_selected build
                add_selected test
                ;;
            config)
                add_selected restore
                add_selected format
                add_selected build
                add_selected test
                add_selected policy
                ;;
            workflow)
                add_selected workflow
                ;;
            docs)
                add_selected docs
                ;;
        esac
    done
    add_selected public-content
    expand_prerequisites
    order_selected
}

require_dotnet_for_checks() {
    local check
    for check in "$@"; do
        case "$check" in
            restore|format|build|test|policy)
                workflow_require_bin DOTNET_BIN "$DOTNET_BIN"
                return 0
                ;;
        esac
    done
}

run_checkpoint() {
    local validated_head=""
    local validated_tree=""
    local checkpoint_commit=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --head) workflow_option_value "$@"; validated_head=$2; shift 2 ;;
            --tree) workflow_option_value "$@"; validated_tree=$2; shift 2 ;;
            --commit) workflow_option_value "$@"; checkpoint_commit=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) workflow_usage_error "unknown argument: $1" ;;
        esac
    done
    workflow_require_sha "--head" "$validated_head"
    workflow_require_sha "--tree" "$validated_tree"
    if [ -n "$checkpoint_commit" ]; then
        workflow_require_sha "--commit" "$checkpoint_commit"
    fi

    cd "$root"
    workflow_require_clean_tree "$root"

    local current_commit
    if ! current_commit=$("$GIT_BIN" rev-parse HEAD 2>/dev/null); then
        workflow_die "could not read HEAD" 1
    fi
    if [ -z "$checkpoint_commit" ]; then
        checkpoint_commit=$current_commit
    fi
    if [ "$checkpoint_commit" != "$current_commit" ]; then
        workflow_die "checkpoint commit must be the current HEAD" 1
    fi
    if ! "$GIT_BIN" cat-file -e "$checkpoint_commit^{commit}" 2>/dev/null; then
        workflow_die "checkpoint commit is not available locally" 1
    fi
    if ! "$GIT_BIN" cat-file -e "$validated_head^{commit}" 2>/dev/null; then
        workflow_die "validated starting HEAD is not available locally" 1
    fi

    local commit_tree
    if ! commit_tree=$("$GIT_BIN" rev-parse "$checkpoint_commit^{tree}" 2>/dev/null); then
        workflow_die "could not read the checkpoint commit tree" 1
    fi
    if [ "$commit_tree" != "$validated_tree" ]; then
        printf 'validate: checkpoint_tree=%s validated_tree=%s\n' "$commit_tree" "$validated_tree" >&2
        workflow_die "checkpoint commit tree does not match the validated snapshot" 1
    fi
    if ! "$GIT_BIN" merge-base --is-ancestor "$validated_head" "$checkpoint_commit" 2>/dev/null; then
        workflow_die "validated starting HEAD is not an ancestor of the checkpoint commit" 1
    fi

    printf 'validate: repository=%s\n' "$root"
    printf 'validate: validated_head=%s\n' "$validated_head"
    printf 'validate: validated_tree=%s\n' "$validated_tree"
    printf 'validate: commit=%s\n' "$checkpoint_commit"
    printf 'validate: commit_tree=%s\n' "$commit_tree"
    printf 'validate: dirty=no\n'
    printf 'validate: mode=checkpoint\n'
    printf 'validate: checkpoint=verified\n'
    printf 'validate: result=pass\n'
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
            selected_checks=""
            local check
            for check in "${canonical_checks[@]}"; do
                add_selected "$check"
            done
            expand_prerequisites
            order_selected
            DOTNET_BIN="${DOTNET_BIN:-dotnet}"
            require_dotnet_for_checks "${ordered_checks[@]}"
            run_checks "${ordered_checks[@]}"
            ;;
        slice)
            MODE=slice
            DOTNET_BIN="${DOTNET_BIN:-dotnet}"
            parse_slice "$@"
            require_dotnet_for_checks "${ordered_checks[@]}"
            run_checks "${ordered_checks[@]}"
            ;;
        docs)
            [ "$#" -eq 0 ] || workflow_usage_error "docs takes no arguments"
            MODE=docs
            DOTNET_BIN="${DOTNET_BIN:-dotnet}"
            run_checks docs public-content
            ;;
        targeted)
            MODE=targeted
            DOTNET_BIN="${DOTNET_BIN:-dotnet}"
            parse_targeted "$@"
            require_dotnet_for_checks "${ordered_checks[@]}"
            run_checks "${ordered_checks[@]}"
            ;;
        checkpoint)
            MODE=checkpoint
            run_checkpoint "$@"
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
