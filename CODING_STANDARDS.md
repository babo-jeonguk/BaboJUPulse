# Coding standards

These rules apply to every change in this repository. They are review criteria, not suggestions. Where a rule can be checked by a tool, the tool is the authority; see [Enforcement](#enforcement).

## Enforcement

| Gate | Command | What it catches |
| --- | --- | --- |
| Restore | `dotnet restore BaboJUPulse.slnx` | Package source pinning and transitive NuGet audits |
| Formatting | `dotnet format BaboJUPulse.slnx --verify-no-changes` | Whitespace, using order, style rules configured in `.editorconfig` |
| Build | `dotnet build BaboJUPulse.slnx -c Release -warnaserror` | Compiler errors, nullable warnings, .NET analyzers, code-style analyzers |
| Tests | `dotnet test BaboJUPulse.slnx -c Release` | Behavior, repository, and configuration invariants |
| CI | `.github/workflows/ci.yml` | The same gates on `windows-latest` |
| CodeQL | `.github/workflows/codeql.yml` | Security-relevant data flow and API misuse |
| Dependency review | `.github/workflows/dependency-review.yml` | New dependencies with known vulnerabilities or disallowed licenses |

Warnings are errors. A narrow suppression for a genuine false positive is allowed under [Suppressions and exceptions](#suppressions-and-exceptions). A project-wide analyzer or quality-gate change needs its own PR; weakening a gate needs an ADR and maintainer approval. Suppressing a warning merely to pass CI is prohibited.

### Enforcement coverage

| Area | Automated now | Remaining manual or deferred |
| --- | --- | --- |
| Formatting, style, naming | `dotnet format` and IDE analyzers | Judgment about whether a name or layout is clear |
| Nullability and type safety | Compiler nullable analysis | Avoiding `dynamic`, reflection, and dishonest annotations |
| Blocking waits and selected unsafe APIs | `BannedApiAnalyzers` with `BannedSymbols.txt` | Synchronous I/O that is not in the banned list |
| Async correctness | `CA1849`, `CA2012`, `CA2016`, banned blocking waits | `async void`, fire-and-forget, and ownership of background work |
| Resource ownership | `CA1001`, `CA1063`, `CA1816`, `CA2000`, `CA2213` | Event unsubscription and native handle lifetime |
| Exception handling | `CA1031`, `CA2201` | Error-message quality and the correct boundary for a failure |
| Complexity and coupling | `CA1502` and configured `CA1506` thresholds | God classes, method length, and whether an abstraction earns its keep |
| Architecture boundaries and cycles | Repository configuration tests; compiler rejects project-reference cycles | Namespace cycles and domain/UI/provider dependency direction until separate assemblies exist; then ArchUnitNET |
| Duplication | None | Review; introduce a focused analyzer only after a recurring failure |
| Security | CodeQL, NuGet audit, dependency review, secret scanning, banned TLS/process APIs | Threat modeling, credential handling, and data-flow review |

The table records coverage, not permission to ignore a manual rule. A rule that is not automated is still a review requirement.

## Architecture and separation of concerns

The target boundaries are described in [Architecture](docs/architecture.md). The enforceable rules are:

- Keep domain types free of WPF, Windows interop, HTTP, and provider SDK types. A domain record must be constructible and testable without a UI thread or a network.
- UI hosts render state and forward user intent. They do not poll hardware, parse provider responses, decide quota semantics, or write settings directly.
- Provider adapters translate provider-specific data into the shared quota model. Capabilities that a provider does not support are represented explicitly, not as zero or an empty string.
- Windows interop belongs in a small boundary with a managed interface. Do not spread P/Invoke declarations across view models, collectors, and tests.
- Dependencies point inward: infrastructure and UI may depend on domain/application contracts; domain code must not depend on them.
- One process owns one concern. Do not introduce a background service, IPC channel, or plugin host until a documented requirement needs it.
- Prefer composition at the application entry point. Do not use a static service locator or ambient global state to avoid passing a dependency.

## Dependencies

- Use the .NET base class library first. Add a package only when it removes meaningful risk or work, not to save a few lines.
- Restore only from the source pinned in `NuGet.config`. Do not add a machine-level or user-level package source to make a build work.
- Every new direct package added by a change, rather than an automated version bump, needs a reason in the PR: what it replaces, its maintenance status, its license, and its security surface.
- Pin versions centrally when the first shared package appears. Do not let projects drift to different versions of the same package.
- Do not depend on transitive packages directly. Add the direct reference or use the BCL type.
- Prefer packages with a public source repository, a clear release history, and a compatible license. Do not add a package with an unknown maintainer for a security-sensitive task.
- Do not add a UI framework, MVVM toolkit, logging framework, or dependency-injection container until the existing code shows the need. The first version should be understandable without one.
- Remove unused packages and usings. The `dotnet format` gate removes unused usings; do not leave them for the next reader.

## Naming

Follow the [.NET naming guidelines](https://learn.microsoft.com/dotnet/standard/design-guidelines/naming-guidelines).

- Types, methods, properties, events, and constants use `PascalCase`; parameters and locals use `camelCase`; private fields use `_camelCase`.
- Interfaces start with `I` only when they are implemented by multiple types or cross a boundary. Do not create an interface for a single implementation without a test or boundary reason.
- Async methods end in `Async` and return `Task` or `ValueTask`. Do not use `async void` except for an event handler at the UI boundary.
- Booleans read as predicates: `IsAvailable`, `HasQuota`, `CanRefresh`. Avoid negated names such as `NotReady`.
- Use the product vocabulary consistently: *account*, *provider*, *quota window*, *reset*, *sample*, *metric*. Do not introduce synonyms for the same concept.
- Name tests after the behavior they protect, not the method they call. `ReturnsUnknownWhenProviderDoesNotReportVram` is better than `TestGetVram2`.

## Types and nullability

- Nullable reference types are enabled. Do not use the null-forgiving operator (`!`) unless the invariant is proven immediately above it and a comment explains why.
- Do not use `dynamic`, `object` as a stand-in for a known type, or reflection to avoid designing a type.
- Use strongly typed identifiers and value objects where mixing values would be a bug (account IDs, provider IDs, percentages, byte counts, timestamps).
- Represent optional provider data explicitly. A missing temperature is not `0`; a missing quota reset is not `DateTime.MinValue`.
- Use `decimal` for user-visible percentages or quota amounts only when exact decimal semantics matter. Use `double` for sampled hardware percentages and document the precision.
- Prefer immutable records for snapshots and state passed across boundaries. Use mutable classes only for objects with a lifecycle that requires it.
- Use enums for closed sets. Do not use magic strings or integer codes for metric kinds, provider kinds, or status values.
- Do not expose mutable collections. Return `IReadOnlyList<T>` or an immutable collection from public boundaries.

## Errors and results

- Throw exceptions for programmer errors and unrecoverable invariant violations. Return a result type for expected operational failures such as a provider being unavailable or a sensor not existing.
- Do not catch `Exception` to keep a process alive. Catch the specific exceptions you can handle, at the boundary that can make a decision.
- Do not swallow exceptions. If a failure is intentionally ignored, log it with context or return it to the caller.
- Do not use exceptions for normal control flow.
- Include the operation and the affected account or metric in error messages. Never include tokens, cookies, request bodies, or raw provider responses that may contain account data.
- Preserve the original exception with `innerException` when wrapping. Do not replace a useful stack trace with a new message-only exception.
- Validate arguments at public boundaries. Use `ArgumentNullException.ThrowIfNull` and range checks rather than relying on downstream failures.
- User-facing error text must say what failed and what the user can do next. Do not surface raw exception text in the UI.

## Resources, time, and concurrency

- Dispose every `IDisposable`/`IAsyncDisposable` with `using` or `await using`. Do not rely on finalizers for owned resources.
- Pass `CancellationToken` through asynchronous and long-running work. Do not start fire-and-forget tasks without an owner that observes failures.
- Do not block the UI thread with `.Result`, `.Wait()`, `Thread.Sleep`, or synchronous I/O. Use async APIs and marshal to the dispatcher only when updating UI state.
- Use one long-lived `HttpClient` per provider or a factory-managed client. Do not create a client per request.
- Use `TimeProvider` or inject a clock instead of reading `DateTimeOffset.UtcNow` inside domain logic. Tests must not depend on wall-clock time.
- Use `PeriodicTimer` or a scheduler with an explicit lifetime for polling. Stop and dispose timers when the owner shuts down.
- Unsubscribe events and dispose Windows handles. A tray icon, window hook, or performance counter that is not released leaks beyond the process lifetime.
- Do not use `lock` around awaited work. Use `SemaphoreSlim` or an async-safe primitive when coordination spans an await.
- Bound queues and caches. An unbounded history of samples or provider responses is a memory leak with a friendly name.

## Testability

- Put logic where it can be tested without Windows, WPF, a real network, or a real clock. If a test needs a UI thread, the logic is probably in the wrong layer.
- Test behavior at the lowest layer that can observe it. Do not duplicate the same assertion in an architecture test, a unit test, and a UI test.
- Use fakes at the boundary, not mocks of internal implementation details. A fake provider or fake sensor should implement the same contract as the real adapter.
- Tests must be deterministic. Do not depend on machine CPU load, GPU presence, network availability, locale, or time zone.
- Every bug fix gets a regression test that fails before the fix. Every new behavior gets a test for its success path and its important failure path.
- Do not weaken a test to make it pass. If a test is flaky, fix the source of nondeterminism or quarantine it with an issue and an owner.
- Architecture tests may read repository configuration to protect structural invariants. They must not assert cosmetic details that change with every refactor.

## Duplication and complexity

- Apply the rule of three: tolerate a small duplication until the third real use, then extract the shared concept. Do not extract on the second use merely because the lines look similar.
- Do not create a generic abstraction for one provider, one metric, or one screen. Name the concrete thing first.
- Keep methods short enough to read without scrolling. `CA1502` rejects excessive cyclomatic complexity at its analyzer default. `CA1506` rejects a type with more than 40 referenced types or a method with more than 20; the thresholds are in `CodeMetricsConfig.txt`. These are backstops, not a design goal.
- Avoid god classes, manager classes, and `Helper`/`Utils` dumping grounds. Put behavior on the type that owns the data.
- Do not add layers that only forward calls. A view model that only exposes a service, or a repository that only wraps another repository, is noise.
- Prefer explicit code over reflection, dynamic dispatch, and convention-based magic. The next reader should be able to follow the call path.
- Delete dead code. Do not keep commented-out implementations or unused extension points "for later".
- Duplication is reviewed manually. Do not add a broad analyzer for it until a repeated, concrete failure justifies the maintenance cost; see [ADR-0002](docs/adr/0002-static-analysis-and-architecture-enforcement.md).

## WPF and Windows specifics

- Keep code-behind limited to view wiring. Business rules, collection, quota evaluation, and persistence belong in testable classes.
- Use data binding and commands for state flow. Do not reach into another view's controls or use `FindName` as a dependency mechanism.
- Do not block or busy-wait on the dispatcher. Marshal background results with `Dispatcher.InvokeAsync` and keep the UI responsive.
- Design for per-monitor DPI awareness. Do not hard-code pixel sizes that break at 125%, 150%, or mixed-DPI setups.
- Respect Windows accessibility: keyboard navigation, focus order, accessible names, high-contrast mode, and screen-reader text for icon-only controls.
- Isolate P/Invoke in one namespace. Declare the exact `DllImport`/`LibraryImport` signature, set `SetLastError` where required, and check the result before using a handle.
- Wrap native handles in `SafeHandle` subclasses. Do not store raw `IntPtr` values in fields that outlive the call.
- Do not require elevation by default. If an operation needs elevation, make it explicit, separate, and documented; do not run the tray process elevated.
- Do not write to `HKLM`, system directories, or machine-wide startup locations without explicit user consent. Prefer per-user `HKCU` and `%LOCALAPPDATA%`.
- Do not assume a GPU, sensor, or vendor library exists. Probe capabilities and degrade the affected metric, not the whole application.
- Keep the process alive only while a host owns it. A tray or taskbar host must have a clear shutdown path that releases hooks and icons.

## Security and privacy

- Never commit credentials, tokens, cookies, account IDs, machine names, or local absolute paths. `.scratch/` and local env files are ignored for a reason.
- Store secrets in Windows Credential Manager or a DPAPI-protected store scoped to the current user. Do not invent a custom encryption scheme.
- Do not log request headers, authorization codes, full provider responses, or file paths that identify the user. Redact at the logging boundary.
- Treat provider responses as untrusted input. Validate shapes, bounds, and timestamps before using them.
- Use HTTPS for provider requests. Do not disable certificate validation or add a global callback to bypass it.
- Do not add telemetry, analytics, or crash upload without an explicit product decision and user consent.
- Do not execute downloaded code, load unsigned plugins, or shell out to arbitrary commands. If a provider requires a CLI, invoke a fixed, validated executable path with explicit arguments.
- Report security issues through [SECURITY.md](SECURITY.md), not a public issue.

## Suppressions and exceptions

There are three different actions. Do not treat them as the same:

### Narrow, justified suppression

A line-level or member-level suppression is acceptable only when all of these are true:

1. The diagnostic is a genuine false positive for this exact code, not an inconvenience.
2. The suppression is the narrowest form available: `#pragma warning disable`/`restore` around the specific line, or a member-level `[SuppressMessage]` with `Justification`.
3. The justification is in the code and names the diagnostic and why the code is safe.
4. The PR description records the diagnostic ID, the scope, and the alternative considered.
5. The suppression does not hide a real defect, a failing test, or an unhandled resource leak.

A narrow suppression for a documented false positive is reviewed like any other code. It is not a quality-gate change.

### Project-wide configuration change

Changing `.editorconfig`, `Directory.Build.props`, `BannedSymbols.txt`, an analyzer package, or a CI gate changes the rules for everyone. It needs its own PR with:

- The diagnostic or gate being changed and the concrete problem it causes.
- Evidence that the change does not reduce coverage for an existing class of defect.
- The scope of the change and the files affected.

Strengthening a gate is normal maintenance. Weakening it is not.

### Weakening a quality gate

Removing a banned symbol, lowering a severity, disabling an analyzer, adding project-wide `NoWarn`, disabling nullable, lowering `AnalysisLevel`, excluding files from analysis, or removing a CI step is a weakening. It requires:

- A separate PR, never bundled with a feature or bug fix.
- An ADR that records why the gate is wrong or impractical, what replaces it, and what risk is accepted.
- Maintainer approval.

Suppressing a warning merely to make CI pass is prohibited. If the warning is real, fix the code or change the design. If CI is wrong, fix the gate through the process above.

## Review checklist

- [ ] The change matches the issue and does not add unrequested scope.
- [ ] Domain logic has no WPF, Windows, HTTP, or provider SDK dependency.
- [ ] Provider-specific behavior is behind an adapter and missing capabilities are explicit.
- [ ] Nullable annotations are honest; no unexplained `!` or `null!`.
- [ ] Failures are handled at the right boundary and do not leak secrets.
- [ ] Disposable resources, timers, events, and native handles have an owner and a release path.
- [ ] Tests cover the new behavior and the important failure path.
- [ ] `dotnet format`, build, and tests pass locally; CI passes on the final commit.
- [ ] Any suppression is narrow, justified, and disclosed; no project-wide gate was weakened.
