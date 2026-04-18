/// S3 + S3-compatible storage adapter for the cloud_sync family.
///
/// Works against AWS S3, Cloudflare R2, MinIO, Backblaze B2, Wasabi,
/// DigitalOcean Spaces, and any other service implementing the S3 HTTP API.
library;

export 'src/aws_sigv4.dart';
export 'src/s3_adapter.dart';
export 'src/s3_auth_client.dart';
export 'src/s3_config.dart';
export 'src/s3_credentials.dart';
