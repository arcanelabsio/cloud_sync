## 0.1.1

Initial release as part of the `cloud_sync` family. Behavior ported from `drive_sync_flutter 1.2.0`.

- `DriveAdapter` (renamed from `GoogleDriveAdapter`) implements `StorageAdapter` from `cloud_sync_core`
- Three factory constructors for OAuth scope selection:
  - `DriveAdapter.userDrive(basePath:, subPath:)` — full `drive` scope
  - `DriveAdapter.appFiles(folderName:, subPath:)` — `drive.file` scope
  - `DriveAdapter.appData(subPath:)` — `drive.appdata` scope
- `DriveAuthClient` — `http.BaseClient` wrapper that injects Google auth headers
- `DriveScope` enum + `DriveScopeError` for scope-mismatch detection
- Legacy constructors (`sandboxed`, `withPath`, default positional) removed — not ported from `drive_sync_flutter`

Not backward-compatible with `drive_sync_flutter` — this is a fresh package with clean naming. Consumers of `drive_sync_flutter 1.2.0` migrate by renaming classes and updating imports.
