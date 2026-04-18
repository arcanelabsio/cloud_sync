# cloud_sync

Bidirectional file sync for Dart and Flutter, across multiple cloud storage backends. Path-based manifest diffing, SHA256 change detection, pluggable conflict resolution — implemented once in a storage-agnostic core, reused across every backend.

## Packages

| Package | Description | Status |
|---|---|---|
| [`cloud_sync_core`](packages/cloud_sync_core) | Core interfaces (`StorageAdapter`), sync engine, manifest differ, conflict resolver, `SyncClient`. No backend logic. | 0.1.0 |
| [`cloud_sync_drive`](packages/cloud_sync_drive) | Google Drive adapter. `drive`, `drive.file`, `drive.appdata` scopes supported. | 0.1.0 |
| `cloud_sync_s3` | AWS S3 + S3-compatible adapter (R2, MinIO, Backblaze B2, Wasabi, DO Spaces). | Planned |
| `cloud_sync_box` | Box Content API adapter. | Planned |

## Design

One interface, many backends. Each backend package implements `StorageAdapter` (5 methods: `ensureFolder`, `listFiles`, `uploadFile`, `downloadFile`, `deleteFile`) and ships with its own auth helpers. The sync engine in `cloud_sync_core` works identically against any adapter.

## Usage

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_drive/cloud_sync_drive.dart';

final adapter = DriveAdapter.appFiles(
  httpClient: authClient,
  folderName: 'MyApp',
);
final client = SyncClient(adapter: adapter);
final result = await client.sync(localPath: '/path/to/data');
```

Swap the adapter, not the client. Everything downstream stays the same.

## Development

```bash
dart pub global activate melos
melos bootstrap
melos run analyze
melos run test
```

## History

This repository supersedes [`drive_sync_flutter`](https://pub.dev/packages/drive_sync_flutter). That package is frozen at 1.2.0; new development lives here.

## License

MIT
