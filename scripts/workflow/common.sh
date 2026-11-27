#!/usr/bin/env bash
# Shared helpers for the workflow entry points.
#
# This file is sourced, not executed. It keeps repository discovery, argument
# validation, SHA validation, worktree inspection, repository identity, and
# Paseo workspace lookup in one place so the entry points cannot drift apart.
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
    if ! status=$("$GIT_BIN" -C "$root" status --porcelain --untracked-files=all 2>/dev/null); then
        workflow_die "could not read the working tree status" 1
    fi
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
    if [ -n "$expected" ]; then
        actual=$("$GH_BIN" repo view "$expected" --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
            || workflow_die "could not determine the GitHub repository" 1
    else
        actual=$("$GH_BIN" repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
            || workflow_die "could not determine the GitHub repository" 1
    fi
    if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
        workflow_die "repository mismatch: expected $expected, found $actual" 1
    fi
    printf '%s' "$actual"
}

workflow_git_common_dir() {
    local path=$1
    local common
    common=$("$GIT_BIN" -C "$path" rev-parse --git-common-dir 2>/dev/null) \
        || return 1
    if [ -z "$common" ]; then
        return 1
    fi
    case "$common" in
        /*|[A-Za-z]:/*) ;;
        *) common="$path/$common" ;;
    esac
    if [ -d "$common" ]; then
        (cd "$common" && pwd -P)
    else
        printf '%s' "$common"
    fi
}

workflow_repository_from_url() {
    local url=${1:-}
    local rest owner repo
    case "$url" in
        *://*)
            rest=${url#*://}
            rest=${rest##*@}
            case "$rest" in
                github.com:*)
                    rest=${rest#github.com:}
                    case "$rest" in
                        [0-9]*/*) rest=${rest#*/} ;;
                    esac
                    ;;
                github.com/*) rest=${rest#github.com/} ;;
                *) return 1 ;;
            esac
            ;;
        git@github.com:*) rest=${url#git@github.com:} ;;
        github.com/*) rest=${url#github.com/} ;;
        *) return 1 ;;
    esac
    rest=${rest%%\?*}
    rest=${rest%%#*}
    rest=${rest%/}
    rest=${rest%.git}
    case "$rest" in
        ''|/*|*/|*/*/*) return 1 ;;
        */*) ;;
        *) return 1 ;;
    esac
    owner=${rest%%/*}
    repo=${rest#*/}
    case "$owner" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; esac
    case "$repo" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; esac
    printf '%s/%s' "$owner" "$repo"
}

workflow_remote_urls() {
    local root=$1
    local remote=$2
    local kind=${3:-fetch}
    local output
    case "$kind" in
        fetch)
            if ! output=$("$GIT_BIN" -C "$root" remote get-url --all "$remote" 2>/dev/null); then
                return 2
            fi
            ;;
        push)
            if ! output=$("$GIT_BIN" -C "$root" remote get-url --push --all "$remote" 2>/dev/null); then
                return 2
            fi
            ;;
        *) return 2 ;;
    esac
    if [ -z "$output" ]; then
        return 2
    fi
    printf '%s\n' "$output"
}

workflow_verify_repository_identity() {
    local root=$1
    local expected=${2:-}
    local repository=""
    local kind url candidate urls
    for kind in fetch push; do
        if ! urls="$(workflow_remote_urls "$root" origin "$kind")"; then
            workflow_die "could not read the origin $kind destination" 1
        fi
        while IFS= read -r url; do
            [ -n "$url" ] || continue
            if ! candidate="$(workflow_repository_from_url "$url")"; then
                workflow_die "cannot establish the GitHub repository from the origin $kind URL" 1
            fi
            if [ -z "$repository" ]; then
                repository=$candidate
            elif [ "$repository" != "$candidate" ]; then
                workflow_die "origin fetch and push destinations do not identify the same repository" 1
            fi
        done <<< "$urls"
    done
    if [ -z "$repository" ]; then
        workflow_die "cannot establish the origin repository" 1
    fi
    local actual
    actual=$("$GH_BIN" repo view "$repository" --json nameWithOwner --jq .nameWithOwner 2>/dev/null) \
        || workflow_die "could not verify the GitHub repository $repository" 1
    if [ "$actual" != "$repository" ]; then
        workflow_die "repository identity mismatch: origin=$repository github=$actual" 1
    fi
    if [ -n "$expected" ] && [ "$expected" != "$actual" ]; then
        workflow_die "repository mismatch: expected $expected, found $actual" 1
    fi
    printf '%s' "$actual"
}

workflow_worktree_records() {
    local root=$1
    local listing
    if ! listing=$("$GIT_BIN" -C "$root" worktree list --porcelain 2>/dev/null); then
        return 2
    fi
    printf '%s\n' "$listing" | awk '
        function emit() {
            if (path != "") {
                print path "\037" branch
            }
            path = ""
            branch = ""
        }
        /^worktree / { emit(); path = substr($0, 10); next }
        /^branch / {
            branch = substr($0, 8)
            sub(/^refs\/heads\//, "", branch)
            next
        }
        /^detached$/ { branch = ""; next }
        /^$/ { emit() }
        END { emit() }
    '
}

workflow_worktree_for_branch() {
    local branch=$1
    local records path registered_branch
    if ! records="$(workflow_worktree_records "$PWD")"; then
        return 2
    fi
    while IFS=$'\x1f' read -r path registered_branch; do
        [ -n "$path" ] || continue
        if [ "$registered_branch" = "$branch" ]; then
            printf '%s' "$path"
            return 0
        fi
    done <<< "$records"
    return 0
}

workflow_worktree_branch_registered() {
    local root=$1
    local wanted=$2
    local records path registered_branch
    if ! records="$(workflow_worktree_records "$root")"; then
        return 2
    fi
    while IFS=$'\x1f' read -r path registered_branch; do
        [ -n "$path" ] || continue
        if [ "$path" = "$wanted" ]; then
            printf '%s' "$registered_branch"
            return 0
        fi
    done <<< "$records"
    return 0
}

workflow_main_worktree() {
    local records path branch
    if ! records="$(workflow_worktree_records "$PWD")"; then
        return 2
    fi
    while IFS=$'\x1f' read -r path branch; do
        [ -n "$path" ] || continue
        if [ "$branch" = "main" ]; then
            printf '%s' "$path"
            return 0
        fi
    done <<< "$records"
    return 0
}

workflow_worktree_registered() {
    local root=$1
    local wanted=$2
    local records path branch
    if ! records="$(workflow_worktree_records "$root")"; then
        return 2
    fi
    while IFS=$'\x1f' read -r path branch; do
        [ -n "$path" ] || continue
        if [ "$path" = "$wanted" ]; then
            return 0
        fi
    done <<< "$records"
    return 1
}

workflow_branch_exists() {
    local root=$1
    local branch=$2
    local status=0
    "$GIT_BIN" -C "$root" show-ref --verify --quiet "refs/heads/$branch" || status=$?
    case "$status" in
        0) return 0 ;;
        1) return 1 ;;
        *) return 2 ;;
    esac
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

workflow_expand_path() {
    local path=${1:-}
    if [ "$path" = '~' ]; then
        path=$HOME
    elif [ "${path#\~/}" != "$path" ]; then
        path="$HOME/${path#\~/}"
    fi
    case "$path" in
        [A-Za-z]:\\*) path=${path//\\//} ;;
    esac
    case "$path" in
        /*|[A-Za-z]:/*) ;;
        *) path="$PWD/$path" ;;
    esac
    case "$path" in
        [A-Za-z]:/) ;;
        *)
            while [ "${#path}" -gt 1 ] && [ "$path" != "/" ]; do
                case "$path" in
                    */) path=${path%/} ;;
                    *) break ;;
                esac
            done
            ;;
    esac
    printf '%s' "$path"
}

workflow_normalize_path() {
    local path
    path="$(workflow_expand_path "$1")"
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
        *.binlog) return 0 ;;
        *) return 1 ;;
    esac
}

workflow_reproducible_output_file() {
    local relative=$1
    local name=${relative##*/}
    case "$relative" in
        bin/*)
            case "$name" in
                *.dll|*.exe|*.pdb|*.mdb|*.obj|*.o|*.a|*.so|*.dylib|*.lib|*.exp|*.ilk|*.cache|*.deps.json|*.runtimeconfig.json)
                    return 0
                    ;;
            esac
            ;;
        obj/*)
            case "$name" in
                *.dll|*.pdb|*.mdb|*.obj|*.o|*.a|*.so|*.dylib|*.lib|*.exp|*.ilk|*.cache|*.deps.json|*.runtimeconfig.json)
                    return 0
                    ;;
                *.AssemblyInfo.cs|*.AssemblyAttributes.cs|*.GlobalUsings.g.cs|*.g.cs)
                    return 0
                    ;;
                *.nuget.g.props|*.nuget.g.targets|*.nuget.dgspec.json|project.assets.json)
                    return 0
                    ;;
                *.GeneratedMSBuildEditorConfig.editorconfig|*.FileListAbsolute.txt|*.Up2Date|*.binlog)
                    return 0
                    ;;
            esac
            ;;
        TestResults/*)
            case "$name" in
                *.trx|*.coverage|*.coveragexml)
                    return 0
                    ;;
            esac
            ;;
        *.binlog)
            case "$relative" in
                */*) ;;
                *) return 0 ;;
            esac
            ;;
    esac
    return 1
}

workflow_reproducible_output_entry() {
    local base=$1
    local target=$2
    local relative=${target#"$base"/}
    if [ -L "$target" ]; then
        return 1
    fi
    if [ -f "$target" ]; then
        workflow_reproducible_output_file "$relative"
        return
    fi
    if [ ! -d "$target" ]; then
        return 1
    fi
    local child
    for child in "$target"/* "$target"/.[!.]* "$target"/..?*; do
        [ -e "$child" ] || [ -L "$child" ] || continue
        if ! workflow_reproducible_output_entry "$base" "$child"; then
            return 1
        fi
    done
    return 0
}

workflow_worktree_status() {
    local path=$1
    local allow_output=${2:-no}
    local tracked
    local ignored
    local line
    local entry
    local target
    if [ ! -d "$path" ]; then
        return 1
    fi
    if ! tracked=$("$GIT_BIN" -C "$path" status --porcelain --untracked-files=all 2>/dev/null); then
        return 2
    fi
    if [ -n "$tracked" ]; then
        return 1
    fi
    if ! ignored=$("$GIT_BIN" -C "$path" status --ignored --short --untracked-files=all 2>/dev/null); then
        return 2
    fi
    if [ -z "$ignored" ]; then
        return 0
    fi
    if [ "$allow_output" != "yes" ]; then
        return 1
    fi
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        entry=${line#?? }
        entry=${entry%/}
        if ! workflow_reproducible_output "$entry"; then
            return 1
        fi
        target="$path/$entry"
        if [ "$target" = "$path" ] || ! workflow_path_is_within "$path" "$target"; then
            return 1
        fi
        if ! workflow_reproducible_output_entry "$path" "$target"; then
            return 1
        fi
    done <<< "$ignored"
    return 0
}

workflow_remove_reproducible_output() {
    local path=$1
    local ignored
    local line
    local entry
    local target
    if ! ignored=$("$GIT_BIN" -C "$path" status --ignored --short --untracked-files=all 2>/dev/null); then
        return 2
    fi
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        entry=${line#?? }
        entry=${entry%/}
        workflow_reproducible_output "$entry" || continue
        target="$path/$entry"
        if [ "$target" = "$path" ] || ! workflow_path_is_within "$path" "$target"; then
            continue
        fi
        if ! workflow_reproducible_output_entry "$path" "$target"; then
            continue
        fi
        rm -rf -- "$target"
    done <<< "$ignored"
    return 0
}

workflow_paseo_workspaces_json() {
    local output
    if ! output=$("$PASEO_BIN" workspace ls --json 2>/dev/null); then
        return 2
    fi
    printf '%s' "$output"
}

workflow_paseo_json_records() {
    local json=$1
    local filter=$2
    local output
    if ! command -v jq >/dev/null 2>&1; then
        printf '%s: required command is unavailable: jq\n' "${WORKFLOW_NAME:-workflow}" >&2
        return 2
    fi
    if ! output=$(printf '%s' "$json" | jq -s -r "$filter" 2>/dev/null); then
        return 2
    fi
    printf '%s' "$output"
}

workflow_paseo_workspaces() {
    local output
    if ! output="$(workflow_paseo_workspaces_json)"; then
        return 2
    fi
    workflow_paseo_json_records "$output" '
        def safe_string:
            if type == "string"
            then (explode | any(. < 32 or . == 127) | not)
            else false
            end;
        def safe_nonempty: safe_string and ((length) > 0);
        if length != 1 then error("expected exactly one JSON value") else .[0] end
        | if type != "array" then error("expected a JSON array") else . end
        | if ([.[].workspaceId] | length) != ([.[].workspaceId] | unique | length)
            then error("duplicate workspace identity") else . end
        | if ([.[].cwd] | length) != ([.[].cwd] | unique | length)
            then error("duplicate workspace cwd") else . end
        | .[]
        | if ((.workspaceId | safe_nonempty) and (.cwd | safe_nonempty))
            then [.workspaceId, .cwd] | join("\u001f")
            else error("invalid workspace record")
            end
    '
}

workflow_paseo_workspace_record() {
    local id=$1
    local records
    local status=0
    local record_id record_cwd
    records="$(workflow_paseo_workspaces)" || status=$?
    if [ "$status" -ne 0 ]; then
        return "$status"
    fi
    while IFS=$'\x1f' read -r record_id record_cwd; do
        [ -n "$record_id" ] || continue
        if [ "$record_id" = "$id" ]; then
            printf '%s\x1f%s' "$record_id" "$record_cwd"
            return 0
        fi
    done <<< "$records"
    return 1
}

workflow_paseo_workspace_id_for_cwd() {
    local wanted=$1
    local records
    local status=0
    local record_id record_cwd
    local normalized
    local matches=0
    local matched_id=""
    records="$(workflow_paseo_workspaces)" || status=$?
    if [ "$status" -ne 0 ]; then
        return "$status"
    fi
    while IFS=$'\x1f' read -r record_id record_cwd; do
        [ -n "$record_id" ] || continue
        normalized="$(workflow_normalize_path "$record_cwd")"
        if [ "$normalized" = "$wanted" ]; then
            matches=$((matches + 1))
            matched_id=$record_id
        fi
    done <<< "$records"
    case "$matches" in
        0) return 0 ;;
        1) printf '%s' "$matched_id"; return 0 ;;
        *) return 3 ;;
    esac
}

workflow_paseo_workspace_exists() {
    local id=$1
    local status=0
    workflow_paseo_workspace_record "$id" >/dev/null || status=$?
    return "$status"
}

workflow_paseo_agents_json() {
    local output
    if ! output=$("$PASEO_BIN" ls --json --all --background 2>/dev/null); then
        return 2
    fi
    printf '%s' "$output"
}

workflow_paseo_agents() {
    local output
    if ! output="$(workflow_paseo_agents_json)"; then
        return 2
    fi
    workflow_paseo_json_records "$output" '
        def safe_string:
            if type == "string"
            then (explode | any(. < 32 or . == 127) | not)
            else false
            end;
        def safe_nonempty: safe_string and ((length) > 0);
        if length != 1 then error("expected exactly one JSON value") else .[0] end
        | if type != "array" then error("expected a JSON array") else . end
        | if ([.[].id] | length) != ([.[].id] | unique | length)
            then error("duplicate agent identity") else . end
        | .[]
        | if ((.id | safe_nonempty)
              and (.status | safe_string)
              and (.cwd | safe_string)
              and (.workspaceId | safe_string))
            then [.id, .status, .cwd, .workspaceId] | join("\u001f")
            else error("invalid agent record")
            end
    '
}

workflow_path_is_within() {
    local parent=$1
    local child=$2
    case "$child/" in
        "$parent"/*) return 0 ;;
        *) return 1 ;;
    esac
}
