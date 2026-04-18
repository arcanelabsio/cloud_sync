# cloud_sync_box

Box Content API adapter for the [`cloud_sync`](..) family. Plugs into `SyncClient` from `cloud_sync_core`.

## Install

```yaml
dependencies:
  cloud_sync_core: ^0.1.0
  cloud_sync_box: ^0.1.0
```

## Quick start

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_box/cloud_sync_box.dart';

final authClient = BoxAuthClient(accessToken: 'your-oauth2-access-token');

final adapter = BoxAdapter(
  config: BoxConfig(rootFolderId: '0'),  // "0" = user's Box root
  httpClient: authClient,
);

final client = SyncClient(adapter: adapter);
final result = await client.sync(localPath: '/path/to/data');
```

## Auth — bring your own client

This package does not handle OAuth2 flows. Consumers supply an `http.Client` that has already been authenticated. The included `BoxAuthClient` is a convenience for the simple Bearer-token case:

```dart
final authClient = BoxAuthClient(accessToken: accessToken);
```

For JWT App Auth (server-to-server), build your own `http.Client` that signs each request with a JWT and pass it to `BoxAdapter`.

## How path resolution works

Box's API is ID-based (`fileId`, `folderId`), but `StorageAdapter` contracts on paths. On first sync, `BoxAdapter` performs one recursive walk below `rootFolderId` to build an in-memory `path → id` cache. Subsequent operations are O(1) lookups. New files and folders created during the session are registered in the cache immediately.

Single-client assumption: the cache is per-adapter-instance. Concurrent mutations from another client won't invalidate our cache automatically — reinitialize `BoxAdapter` (or call the sync operation again, which re-walks) to pick up external changes.

## SHA256 preservation

Box provides SHA1 natively (not SHA256). To satisfy the engine's SHA256 contract, this adapter stores the SHA256 as Box custom metadata at `/files/{id}/metadata/global/properties` under the key `sha256`. On `listFiles`, the adapter reads the metadata back.

Files uploaded outside this library (or before this library managed them) surface with `sha256 == null`, at which point the sync engine falls back to download-and-hash.

## Limitations

- **File size ceiling: ~50MB.** v1 uses Box's single-request upload endpoint. Chunked upload (required for >50MB) is planned for a future release.
- **No shared-link or collaboration features.** This adapter is for sync only.

## License

MIT
