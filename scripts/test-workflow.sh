#!/usr/bin/env bash
# Synthetic cases for the workflow entry points. Uses temporary Git repositories
# and stubbed GitHub/Paseo commands. It never contacts GitHub or Paseo and never
# uses private data.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d)"
output="$(mktemp)"
trap 'rm -rf "$fixture"; rm -f "$output"' EXIT

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
gh_log="$fixture/gh.log"
paseo_log="$fixture/paseo.log"
paseo_archived="$fixture/paseo.archived"
: > "$gh_log"
: > "$paseo_log"
export STUB_REPOSITORY="owner/repo"

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
}
write_stubs

export GH_BIN="$gh_stub"
export PASEO_BIN="$paseo_stub"
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

# --- Workspace fixture: unmerged branch based on origin/main -----------------

workspace_fixture="$fixture/workspace"
make_repository "$workspace_fixture"
workspace_seed="$workspace_fixture/seed"
git -C "$workspace_seed" checkout -q -b chore/workspace-test
printf 'work\n' >> "$workspace_seed/file.txt"
git -C "$workspace_seed" commit -q -am "feat: workspace slice"
git -C "$workspace_seed" push -q -u origin chore/workspace-test
git -C "$workspace_seed" checkout -q main
workspace_base=$(git -C "$workspace_seed" rev-parse origin/main)
git -C "$workspace_seed" worktree add -q "$workspace_fixture/worktree" chore/workspace-test

export STUB_REPOSITORY="owner/repo"
export STUB_ISSUE_RECORD=$'1\x1fOPEN\x1fTest issue\x1fhttps://example.test/issues/1\x1fready-for-agent'
export STUB_ISSUE_STATE="OPEN"

run_at "$workspace_seed" "$root/scripts/workflow/workspace.sh" prepare \
    --issue 1 --branch chore/workspace-test
assert_exit 0 "workspace prepare existing"
assert_contains "workspace: action=reuse" "workspace prepare existing"
assert_contains "workspace: base_sha=$workspace_base" "workspace prepare existing"
assert_contains "workspace: worktree_clean=yes" "workspace prepare existing"

run_at "$workspace_fixture/worktree" "$root/scripts/workflow/workspace.sh" verify \
    --issue 1 --branch chore/workspace-test --base "$workspace_base"
assert_exit 0 "workspace verify"
assert_contains "workspace: verified=yes" "workspace verify"
assert_contains "workspace: head_sha=$(git -C "$workspace_fixture/worktree" rev-parse HEAD)" "workspace verify"

printf 'dirty\n' > "$workspace_fixture/worktree/untracked.txt"
run_at "$workspace_fixture/worktree" "$root/scripts/workflow/workspace.sh" verify \
    --issue 1 --branch chore/workspace-test --base "$workspace_base"
assert_exit 1 "workspace verify dirty"
rm -f "$workspace_fixture/worktree/untracked.txt"

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
export STUB_PR_RECORD=$'7\x1fOPEN\x1ffalse\x1fmain\x1f1111111111111111111111111111111111111111\x1fchore/merge-test\x1fowner\x1frepo\x1fMERGEABLE\x1fCLEAN\x1fhttps://example.test/pull/7'
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
make_repository "$cleanup_fixture"
cleanup_seed="$cleanup_fixture/seed"
git -C "$cleanup_seed" checkout -q -b chore/cleanup-test
printf 'cleanup work\n' >> "$cleanup_seed/file.txt"
git -C "$cleanup_seed" commit -q -am "feat: cleanup slice"
git -C "$cleanup_seed" push -q -u origin chore/cleanup-test
cleanup_head=$(git -C "$cleanup_seed" rev-parse HEAD)
git -C "$cleanup_seed" checkout -q main
git -C "$cleanup_seed" merge -q --no-ff chore/cleanup-test -m "Merge cleanup-test"
git -C "$cleanup_seed" push -q origin main
cleanup_merge=$(git -C "$cleanup_seed" rev-parse HEAD)
git -C "$cleanup_seed" reset -q --hard HEAD^1
cleanup_worktree="$cleanup_fixture/worktree"
git -C "$cleanup_seed" worktree add -q "$cleanup_worktree" chore/cleanup-test

export STUB_REPOSITORY="owner/repo"
export STUB_PR_STATE="MERGED"
export STUB_PR_RECORD="$(printf '8\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/cleanup-test\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/8' "$cleanup_merge" "$cleanup_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_cleanup","cwd":"%s"}]' "$cleanup_worktree")"
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
if [ -d "$cleanup_worktree" ]; then
    ok
else
    fail "cleanup removed a worktree targeted through a subdirectory"
fi
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
if [ -d "$wrong_worktree" ]; then
    ok
else
    fail "cleanup inspect removed a mismatched worktree"
fi
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
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_cleanup","cwd":"%s"}]' "$wrong_cwd")"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup workspace cwd mismatch"
assert_contains "cleanup: blocked=workspace_cwd_mismatch" "cleanup workspace cwd mismatch"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_cleanup","cwd":"%s"}]' "$cleanup_worktree")"

run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --workspace-id 'wks_bad.*'
assert_exit 2 "cleanup invalid workspace id"

export STUB_PR_RECORD="$(printf '15\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fmain\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/15' "$cleanup_merge" "$cleanup_head")"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 15 --branch main
assert_exit 1 "cleanup main branch"
assert_contains "refusing to clean up the default or base branch" "cleanup main branch"
export STUB_PR_RECORD="$(printf '8\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/cleanup-test\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/8' "$cleanup_merge" "$cleanup_head")"

export STUB_PASEO_AGENTS_JSON="$(printf '[\n  {\n    "id": "agent-idle",\n    "name": "Finished issue work",\n    "status": "idle",\n    "cwd": "%s",\n    "workspaceId": "wks_cleanup"\n  }\n]\n' "$cleanup_worktree")"
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
export STUB_PASEO_AGENTS_JSON="[]"

if [ -z "$(git -C "$cleanup_seed" ls-remote --heads origin chore/cleanup-test)" ]; then
    ok
else
    fail "cleanup did not delete the merged remote branch"
fi
if [ ! -d "$cleanup_worktree" ]; then
    ok
else
    fail "cleanup left the worktree directory"
fi
if ! git -C "$cleanup_seed" show-ref --verify --quiet refs/heads/chore/cleanup-test; then
    ok
else
    fail "cleanup left the merged local branch"
fi
if [ "$(git -C "$cleanup_seed" rev-parse HEAD)" = "$(git -C "$cleanup_seed" rev-parse origin/main)" ]; then
    ok
else
    fail "cleanup did not synchronize local main"
fi

run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 8 --verified-sha "$cleanup_head" \
    --workspace-id wks_cleanup --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 0 "cleanup idempotent"
assert_contains "cleanup: local_branch=absent" "cleanup idempotent"
assert_contains "cleanup: worktree=absent" "cleanup idempotent"
assert_contains "cleanup: result=pass" "cleanup idempotent"

export STUB_PR_RECORD=$'13\x1fOPEN\x1f\x1f\x1fchore/open-test\x1f1111111111111111111111111111111111111111\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/13'
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect --pr 13
assert_exit 1 "cleanup open pr fields"
assert_contains "cleanup: base=main head=chore/open-test" "cleanup open pr fields"
assert_contains "cleanup: merge_commit= merged_at=" "cleanup open pr fields"

# A workspace supplied when the worktree is already absent must still match the
# supplied target path before it is archived.
export STUB_PR_RECORD="$(printf '8\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/cleanup-test\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/8' "$cleanup_merge" "$cleanup_head")"
rm -f "$paseo_archived"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_other","cwd":"%s"}]' "$cleanup_fixture/elsewhere")"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 8 --workspace-id wks_other --worktree "$cleanup_worktree" --main-worktree "$cleanup_seed"
assert_exit 1 "cleanup absent worktree workspace cwd"
assert_contains "cleanup: blocked=workspace_cwd_mismatch" "cleanup absent worktree workspace cwd"

export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_cleanup","cwd":"%s"}]' "$cleanup_worktree")"

# --- Cleanup safety: dirty worktree and fork branch --------------------------

dirty_fixture="$fixture/dirty"
make_repository "$dirty_fixture"
dirty_seed="$dirty_fixture/seed"
git -C "$dirty_seed" checkout -q -b chore/dirty-test
printf 'dirty work\n' >> "$dirty_seed/file.txt"
git -C "$dirty_seed" commit -q -am "feat: dirty slice"
git -C "$dirty_seed" push -q -u origin chore/dirty-test
dirty_head=$(git -C "$dirty_seed" rev-parse HEAD)
git -C "$dirty_seed" checkout -q main
git -C "$dirty_seed" merge -q --no-ff chore/dirty-test -m "Merge dirty-test"
git -C "$dirty_seed" push -q origin main
dirty_merge=$(git -C "$dirty_seed" rev-parse HEAD)
dirty_worktree="$dirty_fixture/worktree"
git -C "$dirty_seed" worktree add -q "$dirty_worktree" chore/dirty-test
printf 'local note\n' > "$dirty_worktree/untracked.txt"

export STUB_PR_RECORD="$(printf '9\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/dirty-test\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/9' "$dirty_merge" "$dirty_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_dirty","cwd":"%s"}]' "$dirty_worktree")"
rm -f "$paseo_archived"

run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 9 --verified-sha "$dirty_head" \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup dirty worktree"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup dirty worktree"
if [ -d "$dirty_worktree" ]; then
    ok
else
    fail "cleanup removed a dirty worktree"
fi
if git -C "$dirty_seed" show-ref --verify --quiet refs/heads/chore/dirty-test; then
    ok
else
    fail "cleanup deleted a branch whose worktree was retained"
fi

export STUB_PR_RECORD="$(printf '10\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/cleanup-test\x1f%s\x1ffork-owner\x1frepo\x1fmain\x1fhttps://example.test/pull/10' "$cleanup_merge" "$cleanup_head")"
rm -f "$paseo_archived"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 10 --verified-sha "$cleanup_head"
assert_exit 0 "cleanup fork retention"
assert_contains "cleanup: same_repository=no" "cleanup fork retention"

# The fork scenario uses an already cleaned repository, so the remote branch is
# already absent. Assert the retained-fork path directly with a live branch.
rm -f "$dirty_worktree/untracked.txt"
git -C "$dirty_seed" push -q origin chore/dirty-test
export STUB_PR_RECORD="$(printf '11\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/dirty-test\x1f%s\x1ffork-owner\x1frepo\x1fmain\x1fhttps://example.test/pull/11' "$dirty_merge" "$dirty_head")"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 11 --verified-sha "$dirty_head" --branch chore/dirty-test --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 0 "cleanup fork live branch"
assert_contains "cleanup: remote_branch=retained reason=external_fork" "cleanup fork live branch"
if [ -n "$(git -C "$dirty_seed" ls-remote --heads origin chore/dirty-test)" ]; then
    ok
else
    fail "cleanup deleted a fork branch"
fi

# A merge commit that is not on the default branch must stop cleanup before any
# destructive step.
git -C "$dirty_seed" checkout -q -b chore/unmerged
printf 'unmerged\n' >> "$dirty_seed/file.txt"
git -C "$dirty_seed" commit -q -am "feat: unmerged"
unmerged_sha=$(git -C "$dirty_seed" rev-parse HEAD)
git -C "$dirty_seed" checkout -q main
export STUB_PR_RECORD="$(printf '12\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/dirty-test\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/12' "$unmerged_sha" "$dirty_head")"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 12 --verified-sha "$dirty_head" --branch chore/dirty-test --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup unverified merge"
assert_contains "cleanup: blocked=merge_commit_not_on_main" "cleanup unverified merge"
if [ -n "$(git -C "$dirty_seed" ls-remote --heads origin chore/dirty-test)" ]; then
    ok
else
    fail "cleanup deleted a remote branch before verifying the merge"
fi

# Meaningful ignored content under a broad output name is retained even when
# build-output removal is requested. Standard bin/obj output can be removed only
# with an explicit --remove-build-output request.
printf 'bin/\nobj/\nTestResults/\nartifacts/\n' >> "$dirty_seed/.git/info/exclude"
mkdir -p "$dirty_worktree/bin"
printf 'non-build note\n' > "$dirty_worktree/bin/important.txt"
export STUB_PR_RECORD="$(printf '14\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/dirty-test\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/14' "$dirty_merge" "$dirty_head")"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 14 --verified-sha "$dirty_head" \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup ignored content default"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup ignored content default"
rm -rf "$dirty_worktree/bin"

mkdir -p "$dirty_worktree/bin"
printf 'meaningful note\n' > "$dirty_worktree/bin/important.txt"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful bin content with output flag"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful bin content with output flag"
if [ -f "$dirty_worktree/bin/important.txt" ]; then
    ok
else
    fail "cleanup deleted meaningful content inside a conventionally generated directory"
fi
assert_no_archive "cleanup meaningful bin content with output flag"
rm -rf "$dirty_worktree/bin"

mkdir -p "$dirty_worktree/obj"
printf 'meaningful json\n' > "$dirty_worktree/obj/notes.json"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful obj content"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful obj content"
if [ -f "$dirty_worktree/obj/notes.json" ]; then
    ok
else
    fail "cleanup deleted meaningful content under obj"
fi
assert_no_archive "cleanup meaningful obj content"
rm -rf "$dirty_worktree/obj"

mkdir -p "$dirty_worktree/TestResults"
printf 'meaningful test note\n' > "$dirty_worktree/TestResults/notes.txt"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful test results content"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful test results content"
if [ -f "$dirty_worktree/TestResults/notes.txt" ]; then
    ok
else
    fail "cleanup deleted meaningful content under TestResults"
fi
assert_no_archive "cleanup meaningful test results content"
rm -rf "$dirty_worktree/TestResults"

mkdir -p "$dirty_worktree/artifacts"
printf 'important\n' > "$dirty_worktree/artifacts/important.txt"
rm -f "$paseo_archived"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 14 --verified-sha "$dirty_head" --remove-build-output \
    --workspace-id wks_dirty --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup meaningful ignored content"
assert_contains "cleanup: blocked=worktree_has_local_content" "cleanup meaningful ignored content"
if [ -f "$dirty_worktree/artifacts/important.txt" ]; then
    ok
else
    fail "cleanup deleted meaningful ignored content"
fi
rm -rf "$dirty_worktree/artifacts"

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
if [ ! -d "$dirty_worktree" ]; then
    ok
else
    fail "cleanup retained a worktree with only reproducible output"
fi

# --- Cleanup safety: local branch ancestry before any destructive step ------

unmerged_local_fixture="$fixture/unmerged-local"
make_repository "$unmerged_local_fixture"
unmerged_local_seed="$unmerged_local_fixture/seed"
git -C "$unmerged_local_seed" checkout -q -b chore/late-test
printf 'late work\n' >> "$unmerged_local_seed/file.txt"
git -C "$unmerged_local_seed" commit -q -am "feat: late work"
git -C "$unmerged_local_seed" push -q -u origin chore/late-test
late_head=$(git -C "$unmerged_local_seed" rev-parse HEAD)
git -C "$unmerged_local_seed" checkout -q main
git -C "$unmerged_local_seed" merge -q --no-ff chore/late-test -m "Merge late-test"
git -C "$unmerged_local_seed" push -q origin main
late_merge=$(git -C "$unmerged_local_seed" rev-parse HEAD)
git -C "$unmerged_local_seed" reset -q --hard HEAD^1
late_worktree="$unmerged_local_fixture/worktree"
git -C "$unmerged_local_seed" worktree add -q "$late_worktree" chore/late-test
printf 'after merge\n' >> "$late_worktree/file.txt"
git -C "$late_worktree" commit -q -am "feat: unmerged local work"
late_tip=$(git -C "$late_worktree" rev-parse HEAD)

export STUB_PR_RECORD="$(printf '20\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/late-test\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/20' "$late_merge" "$late_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_late","cwd":"%s"}]' "$late_worktree")"
export STUB_PASEO_AGENTS_JSON="[]"
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
if git -C "$unmerged_local_seed" show-ref --verify --quiet refs/heads/chore/late-test; then
    ok
else
    fail "cleanup deleted a local branch with unmerged commits"
fi
if [ "$(git -C "$late_worktree" rev-parse HEAD)" = "$late_tip" ]; then
    ok
else
    fail "cleanup changed the unmerged local branch tip"
fi
assert_no_archive "cleanup unmerged local branch"
if [ -n "$(git -C "$unmerged_local_seed" ls-remote --heads origin chore/late-test)" ]; then
    ok
else
    fail "cleanup deleted a remote branch before preserving the local workspace"
fi

# --- Cleanup safety: explicit workspace ownership ----------------------------

workspace_identity_fixture="$fixture/workspace-identity"
make_repository "$workspace_identity_fixture"
workspace_identity_seed="$workspace_identity_fixture/seed"
git -C "$workspace_identity_seed" checkout -q -b chore/target-ws
printf 'target work\n' >> "$workspace_identity_seed/file.txt"
git -C "$workspace_identity_seed" commit -q -am "feat: target work"
git -C "$workspace_identity_seed" push -q -u origin chore/target-ws
workspace_target_head=$(git -C "$workspace_identity_seed" rev-parse HEAD)
git -C "$workspace_identity_seed" checkout -q main
git -C "$workspace_identity_seed" merge -q --no-ff chore/target-ws -m "Merge target-ws"
git -C "$workspace_identity_seed" push -q origin main
workspace_target_merge=$(git -C "$workspace_identity_seed" rev-parse HEAD)
git -C "$workspace_identity_seed" reset -q --hard HEAD^1
workspace_target_worktree="$workspace_identity_fixture/target"
git -C "$workspace_identity_seed" worktree add -q "$workspace_target_worktree" chore/target-ws
workspace_other_worktree="$workspace_identity_fixture/other"
git -C "$workspace_identity_seed" worktree add -q -b chore/other-ws "$workspace_other_worktree" HEAD

export STUB_PR_RECORD="$(printf '21\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/target-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/21' "$workspace_target_merge" "$workspace_target_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_other_issue","cwd":"%s"}]' "$workspace_other_worktree")"
export STUB_PASEO_AGENTS_JSON="[]"
rm -f "$paseo_archived"
: > "$paseo_log"

run_at "$workspace_identity_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 21 --verified-sha "$workspace_target_head" \
    --workspace-id wks_other_issue --worktree "$workspace_target_worktree" --main-worktree "$workspace_identity_seed"
assert_exit 1 "cleanup workspace from another issue"
assert_contains "cleanup: blocked=workspace_cwd_mismatch" "cleanup workspace from another issue"
assert_path_exists "$workspace_target_worktree" "cleanup workspace from another issue"
if git -C "$workspace_identity_seed" show-ref --verify --quiet refs/heads/chore/target-ws; then
    ok
else
    fail "cleanup deleted the target branch when the workspace belonged to another issue"
fi
assert_no_archive "cleanup workspace from another issue"

absent_workspace_fixture="$fixture/absent-workspace"
make_repository "$absent_workspace_fixture"
absent_workspace_seed="$absent_workspace_fixture/seed"
git -C "$absent_workspace_seed" checkout -q -b chore/absent-ws
printf 'absent work\n' >> "$absent_workspace_seed/file.txt"
git -C "$absent_workspace_seed" commit -q -am "feat: absent work"
git -C "$absent_workspace_seed" push -q -u origin chore/absent-ws
absent_head=$(git -C "$absent_workspace_seed" rev-parse HEAD)
git -C "$absent_workspace_seed" checkout -q main
git -C "$absent_workspace_seed" merge -q --no-ff chore/absent-ws -m "Merge absent-ws"
git -C "$absent_workspace_seed" push -q origin main
absent_merge=$(git -C "$absent_workspace_seed" rev-parse HEAD)
absent_missing_worktree="$absent_workspace_fixture/missing-worktree"

export STUB_PR_RECORD="$(printf '22\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/absent-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/22' "$absent_merge" "$absent_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_missing","cwd":"%s"}]' "$absent_missing_worktree")"
export STUB_PASEO_AGENTS_JSON="[]"
rm -f "$paseo_archived"
: > "$paseo_log"

run_at "$absent_workspace_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 22 --verified-sha "$absent_head" \
    --workspace-id wks_missing --worktree "$absent_missing_worktree" --main-worktree "$absent_workspace_seed"
assert_exit 1 "cleanup absent workspace worktree"
assert_contains "cleanup: blocked=workspace_ownership_unverifiable" "cleanup absent workspace worktree"
assert_no_archive "cleanup absent workspace worktree"
if git -C "$absent_workspace_seed" show-ref --verify --quiet refs/heads/chore/absent-ws; then
    ok
else
    fail "cleanup deleted a branch whose workspace ownership could not be verified"
fi

# --- Cleanup safety: agent ownership and activity ---------------------------

agent_fixture="$fixture/agents"
make_repository "$agent_fixture"
agent_seed="$agent_fixture/seed"
git -C "$agent_seed" checkout -q -b chore/agent-ws
printf 'agent work\n' >> "$agent_seed/file.txt"
git -C "$agent_seed" commit -q -am "feat: agent work"
git -C "$agent_seed" push -q -u origin chore/agent-ws
agent_head=$(git -C "$agent_seed" rev-parse HEAD)
git -C "$agent_seed" checkout -q main
git -C "$agent_seed" merge -q --no-ff chore/agent-ws -m "Merge agent-ws"
git -C "$agent_seed" push -q origin main
agent_merge=$(git -C "$agent_seed" rev-parse HEAD)
git -C "$agent_seed" reset -q --hard HEAD^1
agent_worktree="$agent_fixture/worktree"
git -C "$agent_seed" worktree add -q "$agent_worktree" chore/agent-ws

export STUB_PR_RECORD="$(printf '23\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/agent-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/23' "$agent_merge" "$agent_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_agent","cwd":"%s"}]' "$agent_worktree")"
export STUB_PASEO_AGENTS_JSON="$(printf '[\n  {\n    "id": "agent-running",\n    "name": "Ongoing work",\n    "status": "running",\n    "cwd": "%s",\n    "workspaceId": "wks_agent"\n  }\n]\n' "$agent_worktree")"
rm -f "$paseo_archived"
: > "$paseo_log"

run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup ongoing agent"
assert_contains "cleanup: blocked=workspace_agent_ongoing" "cleanup ongoing agent"
assert_path_exists "$agent_worktree" "cleanup ongoing agent"
assert_no_archive "cleanup ongoing agent"

export STUB_PASEO_AGENTS_JSON="$(printf '[\n  {\n    "id": "agent-unrelated",\n    "name": "Other work",\n    "status": "idle",\n    "cwd": "%s",\n    "workspaceId": "wks_agent"\n  }\n]\n' "$agent_fixture/elsewhere")"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup unrelated agent"
assert_contains "cleanup: blocked=workspace_agent_unrelated" "cleanup unrelated agent"
assert_path_exists "$agent_worktree" "cleanup unrelated agent"
assert_no_archive "cleanup unrelated agent"

export STUB_PASEO_AGENTS_JSON="$(printf '[{"id":"agent-compact-running","name":"Compact ongoing","status":"running","cwd":"%s","workspaceId":"wks_agent"},{"id":"agent-compact-idle","name":"Compact idle","status":"idle","cwd":"%s","workspaceId":"wks_other"}]\n' "$agent_worktree" "$agent_fixture/elsewhere")"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup compact ongoing agent"
assert_contains "cleanup: blocked=workspace_agent_ongoing" "cleanup compact ongoing agent"
assert_path_exists "$agent_worktree" "cleanup compact ongoing agent"
assert_no_archive "cleanup compact ongoing agent"

export STUB_PASEO_AGENTS_JSON="$(printf '[{"id":"agent-other-workspace","name":"Other workspace","status":"idle","cwd":"%s","workspaceId":"wks_other"}]\n' "$agent_worktree")"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup agent from another workspace"
assert_contains "cleanup: blocked=workspace_agent_other_workspace" "cleanup agent from another workspace"
assert_path_exists "$agent_worktree" "cleanup agent from another workspace"
assert_no_archive "cleanup agent from another workspace"

export STUB_PASEO_AGENTS_JSON='[{"unexpected":true}]'
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$agent_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 23 --verified-sha "$agent_head" \
    --workspace-id wks_agent --worktree "$agent_worktree" --main-worktree "$agent_seed"
assert_exit 1 "cleanup malformed agent state"
assert_contains "cleanup: blocked=workspace_agent_query_failed" "cleanup malformed agent state"
assert_path_exists "$agent_worktree" "cleanup malformed agent state"
assert_no_archive "cleanup malformed agent state"

export STUB_PASEO_AGENTS_JSON="[]"
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
export STUB_PASEO_AGENTS_JSON="[]"

# --- Cleanup safety: repository identity ------------------------------------

identity_fixture="$fixture/identity"
make_repository "$identity_fixture"
identity_seed="$identity_fixture/seed"
git -C "$identity_seed" checkout -q -b chore/identity-ws
printf 'identity work\n' >> "$identity_seed/file.txt"
git -C "$identity_seed" commit -q -am "feat: identity work"
git -C "$identity_seed" push -q -u origin chore/identity-ws
identity_head=$(git -C "$identity_seed" rev-parse HEAD)
git -C "$identity_seed" checkout -q main
git -C "$identity_seed" merge -q --no-ff chore/identity-ws -m "Merge identity-ws"
git -C "$identity_seed" push -q origin main
identity_merge=$(git -C "$identity_seed" rev-parse HEAD)
git -C "$identity_seed" reset -q --hard HEAD^1
identity_worktree="$identity_fixture/worktree"
git -C "$identity_seed" worktree add -q "$identity_worktree" chore/identity-ws

export STUB_PR_RECORD="$(printf '24\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/identity-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/24' "$identity_merge" "$identity_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_identity","cwd":"%s"}]' "$identity_worktree")"
export STUB_PASEO_AGENTS_JSON="[]"
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
if git -C "$identity_seed" show-ref --verify --quiet refs/heads/chore/identity-ws; then
    ok
else
    fail "cleanup deleted a branch when the GitHub repository and origin disagreed"
fi

main_identity_fixture="$fixture/main-identity"
make_repository "$main_identity_fixture"
main_identity_seed="$main_identity_fixture/seed"
git -C "$main_identity_seed" checkout -q -b chore/main-identity
printf 'main identity work\n' >> "$main_identity_seed/file.txt"
git -C "$main_identity_seed" commit -q -am "feat: main identity work"
git -C "$main_identity_seed" push -q -u origin chore/main-identity
main_identity_head=$(git -C "$main_identity_seed" rev-parse HEAD)
git -C "$main_identity_seed" checkout -q main
git -C "$main_identity_seed" merge -q --no-ff chore/main-identity -m "Merge main-identity"
git -C "$main_identity_seed" push -q origin main
main_identity_merge=$(git -C "$main_identity_seed" rev-parse HEAD)
main_identity_worktree="$main_identity_fixture/worktree"
git -C "$main_identity_seed" worktree add -q "$main_identity_worktree" chore/main-identity

foreign_fixture="$fixture/foreign-main"
make_repository "$foreign_fixture"
foreign_seed="$foreign_fixture/seed"

export STUB_PR_RECORD="$(printf '25\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/main-identity\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/25' "$main_identity_merge" "$main_identity_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_main_identity","cwd":"%s"}]' "$main_identity_worktree")"
export STUB_PASEO_AGENTS_JSON="[]"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$main_identity_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 25 --verified-sha "$main_identity_head" \
    --workspace-id wks_main_identity --worktree "$main_identity_worktree" --main-worktree "$foreign_seed"
assert_exit 1 "cleanup main worktree from another repository"
assert_contains "cleanup: blocked=local_main_repository_mismatch" "cleanup main worktree from another repository"
assert_path_exists "$main_identity_worktree" "cleanup main worktree from another repository"
assert_no_archive "cleanup main worktree from another repository"
if [ -n "$(git -C "$main_identity_seed" ls-remote --heads origin chore/main-identity)" ]; then
    ok
else
    fail "cleanup deleted a remote branch before verifying the main worktree repository"
fi

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
if [ -n "$(git -C "$main_identity_seed" ls-remote --heads origin chore/main-identity)" ]; then
    ok
else
    fail "cleanup deleted a remote branch when the explicit main worktree was missing"
fi

# --- Cleanup safety: workspace discovery and incomplete state ---------------

discovery_fixture="$fixture/discovery"
make_repository "$discovery_fixture"
discovery_seed="$discovery_fixture/seed"
git -C "$discovery_seed" checkout -q -b chore/discovery-ws
printf 'discovery work\n' >> "$discovery_seed/file.txt"
git -C "$discovery_seed" commit -q -am "feat: discovery work"
git -C "$discovery_seed" push -q -u origin chore/discovery-ws
discovery_head=$(git -C "$discovery_seed" rev-parse HEAD)
git -C "$discovery_seed" checkout -q main
git -C "$discovery_seed" merge -q --no-ff chore/discovery-ws -m "Merge discovery-ws"
git -C "$discovery_seed" push -q origin main
discovery_merge=$(git -C "$discovery_seed" rev-parse HEAD)
git -C "$discovery_seed" reset -q --hard HEAD^1
discovery_worktree="$discovery_fixture/worktree"
git -C "$discovery_seed" worktree add -q "$discovery_worktree" chore/discovery-ws

export STUB_PR_RECORD="$(printf '29\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/discovery-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/29' "$discovery_merge" "$discovery_head")"
export STUB_PASEO_JSON='[{"workspaceId":"wks_discovery"}]'
export STUB_PASEO_AGENTS_JSON="[]"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$discovery_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 29 --verified-sha "$discovery_head" \
    --worktree "$discovery_worktree" --main-worktree "$discovery_seed"
assert_exit 1 "cleanup incomplete workspace discovery state"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup incomplete workspace discovery state"
assert_path_exists "$discovery_worktree" "cleanup incomplete workspace discovery state"
assert_no_archive "cleanup incomplete workspace discovery state"

export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_discovery","cwd":"%s/"}]' "$discovery_worktree")"
export STUB_PASEO_AGENTS_JSON="$(printf '[\n  {\n    "id": "agent-discovery",\n    "name": "Discovery work",\n    "status": "idle",\n    "cwd": "%s",\n    "workspaceId": "wks_discovery"\n  }\n]\n' "$discovery_worktree")"
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
make_repository "$race_fixture"
race_seed="$race_fixture/seed"
git -C "$race_seed" checkout -q -b chore/race-ws
printf 'race work\n' >> "$race_seed/file.txt"
git -C "$race_seed" commit -q -am "feat: race work"
git -C "$race_seed" push -q -u origin chore/race-ws
race_head=$(git -C "$race_seed" rev-parse HEAD)
git -C "$race_seed" checkout -q main
git -C "$race_seed" merge -q --no-ff chore/race-ws -m "Merge race-ws"
git -C "$race_seed" push -q origin main
race_merge=$(git -C "$race_seed" rev-parse HEAD)
git -C "$race_seed" reset -q --hard HEAD^1
race_worktree="$race_fixture/worktree"
git -C "$race_seed" worktree add -q "$race_worktree" chore/race-ws
git -C "$race_seed" checkout -q -b chore/race-concurrent HEAD
printf 'concurrent work\n' >> "$race_seed/file.txt"
git -C "$race_seed" commit -q -am "feat: concurrent work"
race_concurrent=$(git -C "$race_seed" rev-parse HEAD)
git -C "$race_seed" push -q origin chore/race-concurrent
git -C "$race_seed" checkout -q main

race_git="$fixture/bin/git-race"
real_git=$(command -v git)
cat > "$race_git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\$*" == *"--force-with-lease"* && "\$*" == *"--delete"* ]]; then
    "$real_git" -C "$race_fixture/origin.git" update-ref "refs/heads/chore/race-ws" "$race_concurrent"
fi
exec "$real_git" "\$@"
EOF
chmod +x "$race_git"

export STUB_PR_RECORD="$(printf '26\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/race-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/26' "$race_merge" "$race_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_race","cwd":"%s"}]' "$race_worktree")"
export STUB_PASEO_AGENTS_JSON="[]"
rm -f "$paseo_archived"
: > "$paseo_log"
export GIT_BIN="$race_git"
run_at "$race_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 26 --verified-sha "$race_head" \
    --workspace-id wks_race --worktree "$race_worktree" --main-worktree "$race_seed"
unset GIT_BIN
assert_exit 1 "cleanup remote branch race"
assert_contains "cleanup: blocked=remote_branch_delete_failed" "cleanup remote branch race"
if [ "$(git -C "$race_seed" ls-remote --heads origin chore/race-ws | awk '{ print $1 }')" = "$race_concurrent" ]; then
    ok
else
    fail "cleanup silently deleted a remote branch that changed during verification"
fi

# --- Cleanup safety: unavailable or malformed state -------------------------

malformed_fixture="$fixture/malformed"
make_repository "$malformed_fixture"
malformed_seed="$malformed_fixture/seed"
git -C "$malformed_seed" checkout -q -b chore/malformed-ws
printf 'malformed work\n' >> "$malformed_seed/file.txt"
git -C "$malformed_seed" commit -q -am "feat: malformed work"
git -C "$malformed_seed" push -q -u origin chore/malformed-ws
malformed_head=$(git -C "$malformed_seed" rev-parse HEAD)
git -C "$malformed_seed" checkout -q main
git -C "$malformed_seed" merge -q --no-ff chore/malformed-ws -m "Merge malformed-ws"
git -C "$malformed_seed" push -q origin main
malformed_merge=$(git -C "$malformed_seed" rev-parse HEAD)
git -C "$malformed_seed" reset -q --hard HEAD^1
malformed_worktree="$malformed_fixture/worktree"
git -C "$malformed_seed" worktree add -q "$malformed_worktree" chore/malformed-ws

export STUB_PR_RECORD="$(printf '27\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/malformed-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/27' "$malformed_merge" "$malformed_head")"
export STUB_PASEO_JSON='{"workspaceId": "wks_malformed"}'
export STUB_PASEO_AGENTS_JSON="[]"
rm -f "$paseo_archived"
: > "$paseo_log"
run_at "$malformed_seed" "$root/scripts/workflow/cleanup.sh" execute \
    --pr 27 --verified-sha "$malformed_head" \
    --workspace-id wks_malformed --worktree "$malformed_worktree" --main-worktree "$malformed_seed"
assert_exit 1 "cleanup malformed paseo state"
assert_contains "cleanup: blocked=workspace_query_failed" "cleanup malformed paseo state"
assert_path_exists "$malformed_worktree" "cleanup malformed paseo state"
assert_no_archive "cleanup malformed paseo state"

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
make_repository "$resume_fixture"
resume_seed="$resume_fixture/seed"
git -C "$resume_seed" checkout -q -b chore/resume-ws
printf 'resume work\n' >> "$resume_seed/file.txt"
git -C "$resume_seed" commit -q -am "feat: resume work"
git -C "$resume_seed" push -q -u origin chore/resume-ws
resume_head=$(git -C "$resume_seed" rev-parse HEAD)
git -C "$resume_seed" checkout -q main
git -C "$resume_seed" merge -q --no-ff chore/resume-ws -m "Merge resume-ws"
git -C "$resume_seed" push -q origin main
resume_merge=$(git -C "$resume_seed" rev-parse HEAD)
git -C "$resume_seed" reset -q --hard HEAD^1
resume_worktree="$resume_fixture/worktree"
git -C "$resume_seed" worktree add -q "$resume_worktree" chore/resume-ws

export STUB_PR_RECORD="$(printf '28\x1fMERGED\x1f2026-01-01T00:00:00Z\x1f%s\x1fchore/resume-ws\x1f%s\x1fowner\x1frepo\x1fmain\x1fhttps://example.test/pull/28' "$resume_merge" "$resume_head")"
export STUB_PASEO_JSON="$(printf '[{"workspaceId":"wks_resume","cwd":"%s"}]' "$resume_worktree")"
export STUB_PASEO_AGENTS_JSON="[]"
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
if [ -z "$(git -C "$resume_seed" ls-remote --heads origin chore/resume-ws)" ]; then
    ok
else
    fail "cleanup did not complete the safe remote branch step before the workspace block"
fi

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
