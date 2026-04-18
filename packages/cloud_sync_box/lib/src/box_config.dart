/// Configuration for the Box adapter.
///
/// Box splits its API across two hosts: `api.box.com` for metadata and
/// content operations that return JSON, and `upload.box.com` for the
/// multipart upload endpoint. Both are overridable for testing.
class BoxConfig {
  /// Box folder ID to sync under. `"0"` is the user's Box root.
  /// Use a sub-folder ID to sandbox the adapter to a specific area.
  final String rootFolderId;

  /// Base URL for content/metadata API. Default: `https://api.box.com/2.0`.
  final String baseUrl;

  /// Base URL for file uploads. Default: `https://upload.box.com/api/2.0`.
  final String uploadUrl;

  const BoxConfig({
    required this.rootFolderId,
    this.baseUrl = 'https://api.box.com/2.0',
    this.uploadUrl = 'https://upload.box.com/api/2.0',
  });
}
