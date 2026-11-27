# Security policy

## Supported versions

No version of BaboJUPulse has been released. The repository is a foundation build and is not intended for production use.

## Reporting a vulnerability

Do not open a public issue for a security problem. Use GitHub's private vulnerability reporting:

<https://github.com/babo-jeonguk/BaboJUPulse/security/advisories/new>

Include the affected commit or version, the steps to reproduce, the impact, and any suggested fix. Do not include real credentials, tokens, account identifiers, or provider responses. Redact logs before attaching them.

## Scope

Security-relevant areas of this project include:

- Windows credential storage and account identity.
- Provider authentication and quota requests.
- Logging and crash output.
- Native Windows interop and handle ownership.
- The update and packaging channel once one exists.

## Handling secrets

- Never commit credentials, tokens, cookies, account identifiers, or local configuration.
- Store secrets in Windows Credential Manager or a DPAPI-protected store scoped to the current user.
- Do not log request headers, authorization codes, or full provider responses.
- Use test fixtures with synthetic values only.
