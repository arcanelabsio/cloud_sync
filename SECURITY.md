# Security Policy

Arcane Labs takes security reports seriously. This document describes how to report a vulnerability and what to expect in response.

## Supported versions

`cloud_sync` is a monorepo — each package publishes independently.

| Package | Supported version | Notes |
|---|---|---|
| `cloud_sync_core` | Latest `0.1.x` | Fixes applied here |
| `cloud_sync_drive` | Latest `0.1.x` | Fixes applied here |
| `cloud_sync_s3` | Latest `0.1.x` | Fixes applied here |
| `cloud_sync_box` | Latest `0.1.x` | Fixes applied here |
| `main` branch | Latest | Fixes land here first |

Older `0.1.x` releases are not patched once a newer `0.1.x` ships. Open a tracking issue if you need a fix on an older version.

## Reporting a vulnerability

**Do not open a public GitHub issue for security reports.**

Email **apps@arcanelabs.info** with:

- A short description of the issue
- The **package** and **version** affected (e.g., `cloud_sync_drive 0.1.1`)
- The file, module, or component affected
- Steps to reproduce (or a proof-of-concept, if available)
- The impact as you understand it (data exposure, privilege escalation, bypass, etc.)
- Your preferred credit line if you'd like acknowledgment

We'll acknowledge receipt within **3 business days** and aim to triage and respond with a plan within **7 business days**. If confirmed valid, we'll coordinate a fix timeline with you and publish a security advisory once the fix has shipped.

## Scope

### In scope

- **Path-validation bypass** — any input that slips past `PathValidator` (traversal, absolute-path, empty-segment, dot-segment, trailing-slash) inside `cloud_sync_core`.
- **Query-injection** into a backend's native query syntax (Drive query, S3 URL, Box API) via file or folder names the library exposes to the caller.
- **Scope/trust-boundary bypass** in `cloud_sync_drive` — e.g., an `.appFiles()` adapter reading files it did not create, or `.appData()` leaking into the user's visible Drive.
- **SigV4 correctness** in `cloud_sync_s3` — any input that produces an invalid signature, or any signature-verification shortcut.
- **Auth-token leakage** — tokens appearing in logs, error messages, or the manifest file.
- **Manifest tampering** — a locally attacker-controlled `_sync_manifest.json` causing the engine to overwrite arbitrary local files.
- **Supply-chain issues** in declared dependencies where this repo's usage materially increases exposure.

### Out of scope

- Issues that require the attacker to already have full local filesystem access (the manifest is not a trust boundary against that threat model).
- Google / AWS / Box service-side vulnerabilities — report those to the provider.
- OAuth-consent-screen weaknesses — that's the consumer app's responsibility, not this library.
- Missing encryption at rest. By design, `cloud_sync` does not encrypt. Consumers that need encryption must encrypt before `sync()` — this is documented and intentional.
- Theoretical issues with no practical exploit path.

## Disclosure posture

Arcane Labs prefers **coordinated disclosure**. If your disclosure timeline differs, say so in your initial email and we'll work something out. We will **not** pursue legal action against researchers who act in good faith and follow this policy.

## Privacy of your report

We treat your report as confidential until a fix ships and you're credited (or you've asked to stay anonymous). We do not share reporter details with third parties.

---

Maintained by **Arcane Labs** · apps@arcanelabs.info
