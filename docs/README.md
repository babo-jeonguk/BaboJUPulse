# Documentation map

Each document has one authoritative responsibility.

| Document | Responsible for |
| --- | --- |
| [README](../README.md) | User-facing overview, requirements, and build entry point |
| [AGENTS](../AGENTS.md) | Agent entry point: invariants and task routing |
| [Product scope](product-scope.md) | Intended capabilities, constraints, and non-goals |
| [Architecture](architecture.md) | Current shape, boundaries, and open decisions |
| [Development](development.md) | Setup, build/run, test execution, and troubleshooting |
| [Coding standards](../CODING_STANDARDS.md) | Acceptable code, architectural constraints, and prohibited practices |
| [Agent operations](agents/README.md) | Map of agent operating procedures |
| [GitHub operations](agents/github-operations.md) | Issues, PRs, comments, commits, publication, and local-only artifacts |
| [Quality gates](agents/quality-gates.md) | Verification, analyzer enforcement, suppressions, gate integrity, and limitations |
| [ADRs](adr/) | Accepted decisions and their rationale |
| [Security](../SECURITY.md) | Vulnerability reporting and secret handling |

## Reading rule

Start at [AGENTS.md](../AGENTS.md) and read only the routed document for the current task. `docs/agents/` holds operating procedures; `CODING_STANDARDS.md` defines acceptable code; `docs/development.md` defines environment and commands; `docs/architecture.md` and the ADRs explain boundaries and decisions. Do not duplicate a rule across documents.
