## 0.1.0

Initial release. Box Content API adapter for the cloud_sync family.

- `BoxAdapter` implements `StorageAdapter` from `cloud_sync_core`
- `BoxConfig` — rootFolderId, optional base/upload URL overrides
- `BoxAuthClient` — `http.BaseClient` wrapper that injects Bearer token
- `BoxPathResolver` — lazy recursive walk + in-memory path↔ID cache; creates missing folder segments on demand
- SHA256 preservation via `/files/{id}/metadata/global/properties` custom metadata (Box's native SHA1 is not compatible with the engine's SHA256 contract)
- 50MB file size ceiling (single-request upload — no chunked upload in v1)
- OAuth2 Bearer token only — JWT App Auth requires consumer-supplied authenticated `http.Client`
