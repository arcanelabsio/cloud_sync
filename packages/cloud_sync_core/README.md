# cloud_sync_core

Storage-agnostic core for the [`cloud_sync`](https://github.com/arcanelabsio/cloud_sync) family. Defines *what* syncing means — not *where* it syncs to. Concrete backends (Google Drive, S3, Box, …) live in sibling packages and implement the `StorageAdapter` interface.

This package is backend-free. It has zero HTTP code, zero OAuth logic, and no knowledge of any provider's wire format.

## What's in here

- **`SyncClient`** — high-level API (`sync`, `push`, `pull`, `status`)
- **`SyncEngine`** — orchestrates manifest diff → conflict resolution → file transfer
- **`StorageAdapter`** — abstract 5-method interface every backend implements
- **`ManifestDiffer`** — diffs two `SyncManifest`s to produce a `PendingChanges` set
- **`ConflictResolver`** — applies a `ConflictStrategy` to decide winners
- **`PathValidator`** — structural path safety (no traversal, no absolute paths, no empty segments)
- **Data types** — `SyncManifest`, `RemoteFileInfo`, `SyncResult`, `SyncStatus`, `PendingChanges`

## Install

```yaml
dependencies:
  cloud_sync_core: ^0.1.1
  # plus at least one adapter:
  cloud_sync_drive: ^0.1.1
  # cloud_sync_s3: ^0.1.1
  # cloud_sync_box: ^0.1.1
```

`cloud_sync_core` on its own does nothing useful — it provides the engine and contract, not any backend. Pair it with an adapter package (or a custom one you write).

## Using an existing backend

Every adapter package ships a factory constructor. Build one, wrap it in `SyncClient`, and sync:

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_drive/cloud_sync_drive.dart';

final adapter = DriveAdapter.appFiles(
  httpClient: authClient,
  folderName: 'MyApp',
);

final client = SyncClient(
  adapter: adapter,
  defaultStrategy: ConflictStrategy.newerWins,
);

// Bidirectional sync
final result = await client.sync(localPath: '/path/to/data');
print('${result.filesUploaded} up, ${result.filesDownloaded} down, ${result.unresolvedConflicts.length} conflicts');

// Push only — local overwrites remote
await client.push(localPath: '/path/to/data');

// Pull only — remote overwrites local
await client.pull(localPath: '/path/to/data');

// Dry-run: what would change?
final status = await client.status(localPath: '/path/to/data');
print('Pending: ${status.pendingChanges?.totalChanges ?? 0}');
```

The rest of the code is identical whether `adapter` is `DriveAdapter`, `S3Adapter`, or `BoxAdapter`.

## Implementing a new backend

Implement five methods against `StorageAdapter`:

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';

class MyAdapter implements StorageAdapter {
  @override
  Future<void> ensureFolder() async {
    // Create the root folder (or bucket/prefix) if it doesn't exist.
    // Idempotent — called before every sync.
  }

  @override
  Future<Map<String, RemoteFileInfo>> listFiles() async {
    // List all remote files under the sync root.
    // Key: relative path from the sync root.
    // Value: RemoteFileInfo(sha256, lastModified).
    // sha256 may be null if the backend doesn't have it — the engine will
    // fall back to download-and-hash for those files.
  }

  @override
  Future<void> uploadFile(String path, List<int> content) async {
    // Upload `content` to the given relative path. Create intermediate
    // folders as needed. Preserve SHA256 however your backend allows
    // (native header, custom metadata, etc.) so listFiles() can return it.
  }

  @override
  Future<List<int>> downloadFile(String path) async {
    // Return the bytes of the file at `path`.
  }

  @override
  Future<void> deleteFile(String path) async {
    // Remove the file at `path`. Missing-file is not an error.
  }
}
```

Then wire it up:

```dart
final client = SyncClient(adapter: MyAdapter(...));
await client.sync(localPath: '/path/to/data');
```

### SHA256 preservation

The engine's change detection is SHA256-based. If your backend doesn't return a content hash natively, round-trip SHA256 through custom metadata:

- **AWS S3** — store under `x-amz-meta-sha256`; read via `HeadObject`.
- **Box** — store under `/files/{id}/metadata/global/properties` with key `sha256`.
- **Your backend** — use whatever metadata facility it offers.

If `RemoteFileInfo.sha256` is `null` for a remote file, the engine will download it and hash it locally — correct but slower. This makes the engine robust to files uploaded outside the library.

## Conflict resolution

When both local and remote have modified the same file, the engine **picks one version** — it never merges content. It compares SHA256 (to detect changes) and `lastModified` (to pick a winner), so it works on JSON, binary, or encrypted files.

| Strategy | Behavior |
|---|---|
| `ConflictStrategy.newerWins` | Most recent `lastModified` wins. Ties go to local. |
| `ConflictStrategy.localWins` | Always keep the local version; remote is overwritten. |
| `ConflictStrategy.remoteWins` | Always keep the remote version; local is overwritten. |
| `ConflictStrategy.askUser` | Skip the file and return it in `result.unresolvedConflicts`. |

If you need to preserve both versions, use `askUser` and implement your own merge or backup logic.

## Path validation

`PathValidator` runs before any adapter instance is constructed. It rejects:

- Traversal (`..`)
- Absolute paths (leading `/`)
- Empty segments (`//`)
- Trailing slashes (`path/`)
- Dot segments (`.`)

This is the core's structural contract; adapters are free to add backend-specific escaping on top.

## Manifest

A JSON file (`_sync_manifest.json`) stored alongside your local data tracks `{path, sha256, lastModified}` for each synced file. Only files that changed since the last sync are transferred. The manifest is readable and you can inspect it for debugging — but the engine owns it and will overwrite it on every successful sync.

## Architecture

```
SyncClient                <- your entry point
   └─ SyncEngine          <- orchestrates diff → resolve → transfer
        ├─ ManifestDiffer      <- compares file states (added/modified/deleted/unchanged)
        ├─ ConflictResolver    <- applies conflict strategy
        └─ StorageAdapter      <- backend-specific I/O (5 methods)
```

Everything above `StorageAdapter` is in this package. Everything below is in the adapter packages.

## Available adapters

- [`cloud_sync_drive`](https://pub.dev/packages/cloud_sync_drive) — Google Drive (three scope modes)
- [`cloud_sync_s3`](https://pub.dev/packages/cloud_sync_s3) — AWS S3 + S3-compatibles (R2, MinIO, Backblaze, Wasabi, DO Spaces)
- [`cloud_sync_box`](https://pub.dev/packages/cloud_sync_box) — Box Content API

Or implement your own.

## License

MIT
