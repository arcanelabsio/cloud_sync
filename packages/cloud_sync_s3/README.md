# cloud_sync_s3

S3 + S3-compatible storage adapter for the [`cloud_sync`](..) family. Plugs into `SyncClient` from `cloud_sync_core`.

## Install

```yaml
dependencies:
  cloud_sync_core: ^0.1.0
  cloud_sync_s3: ^0.1.0
```

## Quick start — AWS S3

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_s3/cloud_sync_s3.dart';

final adapter = S3Adapter(
  config: S3Config(region: 'us-east-1', bucket: 'my-sync-bucket'),
  credentials: S3Credentials(
    accessKeyId: 'AKIA...',
    secretAccessKey: '...',
  ),
);

final client = SyncClient(adapter: adapter);
final result = await client.sync(localPath: '/path/to/data');
```

## S3-compatible services

### Cloudflare R2

```dart
S3Config(
  endpoint: 'https://<account-id>.r2.cloudflarestorage.com',
  region: 'auto',
  bucket: 'my-bucket',
);
```

### MinIO (local dev)

```dart
S3Config(
  endpoint: 'http://localhost:9000',
  region: 'us-east-1',
  bucket: 'my-bucket',
  usePathStyle: true,
);
```

### Backblaze B2 (S3-compatible API)

```dart
S3Config(
  endpoint: 'https://s3.us-west-002.backblazeb2.com',
  region: 'us-west-002',
  bucket: 'my-bucket',
);
```

### Wasabi

```dart
S3Config(
  endpoint: 'https://s3.us-east-1.wasabisys.com',
  region: 'us-east-1',
  bucket: 'my-bucket',
);
```

### DigitalOcean Spaces

```dart
S3Config(
  endpoint: 'https://nyc3.digitaloceanspaces.com',
  region: 'nyc3',
  bucket: 'my-bucket',
);
```

## Limitations

- **File size ceiling: ~50MB.** v1 uses single-request `PutObject` (no multipart). Files larger than this may fail or consume excessive memory. Multipart upload support is planned for a future release.
- **SHA256 via custom metadata.** On upload, the adapter sets `x-amz-meta-sha256`. On list, it reads this back via `HeadObject` (one extra round trip per file). Files uploaded outside this library will fall back to the engine's download-and-hash path.

## License

MIT
