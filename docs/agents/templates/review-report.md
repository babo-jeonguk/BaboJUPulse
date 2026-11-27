# Review report

<!--
Use this template for a review decision. Return it directly as session output
when that is sufficient for the handoff. Store it under the local-only workspace
only when a separate session needs the report to persist; never make a published
PR depend on that file. Keep sections proportionate: a clean review can be short,
but the reviewed SHA and decision are always required.
-->

## Identity

- **Issue:** #<number> — <title or URL>
- **Repository:** `<owner/name>`
- **Base SHA:** `<full SHA>`
- **Reviewed head SHA:** `<full SHA>`
- **Review round:** <number>
- **Decision:** Approve / Request changes
- **Reviewed range:** `<base>...<head>`

## Acceptance-criteria coverage

| Criterion | Status | Evidence |
| --- | --- | --- |
| <criterion> | Satisfied / Not satisfied / Not applicable / Unverified | <diff, test, command, or CI run> |

## Blocking findings

<!-- Use stable identifiers B1, B2, ... across review rounds. Write "None" when the review has no blocking findings. -->

### B1 — <short title>

- **Severity:** Blocking
- **Location:** `<file>:<line>` or `<precise symbol>`
- **Requirement or rule:** <acceptance criterion, architecture rule, coding standard, or gate policy>
- **Evidence:** <the code, behavior, or missing proof that demonstrates the problem>
- **Impact:** <the failure scenario or why the change cannot be accepted>
- **Expected correction or verification:** <what would resolve the finding>
- **Status:** Open / Resolved / Accepted risk / Escalated

## Non-blocking findings

<!-- Use stable identifiers N1, N2, ... . Write "None" when there are no optional findings. Do not turn a preference into a blocking demand. -->

### N1 — <short title>

- **Severity:** Non-blocking
- **Location:** `<file>:<line>` or `<precise symbol>`
- **Requirement or rule:** <the affected rule, or "No rule; optional improvement">
- **Evidence:** <the observation>
- **Impact:** <why it is worth considering>
- **Expected correction or verification:** <suggested improvement>
- **Status:** Open / Follow-up issue / Accepted / Declined

## Previous findings

<!-- Include this section only for a re-review. Refer to the stable identifiers and the exact reviewed SHA of the previous round. -->

| Finding | Previous status | Current status | Evidence |
| --- | --- | --- | --- |
| B1 | Open | Resolved | <commit, diff, or test> |

## Verification performed

| Check | Command or run | Result | Applies to |
| --- | --- | --- | --- |
| <gate> | `<command>` or `<CI run>` | Pass / Fail / Not run | `<head SHA>` |

- **Working tree during review:** Clean / Dirty and explained
- **Review range reproducible:** Yes / No

## Unverified behavior

- <behavior that could not be verified, and why>
- <platform-specific behavior that was not exercised>

Write "None" when everything material was verified. Do not treat a successful build as proof of Windows runtime behavior.

## Documentation-only follow-up

<!-- Include only when a later delta is claimed under the documentation-only exception. -->

- **Approved implementation SHA:** `<full SHA>`
- **Final PR head SHA:** `<full SHA>`
- **Complete delta:** `<approved>..<final>`
- **Changed files:** <files>
- **Content classification:** Ordinary documentation / Substantive change
- **Documentation validation:** <command or CI run and result>
- **Reason independent re-review was not required:** <explanation>

## Required next action

- <remediate the listed blocking findings and request re-review of the new head, or approve the exact SHA and proceed to the PR stage>

## Notes

- Approval applies only to the reviewed head SHA. A later commit requires review of the affected work, except for the documentation-only exception in [Code review](../code-review.md#7-documentation-only-follow-up-after-approval).
- Do not include credentials, account data, local absolute paths, workspace identifiers, session data, or references to local-only artifacts.
