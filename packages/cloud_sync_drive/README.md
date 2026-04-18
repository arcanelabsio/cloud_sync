# cloud_sync_drive

Google Drive adapter for the [`cloud_sync`](..) family. Implements `StorageAdapter` from `cloud_sync_core`, so it plugs directly into `SyncClient` or `SyncEngine`.

## Install

```yaml
dependencies:
  cloud_sync_core: ^0.1.0
  cloud_sync_drive: ^0.1.0
  google_sign_in: ^6.0.0   # or any OAuth2 client that yields an authenticated http.Client
```

## Quick start

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_drive/cloud_sync_drive.dart';
import 'package:google_sign_in/google_sign_in.dart';

final signIn = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/drive.file']);
final account = await signIn.signIn();
final authClient = DriveAuthClient(await account!.authHeaders);

final adapter = DriveAdapter.appFiles(
  httpClient: authClient,
  folderName: 'MyApp',
  subPath: 'Backups',
);

final client = SyncClient(adapter: adapter);
final result = await client.sync(localPath: '/path/to/data');
```

## Scope modes

| Factory | OAuth scope | Use when |
|---|---|---|
| `DriveAdapter.userDrive(basePath:)` | `drive` | Files are written by multiple clients (mobile + CLI + Drive Desktop) |
| `DriveAdapter.appFiles(folderName:)` | `drive.file` | Single-writer app sync. No CASA required. |
| `DriveAdapter.appData(subPath:)` | `drive.appdata` | Internal app state. Hidden from user. No CASA required. |

See `DriveScope` doc comments for the full tradeoff discussion including CASA audit cost and scope compliance.

## License

MIT
