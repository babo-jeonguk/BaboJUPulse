# Issue tracker

Authoritative for creating, triaging, and maintaining GitHub Issues as the task-management and specification surface. Label meanings live in [Triage labels](triage-labels.md); publication policy lives in [GitHub operations](github-operations.md).

## Purpose

Make each issue the authoritative statement of the problem, scope, acceptance criteria, and verification for its implementation. A template completion is not proof of readiness.

## Required inputs

- A problem, defect, idea, or research question.
- Any public references needed to understand it.
- The relevant canonical terms from [GLOSSARY.md](../../GLOSSARY.md) and [domain guidance](domain.md) when the work affects product behavior.
- The linked repository, confirmed with `gh repo view --json nameWithOwner`.
- For an implementation specification, enough evidence to state behavior and acceptance criteria.

## Entry criteria

- The work is not already tracked by an open issue or pull request.
- The target repository is `babo-jeonguk/BaboJUPulse`.
- The content can be published without credentials, account data, local absolute paths, or local-only artifacts.

## Procedure

### 1. Search first

Use the `gh` CLI from the repository clone:

```bash
gh issue list --state open --search "<keywords>"
gh issue list --state all --search "<keywords>"
```

Read related issues and pull requests before proposing duplicate work. If a closed issue is still relevant, reopen it or link the new issue to it rather than duplicating history.

### 2. Choose the right template

- **Bug report**: current behavior, expected behavior, reproduction, version, environment, sanitized evidence, and regression information where available. This is a problem report, not a design document.
- **Feature request**: user problem, desired behavior, expected benefit, constraints, and optional references. Ordinary users are not asked for architectural designs.
- **Implementation specification**: problem and objective, verified references, behavioral requirements, constraints, edge cases and failure behavior, out-of-scope items, implementation slices, acceptance criteria, verification requirements, and dependencies. This is the internal development contract.
- **Technical research**: research question, motivation, required evidence, alternatives, constraints, deliverable, and completion criteria.

Use GitHub Issue Forms for these templates. The web UI disables blank issues; when none of the forms fits, create a plain issue with `gh issue create` and a self-contained body, and say why the forms did not fit.

### 3. Draft the issue

Do reference-first research when the task depends on an external API, an unfamiliar library, Windows-specific behavior, a security-sensitive operation, or an architectural decision. Verify current primary sources and record the references and conclusions in the issue; do not rely on an unverified recollection.

Start from the form or a self-contained body. For an implementation specification:

- State the observable behavior, not only the desired code shape.
- Use the canonical domain term and state any material ambiguity that must be resolved before implementation.
- Give every acceptance criterion a verification method.
- Name explicit out-of-scope items.
- Record dependencies and blockers.
- Keep implementation slices small enough to verify independently.
- Link public references. Do not require a separate implementation-plan document when the issue can contain the specification.
- Keep the issue self-contained. Do not depend on a local handoff artifact for the specification.

### 4. Check publication content before posting

There is no server-side pre-publication guard for an issue. Run the local checker on the exact title and body:

```bash
{ printf '%s\n\n' "<clear title>"; cat "<body-file>"; } \
  | bash scripts/check-public-content.sh
```

The checker reports only a rule, safe file label, and line number. Fix the reported line; do not paste the matching text into a comment while investigating.

### 5. Create and label

```bash
gh issue create \
  --title "<clear title>" \
  --body-file "<body-file>" \
  --label "needs-triage"
```

Add a work-type label only when it is already known and exists. Do not invent labels in a template or command. The triage step assigns the work type, functional area, and priority.

### 6. Triage to readiness

A maintainer or an explicitly delegated triage agent:

1. Confirms the problem and the affected area.
2. Confirms or changes exactly one work type (a form may pre-apply an unambiguous one) and assigns at least one functional area.
3. Assigns one priority when the issue is ready to schedule.
4. Removes `needs-triage`.
5. Applies `ready-for-agent` when the issue is fully specified for implementation by an agent, or `ready-for-human` when it needs human judgment or manual work.
6. Leaves the issue in `needs-info` or `blocked` when it is not ready.

Readiness requires all of the following:

- One work type, at least one functional area, and one priority label are applied.
- The problem or objective is unambiguous.
- Acceptance criteria are observable and testable.
- Relevant domain terms are canonical, and a material ambiguity is resolved or explicitly blocking.
- Scope and out-of-scope items are explicit.
- Constraints, failure behavior, and important edge cases are stated.
- Dependencies are known and satisfied or explicitly blocking.
- Verification requirements are stated.
- No unresolved question requires a maintainer decision.
- The issue does not depend on inaccessible local artifacts.

An implementation-specification form that is filled in but has unresolved questions remains in triage. Do not apply a ready label merely because a template was completed.

### 7. Maintain the issue

- Add evidence and decisions as comments; keep the specification in the body current.
- Use native issue dependencies or a `Blocked by: #<n>` line when a dependency is unresolved.
- When scope changes, update acceptance criteria through the maintainer decision process, not silently in the implementation.
- Remove `ready-for-agent` or `ready-for-human` when implementation starts with a linked PR, when the scope changes, or when the issue closes. A readiness label must not remain on a closed issue.
- Close when the work is complete, rejected, duplicated, or no longer relevant.

## Lifecycle handling

| Situation | Action |
| --- | --- |
| Duplicate | Remove any readiness label, add `duplicate`, comment with the canonical issue, and close. Preserve the historical classification. |
| Incomplete or unclear | Add `needs-info`, comment with the exact missing information, and keep it open. Remove `needs-info` when the reporter supplies it. |
| Blocked | Add `blocked`, record the blocker and its issue or external dependency. Remove `blocked` and re-triage when the blocker closes. |
| Rejected as not actionable or not a repository issue | Remove any readiness label, add `invalid`, explain why, and close. |
| Rejected as intentionally out of scope | Remove any readiness label, add `wontfix`, explain why, and close. |
| Question or clarification | Use `question`; answer it, then close unless it produced actionable work. Remove any readiness label before closing. |
| Completed | Remove `ready-for-agent` or `ready-for-human`, then close the issue through the merged PR's closing keyword or manually with a merge reference. Do not add a redundant completed label. |

Closing an issue removes any readiness label because it no longer describes the issue's current state. Work type, area, priority, and disposition labels remain historical classification.

## Required outputs

- An issue number and URL.
- Work type, functional area, and priority labels where applicable.
- At most one lifecycle label: `needs-triage`, `needs-info`, `blocked`, `ready-for-agent`, or `ready-for-human`. A closed issue has no readiness label; an in-progress issue may also have none after the readiness label is removed.
- A body that states the acceptance criteria and verification for implementation work.
- A closing reference when the issue is resolved.

## Exit criteria

- The issue is closed with a recorded reason and no readiness label remains, **or**
- The issue is open, correctly labelled, and either ready or explicitly waiting on information, a dependency, or maintainer judgment.

## Prohibited actions

- Filing into another repository or assuming a fork's upstream is the target.
- Creating a duplicate without searching existing issues and pull requests.
- Asking an ordinary bug reporter for an architectural design or implementation plan.
- Marking an issue ready without testable acceptance criteria.
- Using a label that does not exist in the repository.
- Publishing credentials, account data, raw provider responses, local absolute paths, or local-only artifact references.
- Deleting or renaming a label with historical usage without checking its usage and preserving the classification.
- Inventing a domain term or provider relationship to complete a specification.
- Requiring a separate local report to understand an issue.

## References

- [Triage labels](triage-labels.md) for label meanings, category cardinality, and label synchronization.
- [Domain guidance](domain.md) and [GLOSSARY.md](../../GLOSSARY.md) for canonical terminology.
- [GitHub operations](github-operations.md) for publication, commits, PRs, local-only artifacts, and artifact ownership.
- [Development workflow](development-workflow.md) for stage transitions.
- [Coding standards](../../CODING_STANDARDS.md) and [quality gates](quality-gates.md) for implementation requirements.
- GitHub documentation: [issue and pull request templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests), [issue forms syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms), and [linking a pull request to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue).
