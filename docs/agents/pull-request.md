# Pull request

Authoritative for preparing and publishing a pull request after review convergence. Publication policy lives in [GitHub operations](github-operations.md); merge rules and documentation freshness live in [PR merge](pr-merge.md); the documentation-only review exception lives in [Code review](code-review.md#7-documentation-only-follow-up-after-approval).

## Purpose

Publish a reviewable change with the issue link, a Summary that shows the shape of the change, acceptance-criteria coverage, the exact reviewed implementation commit, the final head and any documentation-only delta, real verification evidence, known limitations, and a proportionate Merge Danger assessment. The PR is the durable record of why the change exists and what was actually verified.

## Required inputs

- A ready issue and a branch based on current `origin/main`.
- Review approval naming the approved implementation SHA, with blocking findings resolved.
- The final PR head SHA and, when it differs, the complete documented delta.
- The final validation results for the final head.
- Canonical domain terms from [GLOSSARY.md](../../GLOSSARY.md) for the Summary and acceptance-criteria coverage.
- The PR template at [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md).

## Entry criteria

- The final head matches the approved implementation SHA, or the difference is a documentation-only delta recorded under [Code review](code-review.md#7-documentation-only-follow-up-after-approval).
- The complete required validation suite passed on the final head.
- Documentation validation passed for the final head when documentation changed.
- The branch is pushed and mergeable with the target branch.
- The PR body can be published without credentials, account data, local absolute paths, workspace identifiers, or local-only artifact references.

## Procedure

### 1. Confirm the final state

```bash
scripts/workflow/validate.sh range --base <approved-sha> --head <final-head-sha>
git status --short
git merge-base --is-ancestor origin/main HEAD
```

Record these values separately:

- The approved implementation SHA.
- The current final head SHA.
- The complete delta between them.

If `origin/main` has advanced materially, merge it into the branch, rerun the affected checks, and repeat review for the new head. Do not rewrite reviewed history with a force push. Do not classify a base merge as a documentation-only delta merely because the resulting commits look documentation-heavy.

### 2. Start from the repository template

`gh pr create --template` pre-fills the body from the named file. It does not fetch a template automatically when `--body` is supplied, and API-based creation does not populate repository templates.

The default procedure uses a body file copied from the template so the exact text can be checked before posting:

```bash
cp .github/PULL_REQUEST_TEMPLATE.md "<body-file>"
# Edit the file and replace every placeholder with actual information.
```

Interactive use of `gh pr create --template .github/PULL_REQUEST_TEMPLATE.md` is acceptable only if you save the completed body and run the checker before submitting. Do not pass both `--template` and `--body` and assume the template is merged; the body override wins.

### 3. Write the Summary as the smallest sufficient representation

The Summary should make the essential change clear with the smallest representation that fits the change, not a long restatement of the diff. Choose one or a few of these:

- Pseudocode for changed logic or an algorithm.
- A call tree for runtime control flow.
- A component tree for UI structure and state boundaries.
- A shallow file tree for responsibility or layout changes.
- A diff sketch when the surrounding shape already exists.
- A Mermaid diagram for component interaction, control flow, or data flow.
- A compact control-flow or data-flow illustration.

Do not use every technique. A trivial change may need only a short paragraph. Place each visual next to the text it supports, and include only the calls, files, states, props, or boundaries that answer the reviewer's question.

Examples:

```text
on(merge)
  verify final head
  verify documentation review
  merge with --match-head-commit
  verify remote and local cleanup
```

```diff
 docs/agents/
   development-workflow.md
   pull-request.md
+  pr-merge.md      # owns freshness review and cleanup
```

Keep implementation detail in "Implementation changes" and avoid duplicating the same information in both sections.

### 4. Fill the template with evidence

Include:

- `Closes #<issue>` in the body. GitHub interprets closing keywords only when the PR targets the default branch.
- A Summary using the smallest sufficient representation.
- Acceptance-criteria coverage, with each criterion marked satisfied, not applicable, or unverified.
- Implementation changes at a level a reviewer can follow without repeating the Summary.
- The approved implementation commit SHA and the review decision.
- The final PR head SHA.
- The documentation-only delta after approval, with changed files, or "none".
- The documentation validation result and the reason independent re-review was not required for a documentation-only delta.
- Blocking-finding resolution, or "none".
- Actual validation commands or CI runs and their results.
- Known limitations and behavior that was not verified.
- The Merge Danger assessment.
- The documentation freshness review record.
- Quality-gate and public-content checklist results.

Use "not applicable" or "unverified" explicitly. Do not invent a result for a check that did not run.

### 5. Assess Merge Danger

Classify the change by reversibility, not size or overall risk.

**Two-way door:** A change that can be reversed at relatively low cost without significant permanent consequences. Ordinary UI changes, documentation updates, and isolated implementation improvements usually fit.

**One-way door:** A change that is difficult, costly, or impossible to reverse after merging, deploying, or executing. Destructive data migrations, incompatible persistent configuration changes, irreversible external operations, and incompatible public contracts usually fit.

A large code change may be reversible; a small migration may not be. Reversibility is also distinct from overall risk: a reversible change can still introduce serious defects or security problems.

Record:

- Door classification and the reason.
- Blast radius.
- Relevant failure scenarios.
- Mitigation measures.
- Rollback or recovery strategy.
- Whether a maintainer decision is required.

For a one-way door, identify the irreversible consequence, explain why an ordinary Git revert is insufficient, and document the safeguards, compatibility measures, recovery plan, or migration strategy. Escalate the decision to the maintainer before merging. Do not assume that a Git revert can recover deleted data, reverse external side effects, or restore compatibility after a release.

For a two-way door, keep the assessment proportionate to the actual risk. A trivial documentation change does not need an elaborate failure analysis.

### 6. Run documentation validation when documentation changed

```bash
scripts/workflow/validate.sh docs
```

This runs `scripts/test-check-documentation.sh`, `scripts/check-documentation.sh`, `scripts/test-public-content.sh`, and `scripts/check-public-content.sh --tracked`. The checker validates relative links, heading fragments, Git-ignored targets, local absolute paths, table shape, fenced-code closure, and public-content policy without building the application. The detailed policy is in [Quality gates](quality-gates.md#documentation-validation); commands and troubleshooting are in [Development](../development.md#documentation-validation).

### 7. Check publication content

Run the checker on the exact title and body before posting:

```bash
{ printf '%s\n\n' "<type>: <subject>"; cat "<body-file>"; } \
  | bash scripts/check-public-content.sh
```

The checker reports a rule, safe file label, and line number without printing the match. Fix the reported line and rerun. Do not include local worktree paths, Paseo workspace identifiers, agent session data, or references to local-only artifacts. Use the issue number, branch name, and commit SHA as shareable identifiers.

### 8. Push and create the PR

```bash
git push -u origin <branch>
gh pr create --title "<type>: <subject>" --body-file "<body-file>" --base main
```

Use the Conventional Commit style for the title when practical. Do not add labels or reviewers that do not exist. Do not create a GitHub Project item unless the task explicitly asks for one.

### 9. Verify CI

The required check is `build` on `windows-latest`. It runs restore/audit, formatting, build, tests, repository-policy tests, and public-content checks. CodeQL and dependency review are advisory unless the maintainer says otherwise.

The separate `documentation` workflow runs the documentation checker, its synthetic tests, the public-content tests, and the workflow-script tests. It is not currently a branch-protection required check; the merge procedure still requires its result on the final head. Do not add path filters that could leave a required check pending.

Use the read-only merge inspection to confirm the mechanical PR state before requesting merge:

```bash
scripts/workflow/merge.sh inspect \
  --pr <number> \
  --verified-sha <final-head-sha> \
  --require-check documentation
```

It verifies the PR state, base, draft state, head SHA, mergeability, and named checks. It does not approve the change; review and documentation freshness remain separate.

- Verify each check runs against the final head SHA. A result on an earlier commit does not cover a later documentation-only commit.
- If a check fails, fix the cause, commit, and rerun the affected verification.
- If production code changes, repeat the review for the new head and update the approved SHA.
- If only documentation changes after approval, record the complete documentation-only delta and its validation instead of requesting a full re-review.
- If a check is infrastructure-flaky, retry once, then report the failure rather than claiming success.

The `pull_request` trigger includes `edited`, so a title or body edit is revalidated by CI. That is post-publication detection; run the local checker before editing, not after.

### 10. Keep the PR body current

Update the body when the head changes, a check result changes, a review finding is resolved, or the documentation review outcome becomes known. A body edit must also pass the local checker. The body must not describe an earlier commit as the reviewed head, and it must not omit a later documentation-only delta.

## Required outputs

- A PR URL with the issue linked.
- A body based on the repository template.
- A Summary that uses the smallest sufficient representation.
- The approved implementation commit SHA, final head SHA, and any documentation-only delta with validation.
- Actual validation evidence and explicit unverified items.
- A proportionate Merge Danger assessment.
- A documentation freshness review record.
- A current required CI result for the final head.
- No dependency on a local review report or other temporary artifact.

## Exit criteria

- The PR is open against `main`.
- The issue is linked with a closing keyword.
- Required checks pass on the final head.
- The approved implementation SHA matches the final head, or the difference is a recorded documentation-only delta with passing documentation validation.
- No blocking review conversation remains unresolved.
- The PR body records the documentation review and Merge Danger assessment.

## Prohibited actions

- Opening a PR without the template or with placeholder evidence.
- Claiming a check passed without a matching run or command output.
- Treating a build as proof of Windows runtime behavior.
- Using a `.md` extension to claim a substantive change is documentation-only.
- Omitting the final head or a later documentation-only delta from the review record.
- Publishing credentials, account data, raw logs, local absolute paths, workspace identifiers, or local-only artifact references.
- Editing the PR body with unvalidated sensitive content and relying on CI to catch it.
- Force-pushing over reviewed history and presenting the result as reviewed.
- Requiring an external contributor to use Paseo or internal agent orchestration.
- Changing merge strategy, branch protection, or required checks as part of the PR.
- Making the PR's review record depend on a local report that disappears with the worktree.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Code review](code-review.md), the [review report template](templates/review-report.md), and [review remediation](review-remediation.md) for the preceding review and the documentation-only exception.
- [PR merge](pr-merge.md) for the following stage, documentation freshness, and cleanup.
- [GitHub operations](github-operations.md) for publication, commits, local-only artifacts, and artifact ownership.
- [Quality gates](quality-gates.md#documentation-validation) and [Development](../development.md#documentation-validation) for validation.
- [Development](../development.md#workflow-scripts) for workflow-script usage.
- [GLOSSARY.md](../../GLOSSARY.md) and [domain guidance](domain.md) for canonical terminology.
- Upstream PR guidance: [mattpocock/skills PR skill](https://github.com/mattpocock/skills/blob/main/skills/engineering/pr/SKILL.md).
