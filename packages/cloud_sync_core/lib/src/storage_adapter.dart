/// Abstract interface for remote storage operations.
///
/// Every cloud backend (Google Drive, S3, Box, ...) implements this interface.
/// The [SyncEngine] and [SyncClient] work against `StorageAdapter` without
/// any knowledge of the underlying backend.
abstract class StorageAdapter {
  /// Ensure the remote sync root (folder, bucket, prefix) exists.
  /// Called before any list/upload/download/delete operation.
  Future<void> ensureFolder();

  /// List all files in the remote sync root.
  /// Returns map of path → [RemoteFileInfo].
  Future<Map<String, RemoteFileInfo>> listFiles();

  /// Upload [content] to [remotePath].
  Future<void> uploadFile(String remotePath, List<int> content);

  /// Download the file at [remotePath] and return its bytes.
  Future<List<int>> downloadFile(String remotePath);

  /// Delete the file at [remotePath].
  Future<void> deleteFile(String remotePath);
}

/// Metadata for a file in remote storage.
class RemoteFileInfo {
  final String path;
  final String? sha256;
  final DateTime lastModified;
  final int sizeBytes;

  const RemoteFileInfo({
    required this.path,
    this.sha256,
    required this.lastModified,
    this.sizeBytes = 0,
  });
}
