# cloud_sync_core

Storage-agnostic core for the `cloud_sync` family. This package defines *what* syncing means — not *where* it syncs to. Concrete backends (Google Drive, S3, Box, ...) live in sibling packages and implement the `StorageAdapter` interface.

## What's in here

- **`StorageAdapter`** — abstract 5-method interface every backend implements
- **`SyncEngine`** — orchestrates manifest diff → conflict resolution → file transfer
- **`SyncClient`** — high-level API (`sync`, `push`, `pull`, `status`)
- **`ManifestDiffer`** — diffs two `SyncManifest`s
- **`ConflictResolver`** — applies a `ConflictStrategy` to decide winners
- **`PathValidator`** — structural path safety (no traversal, no absolute paths)

## What's *not* in here

- No HTTP code
- No OAuth / auth logic
- No file I/O (callbacks are supplied by the caller or by `SyncClient` using `dart:io`)
- No provider-specific knowledge (Drive, S3, Box)

## Implementing a new backend

```dart
class MyAdapter implements StorageAdapter {
  @override Future<void> ensureFolder() async { /* create root */ }
  @override Future<Map<String, RemoteFileInfo>> listFiles() async { /* list */ }
  @override Future<void> uploadFile(String path, List<int> content) async { /* put */ }
  @override Future<List<int>> downloadFile(String path) async { /* get */ }
  @override Future<void> deleteFile(String path) async { /* delete */ }
}
```

Then wire it up:

```dart
final client = SyncClient(adapter: MyAdapter(...));
final result = await client.sync(localPath: '/path/to/data');
```

## Using an existing backend

See `cloud_sync_drive` (Google Drive), `cloud_sync_s3` (AWS S3 + compatibles), `cloud_sync_box` (Box).

## License

MIT
