# Architecture tests

This project protects **repository policy invariants**:

- The app targets Windows/WPF and has no startup window.
- Quality-gate settings in `Directory.Build.props` remain enabled.
- Handwritten source contains no unapproved suppressions or generated-code markers.
- Project and nested analyzer configuration cannot silently disable analysis.
- Banned symbols remain active and coupling thresholds remain strict.
- The CI workflow keeps the required, unconditional Windows gates and no-test runs fail.
- Relative documentation links resolve, do not target Git-ignored paths, and do not use local absolute paths.
- `.scratch/` remains ignored.

These are repository-policy checks, not cross-assembly dependency tests. The app is still a single production assembly, so there is no domain/UI/provider boundary to inspect yet.

When a second production assembly or a provider adapter namespace exists, add a dependency test with [ArchUnitNET](https://github.com/TNG/ArchUnitNET) (Apache-2.0, active). The trigger and tool decision are recorded in [ADR-0002](../../docs/adr/0002-static-analysis-and-architecture-enforcement.md). Do not add an architecture-test framework before there is a boundary it can actually verify.
