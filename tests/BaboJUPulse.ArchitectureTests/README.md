# Architecture tests

This project currently protects **repository and configuration invariants**:

- The app targets Windows/WPF and has no startup window.
- Quality-gate settings in `Directory.Build.props` remain enabled.
- The CI workflow keeps the required Windows gates.
- Analyzer configuration keeps the selected rules and banned symbols.
- Relative documentation links resolve.
- `.scratch/` remains ignored.

These are configuration checks, not cross-assembly dependency tests. The app is still a single production assembly, so there is no domain/UI/provider boundary to inspect yet.

When a second production assembly or a provider adapter namespace exists, add a dependency test with [ArchUnitNET](https://github.com/TNG/ArchUnitNET) (Apache-2.0, active). The trigger and tool decision are recorded in [ADR-0002](../../docs/adr/0002-static-analysis-and-architecture-enforcement.md). Do not add an architecture-test framework before there is a boundary it can actually verify.
