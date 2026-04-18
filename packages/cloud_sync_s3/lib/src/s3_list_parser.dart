import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:xml/xml.dart';

/// Result of parsing a ListObjectsV2 response.
class S3ListResponse {
  /// Files in this response page. Keyed by the object key with the
  /// adapter's prefix stripped (so it's relative to the sync root).
  final Map<String, RemoteFileInfo> files;

  /// Continuation token if the response was truncated. `null` if this was
  /// the last page.
  final String? nextContinuationToken;

  S3ListResponse({required this.files, this.nextContinuationToken});
}

/// Parses S3's ListObjectsV2 XML response into [RemoteFileInfo] records.
///
/// Does NOT populate `sha256` — S3 returns ETag (MD5-based for single-part
/// uploads, opaque for multipart) which doesn't match the engine's SHA256
/// expectation. The adapter calls HeadObject separately to read
/// `x-amz-meta-sha256` custom metadata.
class S3ListParser {
  S3ListParser._();

  /// Parse a ListObjectsV2 XML body.
  ///
  /// [prefix] is optionally stripped from each key so returned paths are
  /// relative to the sync root. Null/empty prefix leaves keys untouched.
  static S3ListResponse parse(String xml, {String? prefix}) {
    final doc = XmlDocument.parse(xml);
    final root = doc.rootElement;

    final normalizedPrefix = _normalizePrefix(prefix);

    final files = <String, RemoteFileInfo>{};
    for (final contents in root.findElements('Contents')) {
      final key = _childText(contents, 'Key');
      if (key == null || key.isEmpty) continue;

      // Skip the prefix "folder" itself (S3 sometimes returns it as a zero-byte object)
      if (normalizedPrefix != null && key == normalizedPrefix) continue;

      final relativePath = _stripPrefix(key, normalizedPrefix);
      if (relativePath.isEmpty) continue;

      final lastModifiedStr = _childText(contents, 'LastModified');
      final sizeStr = _childText(contents, 'Size');

      files[relativePath] = RemoteFileInfo(
        path: relativePath,
        lastModified: lastModifiedStr != null
            ? DateTime.parse(lastModifiedStr)
            : DateTime.now(),
        sizeBytes: int.tryParse(sizeStr ?? '0') ?? 0,
      );
    }

    final isTruncated = _childText(root, 'IsTruncated') == 'true';
    final token = isTruncated
        ? _childText(root, 'NextContinuationToken')
        : null;

    return S3ListResponse(files: files, nextContinuationToken: token);
  }

  static String? _childText(XmlElement parent, String name) {
    final elements = parent.findElements(name);
    if (elements.isEmpty) return null;
    return elements.first.innerText;
  }

  /// Ensure prefix ends with `/` (S3 convention for "folder").
  static String? _normalizePrefix(String? prefix) {
    if (prefix == null || prefix.isEmpty) return null;
    return prefix.endsWith('/') ? prefix : '$prefix/';
  }

  static String _stripPrefix(String key, String? prefix) {
    if (prefix == null) return key;
    if (key.startsWith(prefix)) return key.substring(prefix.length);
    return key;
  }
}
