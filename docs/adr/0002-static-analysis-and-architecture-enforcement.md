# ADR-0002: Static analysis and architecture enforcement

- **Status:** Accepted
- **Date:** 2026-11-27
- **Deciders:** Maintainer

## Context

The foundation has a WPF host shell, no product behavior, and no second production assembly. The goal is to catch recurring defects with tools that are reliable now, without installing a large analyzer suite or inventing architecture that does not exist.

The review asked for coverage of architectural dependencies, cycles, coupling, complexity, large types and methods, unsafe APIs, UI-thread blocking, async correctness, resource leaks, exception handling, duplication, and security-sensitive operations.

## Decision

### Adopted now

- Keep the built-in .NET analyzers at `AnalysisLevel=latest-recommended` with warnings as errors.
- Enable a focused set of built-in rules at error severity:
  - `CA1001`, `CA1063`, `CA1816`, `CA2000`, `CA2213` for disposable ownership.
  - `CA1031`, `CA2201` for exception handling.
  - `CA1849`, `CA2012`, `CA2016` for async correctness and cancellation.
  - `CA1502` for cyclomatic complexity at the analyzer default.
  - `CA1506` with explicit thresholds: 40 referenced types for a type and 20 for a method.
  - `CA1002`, `CA1819` for collection exposure; `CA1310` for string comparison correctness.
- Add `Microsoft.CodeAnalysis.BannedApiAnalyzers` 5.6.0 (MIT, maintained in `dotnet/roslyn`) with a small `BannedSymbols.txt`:
  - Blocking waits and sleeps: `Thread.Sleep`, `Task.Wait*`, `Task<T>.Result`, `TaskAwaiter.GetResult`.
  - Blocking the WPF dispatcher: `Dispatcher.Invoke`.
  - TLS validation bypass.
  - Arbitrary command strings through `Process.Start(string)`.
- Keep repository/configuration tests for the no-startup-window rule, quality-gate settings, CI gates, analyzer configuration, and documentation links.

### Deferred with a trigger

- **ArchUnitNET** (`TngTech.ArchUnitNET`, Apache-2.0, active) becomes the dependency-test tool when a second production assembly or a provider-adapter namespace exists. It will enforce:
  - Domain code does not reference WPF, Windows interop, HTTP, or provider SDK namespaces.
  - UI code does not reference provider-specific namespaces.
  - Provider adapters do not reference UI namespaces.
  - No namespace-level cycles.
  - Cross-assembly dependency direction.
- **Microsoft.VisualStudio.Threading.Analyzers** (MIT, active) is a candidate when async UI code lands. It adds `VSTHRD` rules for `async void`, unobserved tasks, and async delegates. The current code has no async behavior, so the package would add maintenance without signal.
- **Duplication and large-method detectors** are deferred. The codebase is too small to distinguish a real recurring pattern from incidental similarity. Revisit after a repeated failure or when a production feature has enough code to make the signal meaningful.

### Not adopted

- **SonarAnalyzer.CSharp**: the package uses the Sonar Source-Available License v1.0, not an OSI license, and its broad rule set overlaps the built-in analyzers. The licensing and maintenance cost is not justified for this project.
- **NetArchTest**: the latest release is 1.3.2 (May 2021) and the repository has not had meaningful activity since 2024. ArchUnitNET is the better-maintained choice when architecture tests are needed.
- **Roslynator.Analyzers** and **Meziantou.Analyzer**: both are active and permissively licensed, but their broad rule sets overlap the selected built-in rules. Adding them now would trade signal for noise and another upgrade surface.
- Enabling every `CA` rule. Many rules are context-dependent or duplicate CodeQL. The selected set is reviewed when a recurring defect appears.

## Consequences

### Positive

- Blocking waits, dispatcher blocking, TLS bypass, and arbitrary command strings fail the build.
- Complexity and coupling have a real threshold instead of a nominal rule.
- The quality-gate configuration is protected by tests, so a feature PR cannot silently remove formatting, build, or test gates.
- The tool decision and deferred triggers are recorded; future work does not re-litigate the analyzer suite.

### Negative

- `BannedSymbols.txt` and `CodeMetricsConfig.txt` must be maintained when a legitimate exception appears.
- The configured coupling thresholds may require a justified adjustment as the UI grows. That adjustment is a quality-gate change under `CODING_STANDARDS.md`.
- The build is slightly slower because of the additional analyzer package.
- Architecture boundaries remain manual until a second production assembly exists.

### Follow-up

- Add ArchUnitNET when the first domain/application assembly or provider adapter namespace is created.
- Re-evaluate the async analyzer package when the first non-trivial async UI flow lands.
- Review `BannedSymbols.txt` when Windows interop or provider CLI integration is designed; a legitimate need must be documented rather than silently removed.
- Keep CodeQL advisory until its signal is stable, then decide whether to make it a required check.

## References

- [Microsoft.CodeAnalysis.BannedApiAnalyzers 5.6.0](https://www.nuget.org/packages/Microsoft.CodeAnalysis.BannedApiAnalyzers/5.6.0) — MIT, published July 2026, source in [`dotnet/roslyn`](https://github.com/dotnet/roslyn/tree/main/src/RoslynAnalyzers/Microsoft.CodeAnalysis.BannedApiAnalyzers).
- [CA1502](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1502) and [CA1506](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1506) — thresholds and configuration.
- [TngTech.ArchUnitNET 0.13.5](https://www.nuget.org/packages/TngTech.ArchUnitNET/0.13.5) — Apache-2.0, active.
- [NetArchTest.Rules 1.3.2](https://www.nuget.org/packages/NetArchTest.Rules/1.3.2) — MIT, latest release May 2021.
- [Microsoft.VisualStudio.Threading.Analyzers 18.12.1](https://www.nuget.org/packages/Microsoft.VisualStudio.Threading.Analyzers/18.12.1) — MIT, active.
- [SonarAnalyzer.CSharp 10.37.0.15768](https://www.nuget.org/packages/SonarAnalyzer.CSharp/10.37.0.15768) — Sonar Source-Available License v1.0.
- [.NET code analysis overview](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview).
