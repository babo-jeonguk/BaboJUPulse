# BaboJUPulse domain language

The shared vocabulary for BaboJUPulse's product domain. These terms describe intended product concepts; they are not evidence that a capability is implemented. General programming concepts and module-design terms stay out of this glossary; see [Architecture](docs/architecture.md). The operating rules for using and maintaining this language are in [Domain guidance](docs/agents/domain.md).

Use the bold term as the canonical name. The `_Avoid_` list names synonyms that would otherwise fragment specifications, code, tests, and reviews.

## Monitoring

**Metric**:
A system resource that BaboJUPulse can report, such as CPU utilization, RAM usage, GPU utilization, VRAM usage, or a temperature.
_Avoid_: statistic, sensor reading, counter

**Metric Sample**:
A reading of one **Metric** at a point in time, including whether the reading was available and when it was observed.
_Avoid_: data point, measurement, value

**Availability**:
Whether a **Metric** or provider field can be read in the current environment. An unavailable reading is not zero.
_Avoid_: null value, missing value

**Freshness**:
How current a **Metric Sample** or **Quota Snapshot** is, expressed through its observation or synchronization time.
_Avoid_: staleness, age

## Subscriptions

**Provider**:
An external service that offers an AI coding subscription whose quota BaboJUPulse can monitor, such as Claude Code, Codex, Antigravity, or OpenCode Go.
_Avoid_: vendor, service, integration, adapter

**Account**:
A provider subscription identity configured in BaboJUPulse. One **Provider** may have multiple **Accounts**, and an **Account** is not a Windows user account.
_Avoid_: user, login, profile, credential

**Account Alias**:
A user-chosen display name for an **Account**. It is a label, not an identity or a credential.
_Avoid_: nickname, display name, username

**Quota**:
The subscription capacity that a **Provider** makes available to an **Account**, in the units that provider defines. Where the provider reports a **Quota Window**, quota is associated with that window.
_Avoid_: credits, balance, limit, usage

**Quota Window**:
A provider-defined period over which a **Quota** is measured, consumed, or reset. Providers do not necessarily use the same windows.
_Avoid_: billing cycle, period, bucket

**Quota Snapshot**:
The observed quota state of one **Account** at a point in time. It may include one or more **Quota Windows**, available **Quota Resets**, and the time of the last successful synchronization; a field that the provider does not expose is explicitly unavailable rather than zero.
_Avoid_: quota, usage record, response

**Quota Reset**:
The point at which a **Provider** makes some **Quota** available again for an **Account**. A reset follows provider-specific window or grant semantics; do not assume a universal schedule.
_Avoid_: refresh, renewal, rollover

**Banked Reset**:
A **Quota Reset** that a **Provider** has made available for later use rather than applying it immediately. Whether it belongs to a particular **Quota Window**, and when it expires, is provider-specific and not yet established uniformly.
_Avoid_: saved reset, reset credit, reset token

**Quota Event**:
A change in an **Account**'s quota state that may be worth telling the user about, such as a **Quota Reset** becoming available or a threshold being crossed.
_Avoid_: alert, notification

## Surfaces

**Taskbar Readout**:
The persistent information display that BaboJUPulse attaches to the Windows taskbar and keeps visible while the application runs.
_Avoid_: taskbar widget, deskband, toolbar

**Tray Icon**:
The notification-area icon that represents BaboJUPulse and opens the **Tray Popup**.
_Avoid_: system tray icon, notification icon

**Tray Popup**:
The compact detail surface opened from the **Tray Icon**. It is not a main window or a dashboard.
_Avoid_: tray window, flyout, dashboard

## Relationships

- A **Metric** produces a sequence of **Metric Samples**. Each sample carries its own **Availability** and observation time.
- An **Account** belongs to one **Provider**. A **Provider** may have zero, one, or many **Accounts**.
- An **Account** has zero or more **Quota Snapshots** over time. A **Quota Snapshot** describes exactly one **Account**.
- A **Quota Snapshot** may report zero, one, or many **Quota Windows**, and zero or more **Banked Resets**. Do not infer that every account has a quota or that every provider uses windows.
- A **Quota Reset** and a **Banked Reset** may affect quota reported through a **Quota Window**, but the exact relationship is provider-specific.
- A **Taskbar Readout** presents selected **Metrics**. Whether it also presents subscription quota is not established.
- A **Tray Popup** is opened from the **Tray Icon** and is intended to present detail such as **Metric Samples** and **Quota Snapshots**.

## Unresolved language

These points remain open. Do not resolve them by assumption in a specification, implementation, test, or review.

- **Banked-reset ownership.** A banked reset may be independent of every quota window, tied to one window, or modeled differently by different providers. The glossary does not choose.
- **Provider capability uniformity.** Providers may not expose a quota, a reset time, quota windows, banked resets, or a synchronization time. Missing fields stay explicitly unavailable.
- **Quota units.** Quota is expressed in provider-defined units. A shared percentage or currency is not established.
- **"Usage."** The word can mean consumed capacity or remaining capacity. Prefer **Quota** plus an explicit direction instead of the bare word.
- **Taskbar quota display.** Product scope describes a taskbar readout for selected metrics and a tray popup for detail. A taskbar quota readout is not established.
- **Account identity.** How an account is identified, authenticated, and stored is an architecture and security decision, not a settled domain relationship.

## Maintaining this glossary

Update the glossary when a domain concept is established or changes. Keep definitions short, keep implementation detail out, and record unresolved relationships instead of inventing them. See [Domain guidance](docs/agents/domain.md) for when a term is ready to enter this file and when a decision needs an ADR or maintainer input.
