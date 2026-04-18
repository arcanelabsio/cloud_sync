/// Example showing [S3Adapter] set up against AWS S3 and a few S3-compatible
/// services.
///
/// Substitute real credentials below to run. The adapter signs every request
/// with AWS SigV4 automatically — no additional auth setup needed.
library;

import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_s3/cloud_sync_s3.dart';

Future<void> main() async {
  // AWS S3 — virtual-hosted style.
  final awsAdapter = S3Adapter(
    config: S3Config(region: 'us-east-1', bucket: 'my-sync-bucket'),
    credentials: S3Credentials(
      accessKeyId: 'AKIA...',
      secretAccessKey: 'YOUR_SECRET',
    ),
  );

  // Cloudflare R2 — same SigV4 signing; just an endpoint + region override.
  final r2Adapter = S3Adapter(
    config: S3Config(
      endpoint: 'https://your-account-id.r2.cloudflarestorage.com',
      region: 'auto',
      bucket: 'my-sync-bucket',
    ),
    credentials: S3Credentials(
      accessKeyId: 'R2_ACCESS_KEY',
      secretAccessKey: 'R2_SECRET',
    ),
  );

  // MinIO (local dev) — path-style addressing is typical.
  final minioAdapter = S3Adapter(
    config: S3Config(
      endpoint: 'http://localhost:9000',
      region: 'us-east-1',
      bucket: 'dev-bucket',
      usePathStyle: true,
    ),
    credentials: S3Credentials(
      accessKeyId: 'minioadmin',
      secretAccessKey: 'minioadmin',
    ),
  );

  // Plug any of these into SyncClient for a bidirectional sync.
  final client = SyncClient(adapter: awsAdapter);

  // A real run would point at a local directory:
  //   await client.sync(localPath: '/Users/you/data');
  print('S3 adapters configured (AWS, R2, MinIO). Ready to sync.');
  print(client);
  print(r2Adapter.config.baseUri);
  print(minioAdapter.config.baseUri);
}
