#!/usr/bin/env bash
# Synthetic cases for the workflow entry points. Uses temporary Git repositories
# and stubbed GitHub/Paseo commands. It never contacts GitHub or Paseo and never
# uses private data. Git URL lookups are stubbed to keep the transports local; a
# separate case exercises real `git remote get-url` rewrite behavior.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d)"
output="$(mktemp)"
trap 'rm -rf "$fixture"; rm -f "$output"' EXIT

if ! command -v jq >/dev/null 2>&1; then
    printf 'test-workflow: required command is unavailable: jq\n' >&2
    exit 2
fi
if ! real_git="$(command -v git)"; then
    printf 'test-workflow: required command is unavailable: git\n' >&2
    exit 2
fi

passed=0
failed=0
status=0

fail() {
    echo "FAIL: $1" >&2
    failed=$((failed + 1))
}

ok() {
    passed=$((passed + 1))
}

assert_exit() {
    local expected=$1
    local label=$2
    if [ "$status" -eq "$expected" ]; then
        ok
    else
        fail "$label: expected exit $expected, got $status"
    fi
}

assert_equals() {
    local expected=$1
    local actual=$2
    local label=$3
    if [ "$actual" = "$expected" ]; then
        ok
    else
        fail "$label: expected '$expected', got '$actual'"
    fi
}

assert_contains() {
    local expected=$1
    local label=$2
    if grep -Fq -- "$expected" "$output"; then
        ok
    else
        fail "$label: output did not contain '$expected'"
        sed -n '1,40p' "$output" >&2
    fi
}

assert_not_contains() {
    local unexpected=$1
    local label=$2
    if grep -Fq -- "$unexpected" "$output"; then
        fail "$label: output unexpectedly contained '$unexpected'"
    else
        ok
    fi
}

assert_path_exists() {
    local path=$1
    local label=$2
    if [ -e "$path" ]; then
        ok
    else
        fail "$label: expected path to remain: $path"
    fi
}

assert_path_missing() {
    local path=$1
    local label=$2
    if [ ! -e "$path" ]; then
        ok
    else
        fail "$label: expected path to be absent: $path"
    fi
}

assert_no_archive() {
    local label=$1
    if [ ! -f "$paseo_archived" ] && [ ! -s "$paseo_log" ]; then
        ok
    else
        fail "$label: a Paseo workspace was archived"
    fi
}

assert_remote_branch_present() {
    local repo=$1
    local branch=$2
    local label=$3
    local refs
    refs=$(git -C "$repo" ls-remote --heads origin "$branch")
    if [ -n "$refs" ]; then
        ok
    else
        fail "$label: expected remote branch to remain: $branch"
    fi
}

assert_remote_branch_absent() {
    local repo=$1
    local branch=$2
    local label=$3
    local refs
    refs=$(git -C "$repo" ls-remote --heads origin "$branch")
    if [ -z "$refs" ]; then
        ok
    else
        fail "$label: expected remote branch to be absent: $branch"
    fi
}

assert_branch_present() {
    local repo=$1
    local branch=$2
    local label=$3
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        ok
    else
        fail "$label: expected local branch to remain: $branch"
    fi
}

assert_branch_absent() {
    local repo=$1
    local branch=$2
    local label=$3
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        fail "$label: expected local branch to be absent: $branch"
    else
        ok
    fi
}

assert_head_equals() {
    local repo=$1
    local expected=$2
    local label=$3
    local actual
    actual=$(git -C "$repo" rev-parse HEAD)
    assert_equals "$expected" "$actual" "$label"
}

assert_main_synchronized() {
    local repo=$1
    local label=$2
    local head
    local origin
    head=$(git -C "$repo" rev-parse HEAD)
    origin=$(git -C "$repo" rev-parse origin/main)
    assert_equals "$origin" "$head" "$label"
}

run_at() {
    local directory=$1
    shift
    set +e
    (cd "$directory" && bash "$@") >"$output" 2>&1
    status=$?
    set -e
}

bin="$fixture/bin"
mkdir -p "$bin"
gh_stub="$bin/gh"
paseo_stub="$bin/paseo"
git_stub="$bin/git-workflow"
gh_log="$fixture/gh.log"
paseo_log="$fixture/paseo.log"
paseo_archived="$fixture/paseo.archived"
: > "$gh_log"
: > "$paseo_log"
export STUB_REPOSITORY="owner/repo"
export REAL_GIT="$real_git"

write_stubs() {
    cat > "$gh_stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    "repo view"*)
        if [ "${STUB_GH_FAIL:-0}" = "1" ]; then
            exit 1
        fi
        printf '%s\n' "${STUB_REPOSITORY:-owner/repo}"
        ;;
    "issue view"*"number,state,title,url,labels"*)
        printf '%b\n' "${STUB_ISSUE_RECORD:-1\x1fOPEN\x1fTest issue\x1fhttps://example.test/issues/1\x1fready-for-agent}"
        ;;
    "issue view"*"json state"*)
        printf '%s\n' "${STUB_ISSUE_STATE:-OPEN}"
        ;;
    "pr view"*"json state"*)
        printf '%s\n' "${STUB_PR_STATE:-MERGED}"
        ;;
    "pr view"*)
        printf '%s\n' "$STUB_PR_RECORD"
        ;;
    "pr checks"*)
        printf '%b' "${STUB_CHECKS:-build\x1fSUCCESS\x1fpass\n}"
        exit "${STUB_CHECKS_EXIT:-0}"
        ;;
    "pr merge"*)
        printf '%s\n' "$*" >> "${STUB_GH_LOG:-/dev/null}"
        printf 'merged\n'
        ;;
    *)
        printf 'unexpected gh invocation: %s\n' "$*" >&2
        exit 1
        ;;
esac
STUB
    chmod +x "$gh_stub"

    cat > "$paseo_stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    "workspace ls --json")
        if [ "${STUB_PASEO_FAIL:-0}" = "1" ]; then
            exit 1
        fi
        if [ -f "${STUB_PASEO_ARCHIVED:-/nonexistent}" ]; then
            printf '[]\n'
        else
            printf '%s\n' "${STUB_PASEO_JSON:-[]}"
        fi
        ;;
    "workspace archive"*)
        printf '%s\n' "$*" >> "${STUB_PASEO_LOG:-/dev/null}"
        : > "${STUB_PASEO_ARCHIVED:-/dev/null}"
        ;;
    "ls --json --all --background")
        if [ "${STUB_PASEO_AGENTS_FAIL:-0}" = "1" ]; then
            exit 1
        fi
        printf '%s\n' "${STUB_PASEO_AGENTS_JSON:-[]}"
        ;;
    *)
        printf 'unexpected paseo invocation: %s\n' "$*" >&2
        exit 1
        ;;
esac
STUB
    chmod +x "$paseo_stub"

    cat > "$git_stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
real_git=${REAL_GIT:?}
if [[ " $* " == *" remote get-url "* ]]; then
    repo=$PWD
    previous=""
    for arg in "$@"; do
        if [ "$previous" = "-C" ]; then
            repo=$arg
            break
        fi
        previous=$arg
    done
    if [[ " $* " == *" --push "* ]]; then
        if output=$("$real_git" -C "$repo" config --get-all remote.origin.pushurl 2>/dev/null); then
            printf '%s\n' "$output"
            exit 0
        fi
    fi
    exec "$real_git" -C "$repo" config --get-all remote.origin.url
fi
if [ "${STUB_GIT_FAIL_WORKTREE:-0}" = "1" ] && [[ " $* " == *" worktree list "* ]]; then
    exit 1
fi
if [ -n "${STUB_GIT_FAIL_STATUS:-}" ] && [[ " $* " == *" status "* ]]; then
    if [[ " $* " == *"${STUB_GIT_FAIL_STATUS_PATH:-}"* ]]; then
        if [ "$STUB_GIT_FAIL_STATUS" = "tracked" ] && [[ " $* " == *"--porcelain"* ]]; then
            exit 1
        fi
        if [ "$STUB_GIT_FAIL_STATUS" = "ignored" ] && [[ " $* " == *"--ignored"* ]]; then
            exit 1
        fi
    fi
fi
if [ -n "${STUB_RACE_ORIGIN:-}" ] && [[ " $* " == *"--force-with-lease"* && " $* " == *"--delete"* ]]; then
    "$real_git" -C "$STUB_RACE_ORIGIN" update-ref "$STUB_RACE_REF" "$STUB_RACE_SHA"
fi
exec "$real_git" "$@"
STUB
    chmod +x "$git_stub"
}
write_stubs

export GH_BIN="$gh_stub"
export PASEO_BIN="$paseo_stub"
export GIT_BIN="$git_stub"
export STUB_GH_LOG="$gh_log"
export STUB_PASEO_LOG="$paseo_log"
export STUB_PASEO_ARCHIVED="$paseo_archived"

configure_repo() {
    local repo=$1
    git -C "$repo" config user.name "Workflow Test"
    git -C "$repo" config user.email "workflow@example.test"
    git -C "$repo" config commit.gpgsign false
    git -C "$repo" config core.hooksPath /dev/null
}

make_repository() {
    local base=$1
    mkdir -p "$base"
    git init --bare -q "$base/origin.git"
    git init -q "$base/seed"
    git -C "$base/seed" checkout -q -b main
    configure_repo "$base/seed"
    printf 'base\n' > "$base/seed/file.txt"
    git -C "$base/seed" add file.txt
    git -C "$base/seed" commit -q -m "chore: base"
    git -C "$base/seed" remote add origin "https://github.com/${STUB_REPOSITORY}.git"
    git -C "$base/seed" config "url.$base/origin.git.insteadOf" "https://github.com/${STUB_REPOSITORY}.git"
    git -C "$base/seed" push -q -u origin main
}

make_branch_issue() {
    local base=$1
    local branch=$2
    local content=$3
    local seed="$base/seed"
    local head
    make_repository "$base"
    git -C "$seed" checkout -q -b "$branch"
    printf '%s\n' "$content" >> "$seed/file.txt"
    git -C "$seed" commit -q -am "feat: $branch"
    git -C "$seed" push -q -u origin "$branch"
    head=$(git -C "$seed" rev-parse HEAD)
    git -C "$seed" checkout -q main
    printf '%s\x1f%s\n' "$seed" "$head"
}

make_merged_issue() {
    local base=$1
    local branch=$2
    local content=$3
    local add_worktree=${4:-yes}
    local worktree_name=${5:-worktree}
    local seed="$base/seed"
    local head
    local merge
    local worktree=""
    make_repository "$base"
    git -C "$seed" checkout -q -b "$branch"
    printf '%s\n' "$content" >> "$seed/file.txt"
    git -C "$seed" commit -q -am "feat: $branch"
    git -C "$seed" push -q -u origin "$branch"
    head=$(git -C "$seed" rev-parse HEAD)
    git -C "$seed" checkout -q main
    git -C "$seed" merge -q --no-ff "$branch" -m "Merge $branch"
    git -C "$seed" push -q origin main
    merge=$(git -C "$seed" rev-parse HEAD)
    git -C "$seed" reset -q --hard HEAD^1
    if [ "$add_worktree" = yes ]; then
        worktree="$base/$worktree_name"
        git -C "$seed" worktree add -q "$worktree" "$branch"
    fi
    printf '%s\x1f%s\x1f%s\x1f%s\n' "$seed" "$head" "$merge" "$worktree"
}

pr_record() {
    local number=$1
    local state=$2
    local merged_at=$3
    local merge_sha=$4
    local branch=$5
    local head=$6
    local owner=${7-owner}
    local repo=${8-repo}
    local base=${9:-main}
    local url=${10:-https://example.test/pull/$number}
    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s' \
        "$number" "$state" "$merged_at" "$merge_sha" "$branch" "$head" \
        "$owner" "$repo" "$base" "$url"
}

set_merged_pr() {
    local number=$1
    local head=$2
    local merge=$3
    local branch=$4
    local owner=${5-owner}
    local repo=${6-repo}
    STUB_PR_RECORD="$(pr_record "$number" MERGED "2026-01-01T00:00:00Z" \
        "$merge" "$branch" "$head" "$owner" "$repo" main \
        "https://example.test/pull/$number")"
    export STUB_PR_RECORD
}

paseo_workspace_record() {
    printf '{"workspaceId":"%s","cwd":"%s"}' "$1" "$2"
}

paseo_workspace_json() {
    local record
    record=$(paseo_workspace_record "$1" "$2")
    printf '[%s]' "$record"
}

set_paseo_workspace() {
    STUB_PASEO_JSON="$(paseo_workspace_json "$1" "$2")"
    export STUB_PASEO_JSON
}

set_paseo_json() {
    STUB_PASEO_JSON=$1
    export STUB_PASEO_JSON
}

paseo_agent_json() {
    local id=$1
    local name=$2
    local agent_status=$3
    local cwd=$4
    local workspace=$5
    printf '{"id":"%s","name":"%s","status":"%s","cwd":"%s","workspaceId":"%s"}' \
        "$id" "$name" "$agent_status" "$cwd" "$workspace"
}

set_paseo_agents() {
    STUB_PASEO_AGENTS_JSON=$1
    export STUB_PASEO_AGENTS_JSON
}

# --- Workspace fixture: unmerged branch based on origin/main -----------------

workspace_fixture="$fixture/workspace"
fixture_output=$(make_branch_issue "$workspace_fixture" chore/workspace-test "work")
IFS=$'\x1f' read -r workspace_seed _ <<< "$fixture_output"
workspace_base=$(git -C "$workspace_seed" rev-parse origin/main)
workspace_worktree="$workspace_fixture/worktree"
git -C "$workspace_seed" worktree add -q "$workspace_worktree" chore/workspace-test

export STUB_REPOSITORY="owner/repo"
export STUB_ISSUE_RECORD=$'1\x1fOPEN\x1fTest issue\x1fhttps://example.test/issues/1\x1fready-for-agent'
export STUB_ISSUE_STATE="OPEN"

run_at "$workspace_seed" "$root/scripts/workflow/workspace.sh" prepare \
    --issue 1 --branch chore/workspace-test
assert_exit 0 "workspace prepare existing"
assert_contains "workspace: action=reuse" "workspace prepare existing"
assert_contains "workspace: base_sha=$workspace_base" "workspace prepare existing"
assert_contains "workspace: worktree_clean=yes" "workspace prepare existing"

run_at "$workspace_worktree" "$root/scripts/workflow/workspace.sh" verify \
    --issue 1 --branch chore/workspace-test --base "$workspace_base"
assert_exit 0 "workspace verify"
assert_contains "workspace: verified=yes" "workspace verify"
workspace_worktree_head=$(git -C "$workspace_worktree" rev-parse HEAD)
assert_contains "workspace: head_sha=$workspace_worktree_head" "workspace verify"

printf 'dirty\n' > "$workspace_worktree/untracked.txt"
run_at "$workspace_worktree" "$root/scripts/workflow/workspace.sh" verify \
    --issue 1 --branch chore/workspace-test --base "$workspace_base"
assert_exit 1 "workspace verify dirty"
rm -f "$workspace_worktree/untracked.txt"

export STUB_ISSUE_RECORD=$'1\x1fOPEN\x1fTest issue\x1fhttps://example.test/issues/1\x1fneeds-triage'
run_at "$workspace_seed" "$root/scripts/workflow/workspace.sh" prepare \
    --issue 1 --branch chore/new-branch
assert_exit 1 "workspace prepare unready"
export STUB_ISSUE_RECORD=$'1\x1fOPEN\x1fTest issue\x1fhttps://example.test/issues/1\x1fready-for-agent'

run_at "$workspace_seed" "$root/scripts/workflow/workspace.sh" prepare \
    --issue 1 --branch chore/new-branch
assert_exit 0 "workspace prepare create"
assert_contains "workspace: action=create" "workspace prepare create"
assert_contains "workspace: mode=branch-off" "workspace prepare create"
assert_contains "workspace: base_sha=$workspace_base" "workspace prepare create"

run_at "$workspace_seed" "$root/scripts/workflow/workspace.sh" prepare \
    --issue 1 --branch "not-a-branch"
assert_exit 2 "workspace prepare invalid branch"

run_at "$workspace_seed" "$root/scripts/workflow/workspace.sh" prepare --issue
assert_exit 2 "workspace prepare missing value"

# --- Effective remote URLs (real Git rewrites) ------------------------------

remote_fixture="$fixture/remote-urls"
remote_repo="$remote_fixture/repo"
mkdir -p "$remote_repo"
git init -q "$remote_repo"
configure_repo "$remote_repo"
git -C "$remote_repo" config remote.origin.url "https://github.com/owner/repo.git"
git -C "$remote_repo" config "url.git@github.com:owner/repo.git.insteadOf" \
    "https://github.com/owner/repo.git"

fetch_url=$(GIT_BIN="$real_git" bash -c \
    'source "$1/scripts/workflow/common.sh"; workflow_remote_urls "$2" origin fetch' \
    _ "$root" "$remote_repo")
assert_equals "git@github.com:owner/repo.git" "$fetch_url" "effective fetch URL rewrite"

push_url=$(GIT_BIN="$real_git" bash -c \
    'source "$1/scripts/workflow/common.sh"; workflow_remote_urls "$2" origin push' \
    _ "$root" "$remote_repo")
assert_equals "git@github.com:owner/repo.git" "$push_url" "push URL falls back to fetch"

git -C "$remote_repo" config remote.origin.pushurl "https://github.com/other/repo.git"
push_url=$(GIT_BIN="$real_git" bash -c \
    'source "$1/scripts/workflow/common.sh"; workflow_remote_urls "$2" origin push' \
    _ "$root" "$remote_repo")
assert_equals "https://github.com/other/repo.git" "$push_url" "effective push URL"

git -C "$remote_repo" config --unset "url.git@github.com:owner/repo.git.insteadOf"
git -C "$remote_repo" config --unset remote.origin.pushurl
git -C "$remote_repo" remote set-url origin "https://github.com/owner/repo.git"
git -C "$remote_repo" remote set-url --add origin "https://github.com/owner/other.git"
urls=$(GIT_BIN="$real_git" bash -c \
    'source "$1/scripts/workflow/common.sh"; workflow_remote_urls "$2" origin fetch' \
    _ "$root" "$remote_repo")
url_count=$(printf '%s\n' "$urls" | wc -l | tr -d ' ')
assert_equals "2" "$url_count" "multiple effective fetch URLs"

# --- Review range ------------------------------------------------------------

range_fixture="$fixture/range"
make_repository "$range_fixture"
range_seed="$range_fixture/seed"
range_base=$(git -C "$range_seed" rev-parse HEAD)
printf 'second\n' >> "$range_seed/file.txt"
git -C "$range_seed" commit -q -am "feat: second"
printf 'third\n' >> "$range_seed/file.txt"
git -C "$range_seed" commit -q -am "feat: third"
git -C "$range_seed" push -q origin main
range_head=$(git -C "$range_seed" rev-parse HEAD)

run_at "$range_seed" "$root/scripts/workflow/validate.sh" range \
    --base "$range_base" --head "$range_head"
assert_exit 0 "validate range"
assert_contains "validate: commits=2" "validate range"
assert_contains "validate: diffstat_begin" "validate range"

run_at "$range_seed" "$root/scripts/workflow/validate.sh" range \
    --base "$range_head" --head "$range_base"
assert_exit 1 "validate range reversed"

run_at "$range_seed" "$root/scripts/workflow/validate.sh" targeted
assert_exit 2 "validate targeted without checks"

validate_fixture="$fixture/validate"
mkdir -p "$validate_fixture/scripts"
git init -q "$validate_fixture"
configure_repo "$validate_fixture"
printf '#!/usr/bin/env bash\nexit 1\n' > "$validate_fixture/scripts/test-check-documentation.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$validate_fixture/scripts/check-documentation.sh"
chmod +x "$validate_fixture/scripts/test-check-documentation.sh" "$validate_fixture/scripts/check-documentation.sh"
printf 'fixture\n' > "$validate_fixture/file.txt"
git -C "$validate_fixture" add .
git -C "$validate_fixture" commit -q -m "chore: validation fixture"

run_at "$validate_fixture" "$root/scripts/workflow/validate.sh" targeted --docs
assert_exit 1 "validate compound failure"
assert_contains "validate: check=docs result=fail" "validate compound failure"
assert_contains "validate: repository=" "validate compound failure"
assert_contains "validate: commit=" "validate compound failure"
assert_contains "validate: dirty=" "validate compound failure"
assert_contains "validate: result=fail" "validate compound failure"

mkdir -p "$validate_fixture/subdirectory"
run_at "$validate_fixture/subdirectory" "$root/scripts/workflow/validate.sh" targeted --docs
assert_exit 1 "validate from subdirectory"
assert_contains "validate: repository=" "validate from subdirectory"
assert_contains "validate: check=docs result=fail" "validate from subdirectory"

# --- Merge readiness ---------------------------------------------------------

merge_head="1111111111111111111111111111111111111111"
merge_other="2222222222222222222222222222222222222222"
export STUB_REPOSITORY="owner/repo"
export STUB_PR_STATE="MERGED"
STUB_PR_RECORD=$(printf '7\x1fOPEN\x1ffalse\x1fmain\x1f%s\x1fchore/merge-test\x1fowner\x1frepo\x1fMERGEABLE\x1fCLEAN\x1fhttps://example.test/pull/7' "$merge_head")
export STUB_PR_RECORD
export STUB_CHECKS=$'build\x1fSUCCESS\x1fpass\ndocumentation\x1fSUCCESS\x1fpass\n'
export STUB_CHECKS_EXIT=0
: > "$gh_log"

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head"
assert_exit 0 "merge inspect ready"
assert_contains "merge: head_matches=yes" "merge inspect ready"
assert_contains "merge: result=ready" "merge inspect ready"
assert_not_contains "merge: result=merged" "merge inspect ready"

export STUB_CHECKS=$'build\x1fSUCCESS\x1fpass\n'
run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head"
assert_exit 1 "merge inspect default documentation"
assert_contains "merge: check=documentation result=missing" "merge inspect default documentation"

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head" --allow-missing-check documentation
assert_exit 0 "merge inspect allowed missing"
assert_contains "merge: check=documentation result=allowed-missing" "merge inspect allowed missing"
assert_contains "merge: result=ready" "merge inspect allowed missing"

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head" --allow-missing-check build
assert_exit 2 "merge inspect cannot waive build"

export STUB_CHECKS=$'build\x1fSUCCESS\x1fpass\ndocumentation\x1fSUCCESS\x1fpass\n'

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_other"
assert_exit 1 "merge inspect mismatch"
assert_contains "merge: head_matches=no" "merge inspect mismatch"
assert_not_contains "merge: result=ready" "merge inspect mismatch"

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha
assert_exit 2 "merge inspect missing value"

export STUB_CHECKS=$'build\x1fPENDING\x1fpending\ndocumentation\x1fSUCCESS\x1fpass\n'
export STUB_CHECKS_EXIT=8
run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head"
assert_exit 1 "merge inspect pending"
assert_contains "merge: check=build state=PENDING bucket=pending result=fail" "merge inspect pending"

export STUB_CHECKS=$'build\x1fSUCCESS\x1fpass\ndocumentation\x1fFAILURE\x1ffail\n'
export STUB_CHECKS_EXIT=1
run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head" --allow-missing-check documentation
assert_exit 1 "merge inspect unreadable checks"
assert_contains "merge: check=documentation result=unverified" "merge inspect unreadable checks"
assert_not_contains "merge: check=documentation result=allowed-missing" "merge inspect unreadable checks"

export STUB_CHECKS=$'build\x1fSUCCESS\x1fpass\ndocumentation\x1fSUCCESS\x1fpass\n'
export STUB_CHECKS_EXIT=0
: > "$gh_log"
run_at "$fixture" "$root/scripts/workflow/merge.sh" execute \
    --pr 7 --verified-sha "$merge_head"
assert_exit 0 "merge execute"
assert_contains "merge: result=merged" "merge execute"
if grep -Fq -- "pr merge 7 --repo owner/repo --merge --match-head-commit $merge_head" "$gh_log"; then
    ok
else
    fail "merge execute did not pass the original verified SHA"
fi
if grep -Fq -- "--delete-branch" "$gh_log"; then
    fail "merge execute deleted a branch without explicit request"
else
    ok
fi

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head" --delete-branch
assert_exit 2 "merge inspect rejects delete branch"
assert_contains "unknown argument: --delete-branch" "merge inspect rejects delete branch"
assert_not_contains "merge: result=ready" "merge inspect rejects delete branch"

# --- Cleanup fixture: merged branch, worktree, and workspace -----------------

cleanup_fixture="$fixture/cleanup"
fixture_output=$(make_merged_issue "$cleanup_fixture" chore/cleanup-test "cleanup work")
IFS=$'\x1f' read -r cleanup_seed cleanup_head cleanup_merge cleanup_worktree <<< "$fixture_output"

export STUB_REPOSITORY="owner/repo"
export STUB_PR_STATE="MERGED"
set_merged_pr 8 "$cleanup_head" "$cleanup_merge" chore/cleanup-test
set_paseo_workspace wks_cleanup "$cleanup_worktree"
rm -f "$paseo_archived"
: > "$paseo_log"

run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 0 "cleanup inspect"
assert_contains "cleanup: result=pass" "cleanup inspect"
assert_contains "cleanup: remote_branch=delete_candidate" "cleanup inspect"
assert_contains "cleanup: local_main=fast_forward_candidate" "cleanup inspect"
assert_contains "cleanup: workspace=archive_candidate" "cleanup inspect"
assert_contains "cleanup: local_branch=delete_candidate_after_worktree_removal" "cleanup inspect"
if [ -d "$cleanup_worktree" ] && git -C "$cleanup_seed" show-ref --verify --quiet refs/heads/chore/cleanup-test; then
    ok
else
    fail "cleanup inspect changed local state"
fi

mkdir -p "$cleanup_worktree/subdirectory"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree/subdirectory" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup subdirectory target"
assert_contains "cleanup: blocked=worktree_path_not_root" "cleanup subdirectory target"
assert_path_exists "$cleanup_worktree" "cleanup subdirectory target"
rmdir "$cleanup_worktree/subdirectory"

mkdir -p "$cleanup_seed/main-subdirectory"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" --main-worktree "$cleanup_seed/main-subdirectory"
assert_exit 1 "cleanup main subdirectory"
assert_contains "cleanup: blocked=local_main_worktree_not_root" "cleanup main subdirectory"
rmdir "$cleanup_seed/main-subdirectory"

wrong_worktree="$cleanup_fixture/wrong-worktree"
git -C "$cleanup_seed" worktree add -q "$wrong_worktree" -b chore/wrong-worktree HEAD
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$wrong_worktree" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup wrong worktree"
assert_contains "cleanup: blocked=worktree_path_mismatch" "cleanup wrong worktree"
assert_path_exists "$wrong_worktree" "cleanup wrong worktree"
git -C "$cleanup_seed" worktree remove "$wrong_worktree"
git -C "$cleanup_seed" branch -d chore/wrong-worktree >/dev/null

export STUB_PASEO_FAIL=1
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup paseo query failure"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup paseo query failure"
unset STUB_PASEO_FAIL

run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_other --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup workspace id mismatch"
assert_contains "cleanup: blocked=workspace_id_mismatch" "cleanup workspace id mismatch"

wrong_cwd="$cleanup_fixture/other-worktree"
set_paseo_workspace wks_cleanup "$wrong_cwd"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup workspace cwd mismatch"
assert_contains "cleanup: blocked=workspace_cwd_mismatch" "cleanup workspace cwd mismatch"
set_paseo_workspace wks_cleanup "$cleanup_worktree"

run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --workspace-id 'wks_bad.*'
assert_exit 2 "cleanup invalid workspace id"

STUB_PR_RECORD="$(pr_record 15 MERGED "2026-01-01T00:00:00Z" \
    "$cleanup_merge" main "$cleanup_head")"
export STUB_PR_RECORD
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 15 --branch main
assert_exit 1 "cleanup main branch"
assert_contains "refusing to clean up the default or base branch" "cleanup main branch"
set_merged_pr 8 "$cleanup_head" "$cleanup_merge" chore/cleanup-test

idle_agent="[$(paseo_agent_json agent-idle "Finished issue work" idle "$cleanup_worktree" wks_cleanup)]"
set_paseo_agents "$idle_agent"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 0 "cleanup execute"
assert_contains "cleanup: remote_branch=deleted" "cleanup execute"
assert_contains "cleanup: local_main=synchronized" "cleanup execute"
assert_contains "cleanup: workspace=archived" "cleanup execute"
assert_contains "cleanup: worktree=removed" "cleanup execute"
assert_contains "cleanup: local_branch=deleted" "cleanup execute"
assert_contains "cleanup: result=pass" "cleanup execute"
set_paseo_agents "[]"

assert_remote_branch_absent "$cleanup_seed" chore/cleanup-test "cleanup execute"
assert_path_missing "$cleanup_worktree" "cleanup execute"
assert_branch_absent "$cleanup_seed" chore/cleanup-test "cleanup execute"
assert_main_synchronized "$cleanup_seed" "cleanup execute"

run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 0 "cleanup idempotent"
assert_contains "cleanup: local_branch=absent" "cleanup idempotent"
assert_contains "cleanup: worktree=absent" "cleanup idempotent"
assert_contains "cleanup: result=pass" "cleanup idempotent"

STUB_PR_RECORD="$(pr_record 13 OPEN "" "" chore/open-test \
    1111111111111111111111111111111111111111)"
export STUB_PR_RECORD
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect --pr 13
assert_exit 1 "cleanup open pr fields"
assert_contains "cleanup: base=main head=chore/open-test" "cleanup open pr fields"
assert_contains "cleanup: merge_commit= merged_at=" "cleanup open pr fields"

# A workspace supplied when the worktree is already absent must still match the
# supplied target path before it is archived.
set_merged_pr 8 "$cleanup_head" "$cleanup_merge" chore/cleanup-test
rm -f "$paseo_archived"
set_paseo_workspace wks_other "$cleanup_fixture/elsewhere"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --workspace-id wks_other --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup absent worktree workspace cwd"
assert_contains "cleanup: blocked=workspace_cwd_mismatch" "cleanup absent worktree workspace cwd"
set_paseo_workspace wks_cleanup "$cleanup_worktree"

# --- Cleanup safety: dirty worktree and fork branch --------------------------

dirty_fixture="$fixture/dirty"
fixture_output=$(make_merged_issue "$dirty_fixture" chore/dirty-test "dirty work")
IFS=$'\x1f' read -r dirty_seed dirty_head dirty_merge dirty_worktree <<< "$fixture_output"
printf 'local note\n' > "$dirty_worktree/untracked.txt"

set_merged_pr 9 "$dirty_head" "$dirty_merge" chore/dirty-test
set_paseo_workspace wks_dirty "$dirty_worktree"
rm -f "$paseo_archived"

run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 9 --verified-sha "$dirty_head" \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup dirty worktree"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup dirty worktree"
assert_path_exists "$dirty_worktree" "cleanup dirty worktree"
assert_branch_present "$dirty_seed" chore/dirty-test "cleanup dirty worktree"

# A merged same-name local branch belongs to a fork PR's head branch. It must be
# retained with its worktree and workspace, while the independently safe local
# main synchronization still runs.
rm -f "$dirty_worktree/untracked.txt"
git -C "$dirty_seed" push -q origin chore/dirty-test
set_merged_pr 11 "$dirty_head" "$dirty_merge" chore/dirty-test fork-owner repo
set_paseo_workspace wks_dirty "$dirty_worktree"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 11 --verified-sha "$dirty_head" \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 0 "cleanup fork same-name branch"
assert_contains "cleanup: same_repository=no" "cleanup fork same-name branch"
assert_contains "cleanup: remote_branch=retained reason=external_fork" "cleanup fork same-name branch"
assert_contains "cleanup: worktree=retained reason=external_fork" "cleanup fork same-name branch"
assert_contains "cleanup: workspace=retained reason=external_fork" "cleanup fork same-name branch"
assert_contains "cleanup: local_branch=retained reason=external_fork" "cleanup fork same-name branch"
assert_contains "cleanup: local_main=" "cleanup fork same-name branch"
assert_contains "cleanup: result=pass" "cleanup fork same-name branch"
assert_remote_branch_present "$dirty_seed" chore/dirty-test "cleanup fork same-name branch"
assert_path_exists "$dirty_worktree" "cleanup fork same-name branch"
assert_branch_present "$dirty_seed" chore/dirty-test "cleanup fork same-name branch"
assert_no_archive "cleanup fork same-name branch"

# An empty head repository is unverified identity, not the local repository.
set_merged_pr 31 "$dirty_head" "$dirty_merge" chore/dirty-test "" ""
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 31 --verified-sha "$dirty_head" \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 0 "cleanup unverified head repository"
assert_contains "cleanup: same_repository=no" "cleanup unverified head repository"
assert_contains "cleanup: worktree=retained reason=external_fork" "cleanup unverified head repository"
assert_contains "cleanup: local_branch=retained reason=external_fork" "cleanup unverified head repository"
assert_remote_branch_present "$dirty_seed" chore/dirty-test "cleanup unverified head repository"
assert_path_exists "$dirty_worktree" "cleanup unverified head repository"
assert_branch_present "$dirty_seed" chore/dirty-test "cleanup unverified head repository"
assert_no_archive "cleanup unverified head repository"

# A merge commit that is not on the default branch must stop cleanup before any
# destructive step.
git -C "$dirty_seed" checkout -q -b chore/unmerged
printf 'unmerged\n' >> "$dirty_seed/file.txt"
git -C "$dirty_seed" commit -q -am "feat: unmerged"
unmerged_sha=$(git -C "$dirty_seed" rev-parse HEAD)
git -C "$dirty_seed" checkout -q main
set_merged_pr 12 "$dirty_head" "$unmerged_sha" chore/dirty-test
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 12 --verified-sha "$dirty_head" --branch chore/dirty-test \
    --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup unverified merge"
assert_contains "cleanup: blocked=merge_commit_not_on_main" "cleanup unverified merge"
assert_remote_branch_present "$dirty_seed" chore/dirty-test "cleanup unverified merge"

# Meaningful ignored content under a broad output name is retained even when
# build-output removal is requested. Standard bin/obj output can be removed only
# with an explicit --remove-build-output request.
printf 'bin/\nobj/\nTestResults/\nartifacts/\n' >> "$dirty_seed/.git/info/exclude"
mkdir -p "$dirty_worktree/bin"
printf 'non-build note\n' > "$dirty_worktree/bin/important.txt"
set_merged_pr 14 "$dirty_head" "$dirty_merge" chore/dirty-test
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 14 --verified-sha "$dirty_head" \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup ignored content default"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup ignored content default"
rm -rf "${dirty_worktree:?}/bin"

mkdir -p "$dirty_worktree/bin"
printf 'meaningful note\n' > "$dirty_worktree/bin/important.txt"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful bin content with output flag"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful bin content with output flag"
assert_path_exists "$dirty_worktree/bin/important.txt" "cleanup meaningful bin content with output flag"
assert_no_archive "cleanup meaningful bin content with output flag"
rm -rf "${dirty_worktree:?}/bin"

mkdir -p "$dirty_worktree/obj"
printf 'meaningful json\n' > "$dirty_worktree/obj/notes.json"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful obj content"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful obj content"
assert_path_exists "$dirty_worktree/obj/notes.json" "cleanup meaningful obj content"
assert_no_archive "cleanup meaningful obj content"
rm -rf "${dirty_worktree:?}/obj"

mkdir -p "$dirty_worktree/TestResults"
printf 'meaningful test note\n' > "$dirty_worktree/TestResults/notes.txt"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful test results content"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful test results content"
assert_path_exists "$dirty_worktree/TestResults/notes.txt" "cleanup meaningful test results content"
assert_no_archive "cleanup meaningful test results content"
rm -rf "${dirty_worktree:?}/TestResults"

mkdir -p "$dirty_worktree/artifacts"
printf 'important\n' > "$dirty_worktree/artifacts/important.txt"
rm -f "$paseo_archived"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful ignored content"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful ignored content"
assert_path_exists "$dirty_worktree/artifacts/important.txt" "cleanup meaningful ignored content"
rm -rf "${dirty_worktree:?}/artifacts"

mkdir -p "$dirty_worktree/bin" "$dirty_worktree/obj" "$dirty_worktree/TestResults"
printf 'binary\n' > "$dirty_worktree/bin/output.dll"
printf '{"generated":true}\n' > "$dirty_worktree/obj/project.assets.json"
printf 'generated test result\n' > "$dirty_worktree/TestResults/generated.trx"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 0 "cleanup ignored build output"
assert_contains "cleanup: worktree=removed" "cleanup ignored build output"
assert_contains "cleanup: result=pass" "cleanup ignored build output"
assert_path_missing "$dirty_worktree" "cleanup ignored build output"

# --- Cleanup safety: local branch ancestry before any destructive step ------

unmerged_local_fixture="$fixture/unmerged-local"
fixture_output=$(make_merged_issue "$unmerged_local_fixture" chore/late-test "late work")
IFS=$'\x1f' read -r unmerged_local_seed late_head late_merge late_worktree <<< "$fixture_output"
printf 'after merge\n' >> "$late_worktree/file.txt"
git -C "$late_worktree" commit -q -am "feat: unmerged local work"
late_tip=$(git -C "$late_worktree" rev-parse HEAD)

set_merged_pr 20 "$late_head" "$late_merge" chore/late-test
set_paseo_workspace wks_late "$late_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"
: > "$gh_log"

run_at "$unmerged_local_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 20 --verified-sha "$late_head" \
    --workspace-id wks_late --worktree "$late_worktree" --main-worktree "$unmerged_local_seed"
assert_exit 1 "cleanup unmerged local branch"
assert_contains "cleanup: blocked=local_branch_commits_not_merged" "cleanup unmerged local branch"
assert_contains "cleanup: worktree=retained reason=local_branch_commits_not_merged" "cleanup unmerged local branch"
assert_contains "cleanup: workspace=retained reason=local_branch_commits_not_merged" "cleanup unmerged local branch"
assert_path_exists "$late_worktree" "cleanup unmerged local branch"
assert_branch_present "$unmerged_local_seed" chore/late-test "cleanup unmerged local branch"
assert_head_equals "$late_worktree" "$late_tip" "cleanup unmerged local branch"
assert_no_archive "cleanup unmerged local branch"
assert_remote_branch_present "$unmerged_local_seed" chore/late-test "cleanup unmerged local branch"

# --- Cleanup safety: explicit workspace ownership ---------------------------

workspace_identity_fixture="$fixture/workspace-identity"
fixture_output=$(make_merged_issue "$workspace_identity_fixture" chore/target-ws "target work")
IFS=$'\x1f' read -r workspace_identity_seed workspace_target_head workspace_target_merge workspace_target_worktree <<< "$fixture_output"
workspace_other_worktree="$workspace_identity_fixture/other"
git -C "$workspace_identity_seed" worktree add -q -b chore/other-ws "$workspace_other_worktree" HEAD

set_merged_pr 21 "$workspace_target_head" "$workspace_target_merge" chore/target-ws
set_paseo_workspace wks_other_issue "$workspace_other_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"

run_at "$workspace_identity_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 21 --verified-sha "$workspace_target_head" \
    --workspace-id wks_other_issue --worktree "$workspace_target_worktree" --main-worktree "$workspace_identity_seed"
assert_exit 1 "cleanup workspace from another issue"
assert_contains "cleanup: blocked=workspace_cwd_mismatch" "cleanup workspace from another issue"
assert_path_exists "$workspace_target_worktree" "cleanup workspace from another issue"
assert_branch_present "$workspace_identity_seed" chore/target-ws "cleanup workspace from another issue"
assert_no_archive "cleanup workspace from another issue"

absent_workspace_fixture="$fixture/absent-workspace"
fixture_output=$(make_merged_issue "$absent_workspace_fixture" chore/absent-ws "absent work" no)
IFS=$'\x1f' read -r absent_workspace_seed absent_head absent_merge _ <<< "$fixture_output"
absent_missing_worktree="$absent_workspace_fixture/missing-worktree"

set_merged_pr 22 "$absent_head" "$absent_merge" chore/absent-ws
set_paseo_workspace wks_missing "$absent_missing_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"

run_at "$absent_workspace_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 22 --verified-sha "$absent_head" \
    --workspace-id wks_missing --worktree "$absent_missing_worktree" --main-worktree "$absent_workspace_seed"
assert_exit 1 "cleanup absent workspace worktree"
assert_contains "cleanup: blocked=workspace_ownership_unverifiable" "cleanup absent workspace worktree"
assert_no_archive "cleanup absent workspace worktree"
assert_branch_present "$absent_workspace_seed" chore/absent-ws "cleanup absent workspace worktree"

# --- Cleanup safety: agent ownership and activity ---------------------------

agent_fixture="$fixture/agents"
fixture_output=$(make_merged_issue "$agent_fixture" chore/agent-ws "agent work")
IFS=$'\x1f' read -r agent_seed agent_head agent_merge agent_worktree <<< "$fixture_output"

set_merged_pr 23 "$agent_head" "$agent_merge" chore/agent-ws
set_paseo_workspace wks_agent "$agent_worktree"
rm -f "$paseo_archived"
: > "$paseo_log"

agents="[$(paseo_agent_json agent-running "Ongoing work" running "$agent_worktree" wks_agent)]"
set_paseo_agents "$agents"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup ongoing agent"
assert_contains "cleanup: blocked=workspace_agent_ongoing" "cleanup ongoing agent"
assert_path_exists "$agent_worktree" "cleanup ongoing agent"
assert_no_archive "cleanup ongoing agent"

agents="[$(paseo_agent_json agent-unrelated "Other work" idle "$agent_fixture/elsewhere" wks_agent)]"
set_paseo_agents "$agents"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup unrelated agent"
assert_contains "cleanup: blocked=workspace_agent_unrelated" "cleanup unrelated agent"
assert_path_exists "$agent_worktree" "cleanup unrelated agent"
assert_no_archive "cleanup unrelated agent"

compact_running=$(paseo_agent_json agent-compact-running "Compact ongoing" running "$agent_worktree" wks_agent)
compact_idle=$(paseo_agent_json agent-compact-idle "Compact idle" idle "$agent_fixture/elsewhere" wks_other)
agents=$(printf '[%s,%s]' "$compact_running" "$compact_idle")
set_paseo_agents "$agents"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup compact ongoing agent"
assert_contains "cleanup: blocked=workspace_agent_ongoing" "cleanup compact ongoing agent"
assert_path_exists "$agent_worktree" "cleanup compact ongoing agent"
assert_no_archive "cleanup compact ongoing agent"

agents="[$(paseo_agent_json agent-other-workspace "Other workspace" idle "$agent_worktree" wks_other)]"
set_paseo_agents "$agents"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup agent from another workspace"
assert_contains "cleanup: blocked=workspace_agent_other_workspace" "cleanup agent from another workspace"
assert_path_exists "$agent_worktree" "cleanup agent from another workspace"
assert_no_archive "cleanup agent from another workspace"

set_paseo_agents '[{"unexpected":true}]'
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup malformed agent state"
assert_contains "cleanup: blocked=workspace_agent_query_failed" "cleanup malformed agent state"
assert_path_exists "$agent_worktree" "cleanup malformed agent state"
assert_no_archive "cleanup malformed agent state"

set_paseo_agents '[{"id":"agent-null-cwd","name":"Null cwd","status":"idle","cwd":null,"workspaceId":"wks_agent"}]'
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup non-string agent field"
assert_contains "cleanup: blocked=workspace_agent_query_failed" "cleanup non-string agent field"
assert_path_exists "$agent_worktree" "cleanup non-string agent field"
assert_no_archive "cleanup non-string agent field"

duplicate_first=$(paseo_agent_json agent-duplicate "First" idle "$agent_worktree" wks_agent)
duplicate_second=$(paseo_agent_json agent-duplicate "Second" idle "$agent_worktree" wks_agent)
agents=$(printf '[%s,%s]' "$duplicate_first" "$duplicate_second")
set_paseo_agents "$agents"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup duplicate agent identity"
assert_contains "cleanup: blocked=workspace_agent_query_failed" "cleanup duplicate agent identity"
assert_path_exists "$agent_worktree" "cleanup duplicate agent identity"
assert_no_archive "cleanup duplicate agent identity"

mkdir -p "$agent_worktree/café"
set_paseo_agents "[{\"id\":\"agent-escaped-path\",\"name\":\"caf\\u00e9\",\"status\":\"idle\",\"cwd\":\"$agent_worktree/caf\\u00e9\",\"workspaceId\":\"wks_agent\"}]"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 0 "cleanup escaped agent path"
assert_contains "cleanup: worktree=remove_candidate" "cleanup escaped agent path"
assert_contains "cleanup: result=pass" "cleanup escaped agent path"
assert_no_archive "cleanup escaped agent path"

set_paseo_agents "[{\"id\":\"agent-control-path\",\"name\":\"control\",\"status\":\"idle\",\"cwd\":\"$agent_worktree/bad\\u001fpath\",\"workspaceId\":\"wks_agent\"}]"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup unsupported agent control character"
assert_contains "cleanup: blocked=workspace_agent_query_failed" "cleanup unsupported agent control character"
assert_path_exists "$agent_worktree" "cleanup unsupported agent control character"
assert_no_archive "cleanup unsupported agent control character"

set_paseo_agents "[]"
export STUB_PASEO_AGENTS_FAIL=1
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
unset STUB_PASEO_AGENTS_FAIL
assert_exit 1 "cleanup unavailable agent state"
assert_contains "cleanup: blocked=workspace_agent_query_failed" "cleanup unavailable agent state"
assert_path_exists "$agent_worktree" "cleanup unavailable agent state"
assert_no_archive "cleanup unavailable agent state"
set_paseo_agents "[]"

# --- Cleanup safety: Git state query failures -------------------------------

status_fixture="$fixture/status-failure"
fixture_output=$(make_merged_issue "$status_fixture" chore/status-ws "status work")
IFS=$'\x1f' read -r status_seed status_head status_merge status_worktree <<< "$fixture_output"

set_merged_pr 32 "$status_head" "$status_merge" chore/status-ws
set_paseo_workspace wks_status "$status_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"

export STUB_GIT_FAIL_STATUS="tracked"
export STUB_GIT_FAIL_STATUS_PATH="$status_worktree"
run_at "$status_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 32 --verified-sha "$status_head" \
    --workspace-id wks_status --worktree "$status_worktree" --main-worktree "$status_seed"
unset STUB_GIT_FAIL_STATUS STUB_GIT_FAIL_STATUS_PATH
assert_exit 1 "cleanup tracked status query failure"
assert_contains "cleanup: blocked=worktree_status_failed" "cleanup tracked status query failure"
assert_path_exists "$status_worktree" "cleanup tracked status query failure"
assert_branch_present "$status_seed" chore/status-ws "cleanup tracked status query failure"
assert_no_archive "cleanup tracked status query failure"

export STUB_GIT_FAIL_STATUS="ignored"
export STUB_GIT_FAIL_STATUS_PATH="$status_worktree"
run_at "$status_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 32 --verified-sha "$status_head" \
    --workspace-id wks_status --worktree "$status_worktree" --main-worktree "$status_seed"
unset STUB_GIT_FAIL_STATUS STUB_GIT_FAIL_STATUS_PATH
assert_exit 1 "cleanup ignored status query failure"
assert_contains "cleanup: blocked=worktree_status_failed" "cleanup ignored status query failure"
assert_path_exists "$status_worktree" "cleanup ignored status query failure"
assert_branch_present "$status_seed" chore/status-ws "cleanup ignored status query failure"
assert_no_archive "cleanup ignored status query failure"

export STUB_GIT_FAIL_WORKTREE=1
run_at "$status_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 32 --verified-sha "$status_head" \
    --workspace-id wks_status --worktree "$status_worktree" --main-worktree "$status_seed"
unset STUB_GIT_FAIL_WORKTREE
assert_exit 1 "cleanup worktree query failure"
assert_contains "cleanup: blocked=worktree_query_failed" "cleanup worktree query failure"
assert_path_exists "$status_worktree" "cleanup worktree query failure"
assert_branch_present "$status_seed" chore/status-ws "cleanup worktree query failure"
assert_no_archive "cleanup worktree query failure"

# --- Cleanup safety: repository identity ------------------------------------

identity_fixture="$fixture/identity"
fixture_output=$(make_merged_issue "$identity_fixture" chore/identity-ws "identity work")
IFS=$'\x1f' read -r identity_seed identity_head identity_merge identity_worktree <<< "$fixture_output"

set_merged_pr 24 "$identity_head" "$identity_merge" chore/identity-ws
set_paseo_workspace wks_identity "$identity_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"

git -C "$identity_seed" config "url.$identity_fixture/origin.git.insteadOf" "https://github.com/other/repo.git"
git -C "$identity_seed" config remote.origin.url "https://github.com/other/repo.git"
run_at "$identity_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 24 --verified-sha "$identity_head" \
    --workspace-id wks_identity --worktree "$identity_worktree" --main-worktree "$identity_seed"
assert_exit 1 "cleanup repository identity mismatch"
assert_contains "repository identity mismatch" "cleanup repository identity mismatch"
assert_path_exists "$identity_worktree" "cleanup repository identity mismatch"
assert_no_archive "cleanup repository identity mismatch"
assert_branch_present "$identity_seed" chore/identity-ws "cleanup repository identity mismatch"

git -C "$identity_seed" config remote.origin.pushurl "https://github.com/other/repo.git"
run_at "$identity_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 24 --verified-sha "$identity_head"
assert_exit 1 "cleanup push destination mismatch"
assert_contains "repository identity mismatch" "cleanup push destination mismatch"
assert_no_archive "cleanup push destination mismatch"

main_identity_fixture="$fixture/main-identity"
fixture_output=$(make_merged_issue "$main_identity_fixture" chore/main-identity "main identity work")
IFS=$'\x1f' read -r main_identity_seed main_identity_head main_identity_merge main_identity_worktree <<< "$fixture_output"

foreign_fixture="$fixture/foreign-main"
make_repository "$foreign_fixture"
foreign_seed="$foreign_fixture/seed"

set_merged_pr 25 "$main_identity_head" "$main_identity_merge" chore/main-identity
set_paseo_workspace wks_main_identity "$main_identity_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$main_identity_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 25 --verified-sha "$main_identity_head" \
    --workspace-id wks_main_identity --worktree "$main_identity_worktree" --main-worktree "$foreign_seed"
assert_exit 1 "cleanup main worktree from another repository"
assert_contains "cleanup: blocked=local_main_repository_mismatch" "cleanup main worktree from another repository"
assert_path_exists "$main_identity_worktree" "cleanup main worktree from another repository"
assert_no_archive "cleanup main worktree from another repository"
assert_remote_branch_present "$main_identity_seed" chore/main-identity "cleanup main worktree from another repository"

rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$main_identity_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 25 --verified-sha "$main_identity_head" \
    --workspace-id wks_main_identity --worktree "$main_identity_worktree" \
    --main-worktree "$main_identity_fixture/missing-main-worktree"
assert_exit 1 "cleanup explicit missing main worktree"
assert_contains "cleanup: blocked=local_main_worktree_missing" "cleanup explicit missing main worktree"
assert_path_exists "$main_identity_worktree" "cleanup explicit missing main worktree"
assert_no_archive "cleanup explicit missing main worktree"
assert_remote_branch_present "$main_identity_seed" chore/main-identity "cleanup explicit missing main worktree"

# --- Cleanup safety: workspace discovery and incomplete state ---------------

discovery_fixture="$fixture/discovery"
fixture_output=$(make_merged_issue "$discovery_fixture" chore/discovery-ws "discovery work")
IFS=$'\x1f' read -r discovery_seed discovery_head discovery_merge discovery_worktree <<< "$fixture_output"

set_merged_pr 29 "$discovery_head" "$discovery_merge" chore/discovery-ws
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"

set_paseo_agents "[]"
set_paseo_json '[{"workspaceId":"wks_discovery"}]'
run_at "$discovery_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 29 --verified-sha "$discovery_head" \
    --worktree "$discovery_worktree" --main-worktree "$discovery_seed"
assert_exit 1 "cleanup incomplete workspace discovery state"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup incomplete workspace discovery state"
assert_path_exists "$discovery_worktree" "cleanup incomplete workspace discovery state"
assert_no_archive "cleanup incomplete workspace discovery state"

set_paseo_json '[{"workspaceId":"wks_discovery","cwd":null}]'
run_at "$discovery_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 29 --verified-sha "$discovery_head" \
    --worktree "$discovery_worktree" --main-worktree "$discovery_seed"
assert_exit 1 "cleanup non-string workspace cwd"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup non-string workspace cwd"
assert_path_exists "$discovery_worktree" "cleanup non-string workspace cwd"
assert_no_archive "cleanup non-string workspace cwd"

duplicate_one=$(paseo_workspace_record wks_discovery "$discovery_worktree")
duplicate_two=$(paseo_workspace_record wks_discovery "$discovery_fixture/elsewhere")
duplicate_workspaces=$(printf '[%s,%s]' "$duplicate_one" "$duplicate_two")
set_paseo_json "$duplicate_workspaces"
run_at "$discovery_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 29 --verified-sha "$discovery_head" \
    --worktree "$discovery_worktree" --main-worktree "$discovery_seed"
assert_exit 1 "cleanup duplicate workspace identity"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup duplicate workspace identity"
assert_path_exists "$discovery_worktree" "cleanup duplicate workspace identity"
assert_no_archive "cleanup duplicate workspace identity"

variant_one=$(paseo_workspace_record wks_discovery_a "$discovery_worktree")
variant_two=$(paseo_workspace_record wks_discovery_b "$discovery_worktree/")
ambiguous_workspaces=$(printf '[%s,%s]' "$variant_one" "$variant_two")
set_paseo_json "$ambiguous_workspaces"
run_at "$discovery_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 29 --verified-sha "$discovery_head" \
    --worktree "$discovery_worktree" --main-worktree "$discovery_seed"
assert_exit 1 "cleanup ambiguous normalized workspace cwd"
assert_contains "cleanup: blocked=workspace_identity_ambiguous" "cleanup ambiguous normalized workspace cwd"
assert_path_exists "$discovery_worktree" "cleanup ambiguous normalized workspace cwd"
assert_no_archive "cleanup ambiguous normalized workspace cwd"

control_workspace="[{\"workspaceId\":\"wks_discovery\",\"cwd\":\"$discovery_worktree/bad\\u001fpath\"}]"
set_paseo_json "$control_workspace"
run_at "$discovery_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 29 --verified-sha "$discovery_head" \
    --worktree "$discovery_worktree" --main-worktree "$discovery_seed"
assert_exit 1 "cleanup unsupported workspace control character"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup unsupported workspace control character"
assert_path_exists "$discovery_worktree" "cleanup unsupported workspace control character"
assert_no_archive "cleanup unsupported workspace control character"

formatted_workspace=$(printf '[{"workspaceId":"wks_discovery","cwd":"%s/"}]' "$discovery_worktree")
set_paseo_json "$formatted_workspace"
agents="[$(paseo_agent_json agent-discovery "Discovery work" idle "$discovery_worktree" wks_discovery)]"
set_paseo_agents "$agents"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$discovery_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 29 --verified-sha "$discovery_head" \
    --worktree "$discovery_worktree" --main-worktree "$discovery_seed"
assert_exit 0 "cleanup discovered workspace with formatted cwd"
assert_contains "cleanup: workspace=archived" "cleanup discovered workspace with formatted cwd"
assert_contains "cleanup: worktree=removed" "cleanup discovered workspace with formatted cwd"
assert_contains "cleanup: local_branch=deleted" "cleanup discovered workspace with formatted cwd"
assert_contains "cleanup: result=pass" "cleanup discovered workspace with formatted cwd"
assert_path_missing "$discovery_worktree" "cleanup discovered workspace with formatted cwd"

# --- Cleanup safety: remote branch races ------------------------------------

race_fixture="$fixture/race"
fixture_output=$(make_merged_issue "$race_fixture" chore/race-ws "race work")
IFS=$'\x1f' read -r race_seed race_head race_merge race_worktree <<< "$fixture_output"
git -C "$race_seed" checkout -q -b chore/race-concurrent HEAD
printf 'concurrent work\n' >> "$race_seed/file.txt"
git -C "$race_seed" commit -q -am "feat: concurrent work"
race_concurrent=$(git -C "$race_seed" rev-parse HEAD)
git -C "$race_seed" push -q origin chore/race-concurrent
git -C "$race_seed" checkout -q main

set_merged_pr 26 "$race_head" "$race_merge" chore/race-ws
set_paseo_workspace wks_race "$race_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"
export STUB_RACE_ORIGIN="$race_fixture/origin.git"
export STUB_RACE_REF="refs/heads/chore/race-ws"
export STUB_RACE_SHA="$race_concurrent"
run_at "$race_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 26 --verified-sha "$race_head" \
    --workspace-id wks_race --worktree "$race_worktree" --main-worktree "$race_seed"
unset STUB_RACE_ORIGIN STUB_RACE_REF STUB_RACE_SHA
assert_exit 1 "cleanup remote branch race"
assert_contains "cleanup: blocked=remote_branch_delete_failed" "cleanup remote branch race"
race_ref=$(git -C "$race_seed" ls-remote --heads origin chore/race-ws)
assert_equals "$race_concurrent" "${race_ref%%[[:space:]]*}" "cleanup remote branch race"

# --- Cleanup safety: unavailable or malformed state -------------------------

malformed_fixture="$fixture/malformed"
fixture_output=$(make_merged_issue "$malformed_fixture" chore/malformed-ws "malformed work")
IFS=$'\x1f' read -r malformed_seed malformed_head malformed_merge malformed_worktree <<< "$fixture_output"

set_merged_pr 27 "$malformed_head" "$malformed_merge" chore/malformed-ws
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"

set_paseo_json '{"workspaceId": "wks_malformed"}'
run_at "$malformed_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 27 --verified-sha "$malformed_head" \
    --workspace-id wks_malformed --worktree "$malformed_worktree" --main-worktree "$malformed_seed"
assert_exit 1 "cleanup malformed paseo state"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup malformed paseo state"
assert_path_exists "$malformed_worktree" "cleanup malformed paseo state"
assert_no_archive "cleanup malformed paseo state"

set_paseo_json '[{"workspaceId":"wks_malformed"'
run_at "$malformed_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 27 --verified-sha "$malformed_head" \
    --workspace-id wks_malformed --worktree "$malformed_worktree" --main-worktree "$malformed_seed"
assert_exit 1 "cleanup truncated paseo state"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup truncated paseo state"
assert_path_exists "$malformed_worktree" "cleanup truncated paseo state"
assert_no_archive "cleanup truncated paseo state"

set_paseo_json '[] []'
run_at "$malformed_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 27 --verified-sha "$malformed_head" \
    --workspace-id wks_malformed --worktree "$malformed_worktree" --main-worktree "$malformed_seed"
assert_exit 1 "cleanup multiple json values"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup multiple json values"
assert_path_exists "$malformed_worktree" "cleanup multiple json values"
assert_no_archive "cleanup multiple json values"

export STUB_GH_FAIL=1
run_at "$malformed_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 27 --verified-sha "$malformed_head" \
    --workspace-id wks_malformed --worktree "$malformed_worktree" --main-worktree "$malformed_seed"
unset STUB_GH_FAIL
assert_exit 1 "cleanup unavailable github state"
assert_contains "could not verify the GitHub repository" "cleanup unavailable github state"
assert_path_exists "$malformed_worktree" "cleanup unavailable github state"
assert_no_archive "cleanup unavailable github state"

git -C "$malformed_seed" config remote.origin.url "$malformed_fixture/origin.git"
run_at "$malformed_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 27 --verified-sha "$malformed_head"
assert_exit 1 "cleanup unverifiable origin"
assert_contains "cannot establish the GitHub repository" "cleanup unverifiable origin"
assert_no_archive "cleanup unverifiable origin"

# --- Cleanup safety: resumable partial cleanup ------------------------------

resume_fixture="$fixture/resume"
fixture_output=$(make_merged_issue "$resume_fixture" chore/resume-ws "resume work")
IFS=$'\x1f' read -r resume_seed resume_head resume_merge resume_worktree <<< "$fixture_output"

set_merged_pr 28 "$resume_head" "$resume_merge" chore/resume-ws
set_paseo_workspace wks_resume "$resume_worktree"
set_paseo_agents "[]"
rm -f "$paseo_archived"
: > "$paseo_log"

export STUB_PASEO_FAIL=1
run_at "$resume_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 28 --verified-sha "$resume_head" \
    --workspace-id wks_resume --worktree "$resume_worktree" --main-worktree "$resume_seed"
unset STUB_PASEO_FAIL
assert_exit 1 "cleanup partial paseo failure"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup partial paseo failure"
assert_path_exists "$resume_worktree" "cleanup partial paseo failure"
assert_no_archive "cleanup partial paseo failure"
assert_remote_branch_absent "$resume_seed" chore/resume-ws "cleanup partial paseo failure"

run_at "$resume_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 28 --verified-sha "$resume_head" \
    --workspace-id wks_resume --worktree "$resume_worktree" --main-worktree "$resume_seed"
assert_exit 0 "cleanup resume after partial failure"
assert_contains "cleanup: remote_branch=absent" "cleanup resume after partial failure"
assert_contains "cleanup: local_main=unchanged" "cleanup resume after partial failure"
assert_contains "cleanup: workspace=archived" "cleanup resume after partial failure"
assert_contains "cleanup: worktree=removed" "cleanup resume after partial failure"
assert_contains "cleanup: local_branch=deleted" "cleanup resume after partial failure"
assert_contains "cleanup: result=pass" "cleanup resume after partial failure"
assert_path_missing "$resume_worktree" "cleanup resume after partial failure"

run_at "$resume_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 28 --verified-sha "$resume_head" \
    --workspace-id wks_resume --worktree "$resume_worktree" --main-worktree "$resume_seed"
assert_exit 0 "cleanup resume repeated"
assert_contains "cleanup: local_branch=absent" "cleanup resume repeated"
assert_contains "cleanup: worktree=absent" "cleanup resume repeated"
assert_contains "cleanup: result=pass" "cleanup resume repeated"

printf 'workflow-script tests: %s passed, %s failed\n' "$passed" "$failed"
if [ "$failed" -ne 0 ]; then
    exit 1
fi
