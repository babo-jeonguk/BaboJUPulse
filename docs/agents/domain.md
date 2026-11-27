# Domain language

Authoritative for discovering, using, and maintaining BaboJUPulse's product vocabulary. The vocabulary itself lives in [GLOSSARY.md](../../GLOSSARY.md). Product intent lives in [Product scope](../product-scope.md); structural decisions live in [Architecture](../architecture.md) and the [ADRs](../adr/); publication policy lives in [GitHub operations](github-operations.md).

## Purpose

Keep one precise language across issue specifications, architecture, code, tests, review, and user-facing text. A shared vocabulary prevents a spec from saying "account" while the code says "profile", and prevents an unverified provider capability from becoming an assumed domain fact.

This is a language discipline, not a mandatory Domain-Driven Design layer. Do not introduce aggregates, repositories, bounded contexts, or domain abstractions unless a concrete requirement justifies them.

## Where the language lives

- [GLOSSARY.md](../../GLOSSARY.md) is the single authoritative vocabulary for product-specific terms.
- Product capabilities and provider limits remain in [Product scope](../product-scope.md).
- Module, interface, seam, and dependency rules remain in [Architecture](../architecture.md) and [Coding standards](../../CODING_STANDARDS.md).
- Consequential decisions with real alternatives remain in [ADRs](../adr/).

Do not create a second glossary, a terminology section in a stage document, or a per-feature vocabulary file.

## When to consult and use it

| Stage | Required use |
| --- | --- |
| Specification | Identify the domain terms the issue depends on. Use the canonical term. Resolve a material ambiguity before implementation. |
| Workspace and implementation | Use the canonical term in names, messages, and tests. Check that a new concept is established rather than invented. |
| Review | Check that the implementation and tests use the same term as the issue and glossary. Treat a silent synonym or an assumed relationship as a review finding when it affects behavior. |
| Documentation freshness | Update the glossary when the work establishes or changes a domain concept. Do not wait for a separate domain stage. |

A domain clarification that affects correctness belongs before or during implementation, not in the final documentation review. A naming preference that does not affect behavior can wait for the documentation review or a follow-up.

## Using the language

- Use the canonical term in issue acceptance criteria, architecture descriptions, type and member names, test names, error text, and review findings.
- Treat `_Avoid_` entries as discouraged synonyms, not as forbidden identifiers in an established external API. If an external provider uses a different word, keep the provider's term inside its adapter and map it to the canonical term at the boundary.
- Prefer a relationship the source actually establishes. Do not add "every account has a quota" or "a banked reset belongs to a window" to make the model look complete.
- Represent missing data explicitly. An unavailable quota field is not zero, and an unknown reset time is not a sentinel timestamp.
- Keep unresolved questions visible in the issue or the glossary's unresolved section. Do not encode a guess as a domain fact.

## Resolving an ambiguity

1. State the competing meanings and where they appear: issue, code, test, ADR, or provider documentation.
2. Check the authoritative sources: product scope, architecture, ADRs, tracked code and tests, and verified provider documentation.
3. Prefer the term and relationship that the established sources support. If they conflict, do not silently choose one.
4. If the ambiguity changes observable behavior, acceptance criteria, a provider capability, or a durable contract, stop and ask the maintainer.
5. Record the resolution in the issue. Update the glossary in the same change when the term is established.

A discussion that only clarifies wording can be resolved in the issue. A decision that is hard to reverse, surprising without context, and the result of a real trade-off needs an ADR. A glossary entry alone does not justify an ADR.

## When to update the glossary

Add or change a term when:

- The work establishes a new product-specific concept that future specifications will need.
- A canonical term changes and existing text would otherwise drift.
- A previously unresolved relationship becomes established.
- A discouraged synonym is causing repeated confusion.

Do not add a term when:

- It is a general programming concept, a library name, a class name, or a UI control that has no product-specific meaning.
- It is a proposal that the maintainer has not accepted.
- It is an implementation detail such as a cache, a retry policy, or a parser.
- It merely restates a capability already clear from product scope.

Keep the definition to one or two sentences. Define what the concept is, not how to implement it. Bold related glossary terms and state the relationship in plain language.

## Established knowledge and proposals

- **Established**: supported by product scope, an accepted ADR, tracked behavior, or verified provider documentation.
- **Proposed**: a useful term under discussion but not yet supported. Keep it in the issue or a draft section, not as an accepted glossary entry.
- **Unresolved**: a relationship that the sources do not settle. Record it under "Unresolved language" with the competing possibilities and the decision needed.

Do not promote a proposal to established language merely because code already uses the word.

## Conflicts

When the glossary conflicts with code, an issue, or an ADR:

1. Do not edit one side silently to match the other.
2. Identify which source is authoritative for the disputed point. An ADR owns an accepted structural decision; an issue owns its acceptance criteria; the glossary owns terminology, not behavior.
3. Surface the conflict in the issue and, when behavior is affected, in review.
4. Resolve it through the existing change, or escalate when it changes scope, a contract, or a provider capability.

An implementation agent may correct an obvious naming drift within its issue. It may not redefine an accepted domain relationship, rewrite acceptance criteria, or change a provider contract to match its code.

## Maintainer involvement

Ask the maintainer before:

- Establishing a domain relationship that is not supported by product scope, an ADR, tracked behavior, or verified provider documentation.
- Changing the meaning of an established term in a way that affects behavior or a public contract.
- Resolving a conflict between an ADR and a proposed requirement.
- Adding a term that implies a provider capability the project has not verified.
- Creating an ADR for a domain decision.

A maintainer decision that changes product scope or an accepted architecture decision follows the normal issue and ADR process; it is not recorded only in the glossary.

## Required outputs

- Canonical terms used in the issue, implementation, tests, and review.
- Glossary updates for established or changed concepts.
- An explicit unresolved note for a relationship the sources do not settle.
- A maintainer decision when a domain question affects scope, behavior, or a provider capability.

## Prohibited actions

- Inventing a provider capability, quota relationship, or reset rule to complete the glossary.
- Adding implementation detail, class design, or behavioral specification to the glossary.
- Silently choosing one meaning when the issue, code, and ADR disagree.
- Treating a proposal as established because it appears in code.
- Requiring a new ADR for every term or turning this guidance into a mandatory standalone workflow stage.

## References

- [GLOSSARY.md](../../GLOSSARY.md) for the vocabulary.
- [Product scope](../product-scope.md) for intended capabilities and provider limits.
- [Architecture](../architecture.md) and [ADRs](../adr/) for structural decisions.
- [Coding standards](../../CODING_STANDARDS.md) for naming and type rules.
- [Development workflow](development-workflow.md) for stage transitions.
- [Code review](code-review.md) and [PR merge](pr-merge.md) for review and documentation freshness.
- Upstream guidance: [mattpocock/skills domain modeling](https://github.com/mattpocock/skills/tree/main/skills/engineering/domain-modeling) and [glossary format](https://github.com/mattpocock/skills/blob/main/skills/engineering/domain-modeling/GLOSSARY-FORMAT.md).
