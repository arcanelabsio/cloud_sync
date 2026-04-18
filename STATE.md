# cloud_sync — STATE

## Current phase

**Phase 1 — COMPLETE.** Monorepo stood up with `cloud_sync_core 0.1.0` + `cloud_sync_drive 0.1.0`. Both packages analyze clean and all tests pass.

## Phase status

| Phase | Packages | Status |
|---|---|---|
| 1 | `cloud_sync_core`, `cloud_sync_drive` | ✅ Done (analyze ✅, 90 tests passing) |
| 2 | `cloud_sync_s3` | Not started |
| 3 | `cloud_sync_box` | Not started |

## Test counts

- `cloud_sync_core`: 62 tests passing
- `cloud_sync_drive`: 28 tests passing
- **Total**: 90 tests passing

Delta from old `drive_sync_flutter 1.2.0` (117 tests): 27 tests dropped — all legacy-constructor or inlined-helper tests with no functional equivalent in the new package.

## Porting notes

- `DriveAdapter` (interface) → renamed `StorageAdapter`, moved to `cloud_sync_core`
- `DriveSyncClient` → renamed `SyncClient`, moved to `cloud_sync_core`
- `SandboxValidator` → renamed `PathValidator`, moved to `cloud_sync_core`. `escapeDriveQuery` method dropped from the validator and inlined as a private method inside `DriveAdapter`.
- `GoogleDriveAdapter` → renamed `DriveAdapter`, stayed in `cloud_sync_drive`. Legacy constructors (`.sandboxed()`, `.withPath()`, positional `()`) removed — clean-slate API.
- `GoogleAuthClient` → renamed `DriveAuthClient`, stayed in `cloud_sync_drive`.
- `DriveScope` enum + `DriveScopeError` → unchanged, stayed in `cloud_sync_drive`.

## Next

1. Git commit Phase 1 with a single conventional commit (`chore: initial monorepo + cloud_sync_core + cloud_sync_drive`).
2. Decide: publish `cloud_sync_core 0.1.0` + `cloud_sync_drive 0.1.0` to pub.dev now, or after Phase 2 lands?
3. Open question unresolved from plan: large-file support ceiling for Phase 2 (keep ~50MB or lift via streaming refactor in `cloud_sync_core 0.2.0`?).
4. Phase 2: `cloud_sync_s3` (SigV4 hand-rolled, S3-compatible endpoints from day one).

## Last updated

2026-04-18 — Phase 1 complete, ready for commit.
