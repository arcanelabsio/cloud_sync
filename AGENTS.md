# AGENTS.md — cloud_sync

> Authoritative guide for AI coding assistants (Claude Code, Codex, Copilot, Gemini) working in this repo. `CLAUDE.md` imports this file via `@AGENTS.md`; edit here, not there.

## Purpose

`cloud_sync` is a Dart/Flutter monorepo for bidirectional file sync between local disk and cloud storage. The design is deliberate: one small storage-agnostic core (`cloud_sync_core`) plus independent per-backend adapter packages (`cloud_sync_drive`, `cloud_sync_s3`, `cloud_sync_box`). The same `SyncClient` runs against any adapter; adding a backend means implementing a 5-method `StorageAdapter` interface.

Before changing anything non-trivial, read this file and the docs it links to. Arcane Labs repos prize invariants over defaults — the right edit respects the constraints that were chosen deliberately.

## Key Rules

- **Conventional Commits.** `feat|fix|chore|docs|refactor|test|ci(<scope>): <subject>`. No `Co-Authored-By:` trailers.
- **ADRs for structural decisions.** Any change that alters the `StorageAdapter` contract, the manifest format, conflict-resolution semantics, path-validation rules, or a backend's trust boundary ships with an ADR in `docs/adr/` — even if the ADR is three paragraphs.
- **No silent scope expansion.** If a task grows beyond its original intent, surface it in the PR description and propose splitting. Don't quietly add features, refactors, or abstractions.
- **Comments only when the *why* is non-obvious.** Well-named code doesn't need comments explaining what it does. Use comments to record hidden constraints, subtle invariants, workarounds.
- **Tests live alongside code** and cover the invariants below. A PR that adds behavior without adding a test that would fail without it is incomplete.
- **Per-package independence.** Each `packages/cloud_sync_*` publishes independently on its own semver track. A breaking change in one adapter must not force a lockstep bump in another.

## Invariants that must not be broken

1. **The sync engine never reads file contents.** Content flows through the engine as opaque `List<int>` bytes only. SHA256 is computed on the bytes; no format-aware parsing. This is what makes the library safe for encrypted blobs.
2. **Storage-agnostic core.** `cloud_sync_core` must not import any provider SDK or speak any backend's wire format. A regression here (e.g., importing `package:googleapis` in the core) is a bug.
3. **Every adapter implements the full `StorageAdapter` contract.** The 5 methods are mandatory. Adapters may add extension methods, but the core engine must never call outside the 5.
4. **Path validation is always on.** `PathValidator` runs before any adapter instance exists and rejects traversal (`..`), absolute paths (leading `/`), empty segments, trailing slashes, and dot segments. Query injection into backend-specific queries is escaped inside the adapter, not outside.
5. **SHA256 is preserved across all adapters.** Backends that don't return SHA256 natively (S3, Box) must round-trip it via custom metadata. Files uploaded outside the library legitimately surface with `sha256 == null`; the engine falls back to download-and-hash in that case.
6. **No long-lived secrets in CI.** Publishing uses pub.dev OIDC trusted publishing. Static credentials must not be introduced.
7. **50MB single-request ceiling is documented, not hidden.** If multipart/chunked upload is added, it's an ADR — the single-request invariant is part of v1's shipped contract.

A PR that weakens an invariant without superseding the ADR that established it must be rejected.

## Where to find the contract

- **Code entry points:**
  - `packages/cloud_sync_core/lib/cloud_sync_core.dart` — `SyncClient`, `SyncEngine`, `StorageAdapter`, `ConflictStrategy`, `PathValidator`, manifest types.
  - `packages/cloud_sync_drive/lib/cloud_sync_drive.dart` — `DriveAdapter`, `DriveAuthClient`, `DriveScope`, `DriveScopeError`.
  - `packages/cloud_sync_s3/lib/cloud_sync_s3.dart` — `S3Adapter`, `S3Config`, `S3Credentials`, `S3AuthClient`, `AwsSigV4`.
  - `packages/cloud_sync_box/lib/cloud_sync_box.dart` — `BoxAdapter`, `BoxConfig`, `BoxAuthClient`.
- **Data contract:** `SyncManifest` in `cloud_sync_core` — the on-disk `_sync_manifest.json` shape. Changes to its JSON structure are breaking.
- **ADRs:** [`docs/adr/`](./docs/adr/) — read before proposing structural changes.
- **Security reporting:** [`SECURITY.md`](./SECURITY.md).
- **Contribution guide:** [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## Onboarding order for a new contributor (human or agent)

1. This file — rules and invariants.
2. `README.md` — the full feature tour and public API.
3. `STATE.md` — current phase, active work, open decisions.
4. Each package README under `packages/cloud_sync_*/README.md` — per-backend specifics.
5. `docs/adr/` — why the code looks the way it does.
6. The entry-point files listed above.

## Commands an agent will typically run

```bash
# Setup
dart pub global activate melos
melos bootstrap                 # or: make bootstrap

# Quality gates
melos run analyze               # or: make analyze
melos run test                  # or: make test
melos run format                # or: make format

# Pre-release preflight
make pre-release                # analyze + test + publish dry-run

# Release a single package (tag → GitHub Actions → pub.dev)
make release PKG=drive          # or: core | s3 | box
```

`make help` prints the full target list.

## Working in the monorepo

- Use `melos bootstrap` after every pull that changes a `pubspec.yaml`. It rewires intra-repo path dependencies through `pubspec_overrides.yaml`.
- Adapter packages depend on `cloud_sync_core` via the melos workspace; overrides are regenerated by `bootstrap` — never hand-edit `pubspec_overrides.yaml`.
- When changing `cloud_sync_core`, run `melos run test` (the full suite). A core change can break any adapter.
