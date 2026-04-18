## 0.1.1

Initial release. Storage-agnostic core extracted from `drive_sync_flutter 1.2.0`.

- `StorageAdapter`: 5-method abstract interface (`ensureFolder`, `listFiles`, `uploadFile`, `downloadFile`, `deleteFile`)
- `SyncEngine`: orchestrates manifest diffing, conflict resolution, and file transfer
- `ManifestDiffer`: compares two sync manifests (added / modified / deleted / unchanged)
- `ConflictResolver`: four strategies — `newerWins`, `localWins`, `remoteWins`, `askUser`
- `SyncClient`: high-level bidirectional sync with `push` / `pull` / `sync` / `status` operations
- `PathValidator`: structural path safety (no traversal, no absolute paths, no empty segments)
- Value types: `RemoteFileInfo`, `SyncFileEntry`, `SyncManifest`, `SyncResult`, `SyncStatus`, `SyncConflict`, `ManifestDiff`
