# Pull request

Authoritative for preparing and publishing a pull request after review convergence. Publication policy lives in [GitHub operations](github-operations.md); merge rules live in [PR merge](pr-merge.md).

## Purpose

Publish a reviewable change with the issue link, acceptance-criteria coverage, exact reviewed commit, real verification evidence, known limitations, and rollback information. The PR is the durable record of why the change exists and what was actually verified.

## Required inputs

- A ready issue and a branch based on current `origin/main`.
- Review approval naming the current head SHA, with blocking findings resolved.
- The final validation results for that SHA.
- The PR template at [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md).

## Entry criteria

- The head commit matches the reviewed commit, or the difference is explicitly re-reviewed.
- The complete required validation suite passed on the head commit.
- The branch is pushed and mergeable with the target branch.
- The PR body can be published without credentials, account data, local absolute paths, or local-only artifact references.

## Procedure

### 1. Confirm the final state

```bash
git fetch origin
git status --short
git rev-parse HEAD
git merge-base --is-ancestor origin/main HEAD
```

If `origin/main` has advanced materially, merge it into the branch, rerun the affected checks, and repeat review for the new head. Do not rewrite reviewed history with a force push.

### 2. Start from the repository template

`gh pr create --template` pre-fills the body from the named file. It does not fetch a template automatically when `--body` is supplied, and API-based creation does not populate repository templates. Use one of these forms:

Interactive:

```bash
gh pr create \
  --template .github/PULL_REQUEST_TEMPLATE.md \
  --base main
```

Non-interactive: copy the template, fill it, and pass the resulting body file:

```bash
cp .github/PULL_REQUEST_TEMPLATE.md "<body-file>"
# Edit the file and replace every placeholder with actual information.
gh pr create \
  --title "<type>: <subject>" \
  --body-file "<body-file>" \
  --base main
```

Do not pass both `--template` and `--body` and assume the template is merged. The body override wins.

### 3. Fill the template with evidence

Include:

- `Closes #<issue>` in the body. GitHub interprets closing keywords only when the PR targets the default branch.
- Summary and rationale.
- Acceptance-criteria coverage, with each criterion marked satisfied, not applicable, or unverified.
- Implementation changes at a level a reviewer can follow.
- The reviewed commit SHA and the review decision.
- Blocking-finding resolution, or "none".
- Actual validation commands or CI runs and their results.
- Known limitations and behavior that was not verified.
- Risk, blast radius, and rollback.
- Quality-gate and public-content checklist results.

Use "not applicable" or "unverified" explicitly. Do not invent a result for a check that did not run.

### 4. Check publication content

Run the checker on the exact title and body before posting:

```bash
bash scripts/check-public-content.sh < "<body-file>"
```

The checker reports a rule, safe file label, and line number without printing the match. Fix the reported line and rerun.

### 5. Push and create the PR

```bash
git push -u origin <branch>
gh pr create --title "<type>: <subject>" --body-file "<body-file>" --base main
```

Use the Conventional Commit style for the title when practical. Do not add labels or reviewers that do not exist. Do not create a GitHub Project item unless the task explicitly asks for one.

### 6. Verify CI

The required check is `build` on `windows-latest`. It runs restore/audit, formatting, build, tests, repository-policy tests, and public-content checks. CodeQL and dependency review are advisory unless the maintainer says otherwise.

- Verify the check runs against the current head SHA.
- If a check fails, fix the cause, commit, and rerun the affected verification.
- If the code changes, repeat the review for the new head and update the reviewed SHA in the body.
- If a check is infrastructure-flaky, retry once, then report the failure rather than claiming success.

The `pull_request` trigger includes `edited`, so a title or body edit is revalidated by CI. That is post-publication detection; run the local checker before editing, not after.

### 7. Keep the PR body current

Update the body when the head changes, a check result changes, or a review finding is resolved. A body edit must also pass the local checker. The body must not describe an earlier commit as the reviewed head.

## Required outputs

- A PR URL with the issue linked.
- A body based on the repository template.
- The exact reviewed commit SHA and review outcome.
- Actual validation evidence and explicit unverified items.
- Risk and rollback information.
- A current required CI result for the head SHA.

## Exit criteria

- The PR is open against `main`.
- The issue is linked with a closing keyword.
- Required checks pass on the current head.
- The reviewed SHA matches the head or a later review covers the difference.
- No blocking review conversation remains unresolved.

## Prohibited actions

- Opening a PR without the template or with placeholder evidence.
- Claiming a check passed without a matching run or command output.
- Treating a build as proof of Windows runtime behavior.
- Publishing credentials, account data, raw logs, local absolute paths, or local-only artifact references.
- Editing the PR body with unvalidated sensitive content and relying on CI to catch it.
- Force-pushing over reviewed history and presenting the result as reviewed.
- Requiring an external contributor to use Paseo or internal agent orchestration.
- Changing merge strategy, branch protection, or required checks as part of the PR.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Code review](code-review.md) and [review remediation](review-remediation.md) for the preceding review.
- [PR merge](pr-merge.md) for the following stage.
- [GitHub operations](github-operations.md) for publication, commits, and local-only artifacts.
- [Quality gates](quality-gates.md) and [Development](../development.md#quality-gates) for validation.
