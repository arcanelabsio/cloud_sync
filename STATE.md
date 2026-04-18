# cloud_sync — STATE

## Current phase

**Phase 2 — COMPLETE.** `cloud_sync_s3 0.1.0` added. Hand-rolled SigV4 matches AWS's published S3 test vector byte-for-byte. Supports AWS + all major S3-compatible services via endpoint override.

## Phase status

| Phase | Packages | Status |
|---|---|---|
| 1 | `cloud_sync_core`, `cloud_sync_drive` | ✅ Done (90 tests) |
| 2 | `cloud_sync_s3` | ✅ Done (48 tests) |
| 3 | `cloud_sync_box` | Not started |

## Test counts

- `cloud_sync_core`: 62 tests passing
- `cloud_sync_drive`: 28 tests passing
- `cloud_sync_s3`: 48 tests passing
- **Total**: 138 tests passing

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

## Next

1. Phase 3: `cloud_sync_box` — Box Content API, OAuth2 Bearer only, path↔ID resolver.
2. Wire up `.github/workflows/publish.yaml` (tag-triggered) before creating the GitHub remote.
3. Create GitHub repo + push after Phase 3 lands.
4. Freeze pub.dev `drive_sync_flutter 1.2.0` — add deprecation note pointing at `cloud_sync_drive` once published.

## Last updated

2026-04-18 — Phase 2 (S3) complete, ready for commit.
