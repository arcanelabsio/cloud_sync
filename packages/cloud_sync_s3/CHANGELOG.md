## 0.1.1

Initial release. S3 + S3-compatible storage adapter for the cloud_sync family.

- `S3Adapter` implements `StorageAdapter` from `cloud_sync_core`
- `S3Config` — bucket, region, endpoint override, path-style toggle (for MinIO and others)
- `S3Credentials` — static credentials (access key + secret key, optional session token)
- `S3AuthClient` — `http.BaseClient` wrapper that signs every request with AWS SigV4
- Hand-rolled SigV4 implementation — no `aws_*` family dependencies
- SHA256 preservation via `x-amz-meta-sha256` custom metadata (read back via HeadObject)
- 50MB file size ceiling (no multipart upload in v1)
- Validated compatibility: AWS S3, Cloudflare R2, MinIO, Backblaze B2, Wasabi, DO Spaces
