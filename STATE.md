# cloud_sync — STATE

## Current phase

**All four packages live on pub.dev at 0.1.1.** Core + Drive + S3 + Box shipped. GitHub repo at `arcanelabsio/cloud_sync`. Release tooling (Makefile + `scripts/tag.sh`) in place. Next: configure OIDC on pub.dev and swap the workflow's placeholder step for the real publish call.

## Phase status

| Phase | Packages | Status |
|---|---|---|
| 1 | `cloud_sync_core`, `cloud_sync_drive` | ✅ Done (90 tests) |
| 2 | `cloud_sync_s3` | ✅ Done (48 tests) |
| 3 | `cloud_sync_box` | ✅ Done (19 tests) |

## Test counts

- `cloud_sync_core`: 62 tests passing
- `cloud_sync_drive`: 28 tests passing
- `cloud_sync_s3`: 48 tests passing
- `cloud_sync_box`: 19 tests passing
- **Total**: 157 tests passing across 4 packages

## pub.dev score (pana, local)

All four packages: **160/160**.

- Conventions 30/30 (description length, README, CHANGELOG, MIT LICENSE)
- Documentation 20/20 (≥20% dartdoc coverage, example/ present)
- Platform 20/20 (5 of 6 platforms — Web excluded due to `dart:io`, no deduction)
- Analysis 50/50 (0 errors, 0 warnings, 0 format issues)
- Dependencies 40/40 (all constraints admit latest major)

## cloud_sync_s3 design notes

- `AwsSigV4`: stateless signer, validated against AWS's "GET Object with Range" test vector (signature `f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41`).
- `S3AuthClient`: `http.BaseClient` that signs every request. Extracts `x-amz-*` headers from the outgoing request and includes them in the SigV4 signed-headers set.
- `S3Adapter`: primary constructor always wraps in `S3AuthClient`. Test-only `.withHttpClient()` bypasses signing for mock-HTTP tests.
- SHA256 preservation: PutObject sets `x-amz-meta-sha256`; `listFiles()` performs HeadObject per file to read it back. N+1 round trips for correctness — files uploaded outside the library fall back to the engine's download-and-hash path.
- 50MB file ceiling: no multipart upload. Enforced by single-request PutObject. Documented in README.

## Porting notes

- `DriveAdapter` (interface) → renamed `StorageAdapter`, moved to `cloud_sync_core`
- `DriveSyncClient` → renamed `SyncClient`, moved to `cloud_sync_core`
- `SandboxValidator` → renamed `PathValidator`, moved to `cloud_sync_core`. `escapeDriveQuery` method dropped from the validator and inlined as a private method inside `DriveAdapter`.
- `GoogleDriveAdapter` → renamed `DriveAdapter`, stayed in `cloud_sync_drive`. Legacy constructors (`.sandboxed()`, `.withPath()`, positional `()`) removed — clean-slate API.
- `GoogleAuthClient` → renamed `DriveAuthClient`, stayed in `cloud_sync_drive`.
- `DriveScope` enum + `DriveScopeError` → unchanged, stayed in `cloud_sync_drive`.

## Decisions (2026-04-18)

- **Publishing**: Hold all publishes until S3 + Box land. Then publish from a GitHub Actions workflow triggered by release tags — not from local shell.
- **Large-file ceiling**: Keep the ~50MB limit in v1 across all adapters. Streaming refactor is deferred (would require breaking changes to `SyncEngine`). Document the limit in each adapter README.
- **GitHub remote**: Hold. Create the `arcanelabsio/cloud_sync` repo and push after all planned connectors land locally.

## cloud_sync_box design notes

- `BoxConfig`: rootFolderId + overridable baseUrl/uploadUrl (api.box.com vs upload.box.com are separate hosts in Box's real API).
- `BoxAuthClient`: Bearer-token helper. JWT App Auth consumers build their own `http.Client`.
- `BoxPathResolver`: lazy recursive walk from rootFolderId populates `path→id` cache. `ensureParent()` creates missing folder segments on demand. Single-client assumption — call `reset()` if external mutations occurred.
- `BoxAdapter`: picks upload-new vs upload-version based on resolver.resolveExisting. Stores SHA256 at `/files/{id}/metadata/global/properties` (POST on create, PUT with JSON Patch on 409 conflict).
- 50MB file ceiling: uses Box's single-request upload endpoint, not chunked.

## Release workflow

```bash
# Typical release of a single package:
# 1. Bump version in packages/<pkg>/pubspec.yaml + update CHANGELOG.md
# 2. git commit + git push main
# 3. Preflight (analyze + test + publish dry-run):
make pre-release
# 4. Tag + push → publish.yaml picks it up:
make release PKG=drive   # or: core | s3 | box
```

`make help` for the full target list. Wraps `melos run` scripts + `scripts/tag.sh`.

## Next

1. Freeze pub.dev `drive_sync_flutter 1.2.0` — add deprecation note pointing
   at `cloud_sync_drive` (manual pub.dev admin action).

## Last updated

2026-04-18 — All 4 packages published at 0.1.1. OIDC-backed auto-publish
wired end-to-end. Next `make release PKG=<pkg>` will publish via CI.
