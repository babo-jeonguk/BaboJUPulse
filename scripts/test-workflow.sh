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

write_stubs() {
    cat > "$gh_stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    "repo view"*)
        printf '%s\n' "${STUB_REPOSITORY:-owner/repo}"
        ;;
    "issue view"*"number,state,title,url,labels"*)
        printf '%s\n' "${STUB_ISSUE_RECORD:-1	OPEN	Test issue	https://example.test/issues/1	ready-for-agent}"
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
        printf '%b' "${STUB_CHECKS:-build	SUCCESS	pass
}"
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
    git -C "$base/seed" remote add origin "$base/origin.git"
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
export STUB_ISSUE_RECORD=$'1\tOPEN\tTest issue\thttps://example.test/issues/1\tready-for-agent'
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

export STUB_ISSUE_RECORD=$'1\tOPEN\tTest issue\thttps://example.test/issues/1\tneeds-triage'
run_at "$workspace_seed" "$root/scripts/workflow/workspace.sh" prepare \
    --issue 1 --branch chore/new-branch
assert_exit 1 "workspace prepare unready"
export STUB_ISSUE_RECORD=$'1\tOPEN\tTest issue\thttps://example.test/issues/1\tready-for-agent'

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

# --- Merge readiness ---------------------------------------------------------

merge_head="1111111111111111111111111111111111111111"
merge_other="2222222222222222222222222222222222222222"
export STUB_REPOSITORY="owner/repo"
export STUB_PR_STATE="MERGED"
export STUB_PR_RECORD=$'7\tOPEN\tfalse\tmain\t1111111111111111111111111111111111111111\tchore/merge-test\towner\trepo\tMERGEABLE\tCLEAN\thttps://example.test/pull/7'
export STUB_CHECKS=$'build\tSUCCESS\tpass\n'
export STUB_CHECKS_EXIT=0
: > "$gh_log"

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head"
assert_exit 0 "merge inspect ready"
assert_contains "merge: head_matches=yes" "merge inspect ready"
assert_contains "merge: result=ready" "merge inspect ready"
assert_not_contains "merge: result=merged" "merge inspect ready"

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_other"
assert_exit 1 "merge inspect mismatch"
assert_contains "merge: head_matches=no" "merge inspect mismatch"
assert_not_contains "merge: result=ready" "merge inspect mismatch"

run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha
assert_exit 2 "merge inspect missing value"

export STUB_CHECKS=$'build\tPENDING\tpending\n'
export STUB_CHECKS_EXIT=8
run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head"
assert_exit 1 "merge inspect pending"
assert_contains "merge: check=build state=PENDING bucket=pending result=fail" "merge inspect pending"

export STUB_CHECKS=$'build\tSUCCESS\tpass\n'
export STUB_CHECKS_EXIT=0
: > "$gh_log"
run_at "$fixture" "$root/scripts/workflow/merge.sh" execute \
    --pr 7 --verified-sha "$merge_head"
assert_exit 0 "merge execute"
assert_contains "merge: result=merged" "merge execute"
if grep -Fq -- "pr merge 7 --merge --match-head-commit $merge_head" "$gh_log"; then
    ok
else
    fail "merge execute did not pass the original verified SHA"
fi
if grep -Fq -- "--delete-branch" "$gh_log"; then
    fail "merge execute deleted a branch without explicit request"
else
    ok
fi

export STUB_PR_RECORD=$'7\tOPEN\tfalse\tmain\t1111111111111111111111111111111111111111\tchore/merge-test\tfork-owner\trepo\tMERGEABLE\tCLEAN\thttps://example.test/pull/7'
run_at "$fixture" "$root/scripts/workflow/merge.sh" inspect \
    --pr 7 --verified-sha "$merge_head" --delete-branch
assert_exit 1 "merge inspect fork deletion"

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
export STUB_PR_RECORD="$(printf '8\tMERGED\t2026-01-01T00:00:00Z\t%s\tchore/cleanup-test\t%s\towner\trepo\tmain\thttps://example.test/pull/8' "$cleanup_merge" "$cleanup_head")"
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

export STUB_PR_RECORD="$(printf '9\tMERGED\t2026-01-01T00:00:00Z\t%s\tchore/dirty-test\t%s\towner\trepo\tmain\thttps://example.test/pull/9' "$dirty_merge" "$dirty_head")"
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

export STUB_PR_RECORD="$(printf '10\tMERGED\t2026-01-01T00:00:00Z\t%s\tchore/cleanup-test\t%s\tfork-owner\trepo\tmain\thttps://example.test/pull/10' "$cleanup_merge" "$cleanup_head")"
rm -f "$paseo_archived"
run_at "$cleanup_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 10 --verified-sha "$cleanup_head"
assert_exit 0 "cleanup fork retention"
assert_contains "cleanup: same_repository=no" "cleanup fork retention"

# The fork scenario uses an already cleaned repository, so the remote branch is
# already absent. Assert the retained-fork path directly with a live branch.
rm -f "$dirty_worktree/untracked.txt"
git -C "$dirty_seed" push -q origin chore/dirty-test
export STUB_PR_RECORD="$(printf '11\tMERGED\t2026-01-01T00:00:00Z\t%s\tchore/dirty-test\t%s\tfork-owner\trepo\tmain\thttps://example.test/pull/11' "$dirty_merge" "$dirty_head")"
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
export STUB_PR_RECORD="$(printf '12\tMERGED\t2026-01-01T00:00:00Z\t%s\tchore/dirty-test\t%s\towner\trepo\tmain\thttps://example.test/pull/12' "$unmerged_sha" "$dirty_head")"
run_at "$dirty_seed" "$root/scripts/workflow/cleanup.sh" inspect \
    --pr 12 --verified-sha "$dirty_head" --branch chore/dirty-test --worktree "$dirty_worktree" --main-worktree "$dirty_seed"
assert_exit 1 "cleanup unverified merge"
assert_contains "cleanup: blocked=merge_commit_not_on_main" "cleanup unverified merge"
if [ -n "$(git -C "$dirty_seed" ls-remote --heads origin chore/dirty-test)" ]; then
    ok
else
    fail "cleanup deleted a remote branch before verifying the merge"
fi

printf 'workflow-script tests: %s passed, %s failed\n' "$passed" "$failed"
if [ "$failed" -ne 0 ]; then
    exit 1
fi
