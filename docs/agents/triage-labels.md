# Triage labels

Authoritative for the meaning and use of repository labels. Issue operations live in [Issue tracker](issue-tracker.md); label changes must also respect [GitHub operations](github-operations.md).

## Purpose

Keep classification useful without turning every issue into a project-management exercise. Labels answer a small number of questions: what kind of work is this, where is it, how urgent is it, and is it ready or closed for a reason?

## Categories

| Category | Cardinality | Labels |
| --- | --- | --- |
| Work type | Exactly one when triaged | `bug`, `enhancement`, `refactor`, `documentation`, `research`, `maintenance` |
| Lifecycle | At most one | `needs-triage`, `needs-info`, `blocked`, `ready-for-agent`, `ready-for-human` |
| Functional area | One or more before ready | `area: system`, `area: providers`, `area: taskbar`, `area: tray`, `area: accounts`, `area: settings`, `area: notifications`, `area: infrastructure`, `area: docs` |
| Priority | Exactly one before ready | `priority: P0`, `priority: P1`, `priority: P2`, `priority: P3` |
| Contribution opportunity | Zero or more | `good first issue`, `help wanted` |
| Cross-cutting concern | Zero or more | `accessibility`, `security` |
| Disposition | At most one | `duplicate`, `wontfix`, `invalid`, `question` |
| Automation | Managed by Dependabot | `.NET`, `dependencies` |

## Work type

| Label | Meaning | Apply when | Remove when |
| --- | --- | --- | --- |
| `bug` | Unexpected or incorrect behavior | The issue reports a defect or regression | Never; change the issue type only through an explicit re-triage |
| `enhancement` | A new product capability or a change to one | The work changes intended product behavior | Never without re-triage |
| `refactor` | Internal restructuring without intended behavior change | The primary purpose is design or maintainability | Never without re-triage |
| `documentation` | Documentation, templates, or contributor guidance | The primary deliverable is written guidance | Never without re-triage |
| `research` | Investigation or evidence gathering | The deliverable is a decision, comparison, or evidence report | Never without re-triage |
| `maintenance` | Repository upkeep, tooling, CI, or policy | The work keeps the project healthy without changing product behavior | Never without re-triage |

Choose the primary purpose. If work genuinely spans types, split it; do not apply two work-type labels to avoid deciding.

## Lifecycle

| Label | Meaning | Apply when | Remove when |
| --- | --- | --- | --- |
| `needs-triage` | New or returned to the maintainer for classification | An issue has not been scoped and labelled | Work type, area, priority, and readiness are decided |
| `needs-info` | Waiting on the reporter or another source for missing information | A specific answer is required before the issue can be scoped | The information arrives and triage resumes |
| `blocked` | Cannot proceed until a dependency is resolved | A linked issue, external dependency, or decision is unresolved | The blocker closes or the maintainer removes the dependency |
| `ready-for-agent` | Scoped for implementation by an agent | All readiness conditions are met and the issue is suitable for delegated implementation | Implementation starts and the issue is linked to a PR, the scope changes, or the issue closes |
| `ready-for-human` | Scoped for human implementation or a human decision | All readiness conditions are met but the work needs judgment, access, or manual verification that should not be delegated | Implementation starts, the scope changes, or the issue closes |

At most one lifecycle label is active. `blocked` replaces a ready state; do not leave a blocked issue marked ready. Removing `blocked` returns the issue to triage before a ready label is reapplied.

A closed issue must not keep `ready-for-agent` or `ready-for-human`. The readiness label describes work still waiting to be done; it is not a historical classification. Preserve the work type, area, priority, and any disposition instead. Remove the readiness label when implementation starts or when any closure path is taken.

There is no separate `triaged` label. An issue is triaged when it has a work type, area, priority, and either a ready label or an explicit waiting state. This avoids a label that duplicates the lifecycle.

`ready-for-agent` does not mean beginner-friendly. It means the specification is complete enough for delegated implementation. Use `good first issue` separately for newcomer-friendly work.

## Functional area

| Label | Owns |
| --- | --- |
| `area: system` | CPU, memory, GPU, temperature, and other hardware sampling |
| `area: providers` | Provider adapters, quota requests, capability modeling, and provider-specific failure behavior |
| `area: taskbar` | Taskbar host and readout surfaces |
| `area: tray` | Tray icon and compact tray popup |
| `area: accounts` | Account identity, credentials, and provider sessions |
| `area: settings` | Settings, configuration, and persistence |
| `area: notifications` | Resource and quota notifications |
| `area: infrastructure` | Build, CI, tests, repository policy, scripts, and tooling |
| `area: docs` | Documentation content, templates, and contributor guidance |

Apply at least one area before an issue becomes ready. Apply more than one only when the change genuinely crosses those boundaries. Do not create a new area label for a single issue without maintainer agreement. Work type describes the deliverable; area describes where it lands. A documentation change may therefore use both `documentation` and `area: docs` without duplicating a category.

Product scope remains in [Product scope](../product-scope.md); architecture boundaries remain in [Architecture](../architecture.md) and the [ADRs](../adr/).

## Priority

| Label | Meaning |
| --- | --- |
| `priority: P0` | Critical: blocks safe use, security response, or publication of the repository |
| `priority: P1` | High: next milestone, a major defect, or a blocking dependency |
| `priority: P2` | Normal: planned work without an immediate deadline |
| `priority: P3` | Low: desirable but not urgent |

Apply exactly one priority when an issue is ready. Do not use priority as a substitute for a blocked dependency. Re-triage priority when the product context changes.

## Contribution and cross-cutting labels

| Label | Meaning | Use |
| --- | --- | --- |
| `good first issue` | Scoped for a first-time contributor | Add only when the issue has a clear starting point, bounded scope, and available guidance. Remove if the scope grows beyond a newcomer-friendly change. |
| `help wanted` | Maintainer welcomes external help | Add when outside contribution is useful. It can coexist with either ready lifecycle label. |
| `accessibility` | Affects accessibility or assistive technology | Add to any work with an accessibility impact, regardless of work type. |
| `security` | Security-sensitive change or report | Add to public hardening work. Do not use it to discuss a vulnerability; follow [SECURITY.md](../../SECURITY.md) and keep the report private. |

## Dispositions

| Label | Meaning | Handling |
| --- | --- | --- |
| `duplicate` | Another issue already tracks the work | Comment with the canonical issue and close. Do not delete the duplicate's history. |
| `wontfix` | Intentionally not being actioned | Explain the product or maintenance reason and close. |
| `invalid` | Not actionable, not reproducible, or not a repository issue | Explain what would make it actionable and close. |
| `question` | A question rather than a scoped implementation task | Answer it and close unless it creates actionable work. Use `needs-info` instead when an actionable issue is missing details. |

At most one disposition is active. A closed issue keeps its disposition and historical labels. Use GitHub's native open/closed state; do not add a `completed` or `done` label.

## Automation labels

`.NET` and `dependencies` describe Dependabot pull requests. Do not apply them manually to issues. If a Dependabot PR needs product review, use the work-type and area labels on the issue it resolves, not on the dependency PR.

## Authority

- Maintainers, or agents explicitly delegated by a maintainer, may change work type, lifecycle, area, priority, and disposition labels.
- Implementation agents must not mark their own issue ready, close their own issue as complete, or resolve their own review findings. They may add evidence comments and update checkboxes.
- External contributors can request classification; repository permissions determine whether they can apply labels.
- A label change that hides a blocker, marks unfinished work ready, or closes a valid report without a reason is a workflow violation, not a formatting choice.

## Readiness labels

The readiness conditions are owned by [Issue tracker](issue-tracker.md#6-triage-to-readiness). Apply `ready-for-agent` or `ready-for-human` only after that gate passes. A completed issue form does not satisfy it by itself.

## Synchronizing actual labels

This document defines meaning; the live repository labels are the operational source. To change or add a label:

1. Inspect current usage with `gh issue list` and `gh pr list`, including closed items.
2. Confirm the label is not redundant with an existing category.
3. Create or edit it with `gh label create` / `gh label edit`.
4. Update this document and any affected templates in the same change.
5. Do not delete or rename a label with historical usage unless the maintainer explicitly approves preserving the history another way.

No label-sync automation is required at the current project size. If automation is added later, it must be deterministic, idempotent, permission-scoped, and must not delete a label that is still in use.

## References

- [Issue tracker](issue-tracker.md) for issue creation, triage, and closure.
- [Development workflow](development-workflow.md) for stage transitions.
- [GitHub operations](github-operations.md) for publication and repository settings.
- GitHub documentation: [managing labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels).
