import 'dart:convert';
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'box_config.dart';
import 'box_path_resolver.dart';

/// Box Content API implementation of [StorageAdapter].
///
/// Translates path-based sync operations against Box's ID-based API via
/// a [BoxPathResolver]. SHA256 is stored as Box custom metadata at
/// `/files/{id}/metadata/global/properties` because Box's native hash
/// (SHA1) does not match the engine's SHA256 contract.
///
/// File size ceiling: ~50MB. The adapter uses Box's single-request upload
/// endpoint. Chunked upload for larger files is planned for a future release.
class BoxAdapter implements StorageAdapter {
  final BoxConfig config;
  final http.Client _httpClient;
  late final BoxPathResolver _resolver;

  /// Caller provides an authenticated [httpClient] (e.g., [BoxAuthClient]
  /// wrapping an OAuth2 Bearer token, or a custom client implementing JWT
  /// App Auth). The adapter does not manage token lifecycle.
  BoxAdapter({required this.config, required http.Client httpClient})
      : _httpClient = httpClient {
    _resolver = BoxPathResolver(
      httpClient: _httpClient,
      baseUrl: config.baseUrl,
      rootFolderId: config.rootFolderId,
    );
  }

  /// Internal resolver — exposed for testing and for consumers that need to
  /// invalidate the cache (e.g., after external mutations).
  @visibleForTesting
  BoxPathResolver get resolver => _resolver;

  @override
  Future<void> ensureFolder() async {
    final uri = Uri.parse('${config.baseUrl}/folders/${config.rootFolderId}');
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Box root folder "${config.rootFolderId}" not accessible '
        '(${response.statusCode}). Verify the folder ID is correct and '
        'the OAuth token has read access.',
      );
    }
  }

  @override
  Future<Map<String, RemoteFileInfo>> listFiles() async {
    final items = await _resolver.allFiles();
    final result = <String, RemoteFileInfo>{};

    for (final item in items) {
      final hash = await _fetchSha256Metadata(item.id);
      result[item.path] = RemoteFileInfo(
        path: item.path,
        sha256: hash,
        lastModified: item.modifiedAt,
        sizeBytes: item.size,
      );
    }

    return result;
  }

  @override
  Future<void> uploadFile(String remotePath, List<int> content) async {
    final hash = sha256.convert(content).toString();
    final fileName = _fileName(remotePath);

    final existingId = await _resolver.resolveExisting(remotePath);
    final String fileId;
    if (existingId != null) {
      fileId = await _uploadVersion(existingId, fileName, content);
    } else {
      final parentId = await _resolver.ensureParent(remotePath);
      fileId = await _uploadNew(parentId, fileName, content);
      _resolver.register(remotePath, fileId);
    }

    await _setSha256Metadata(fileId, hash);
  }

  @override
  Future<List<int>> downloadFile(String remotePath) async {
    final fileId = await _resolver.resolveExisting(remotePath);
    if (fileId == null) {
      throw Exception('File not found in Box: $remotePath');
    }
    final uri = Uri.parse('${config.baseUrl}/files/$fileId/content');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Box download failed: ${response.statusCode} — ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final fileId = await _resolver.resolveExisting(remotePath);
    if (fileId == null) return;
    final uri = Uri.parse('${config.baseUrl}/files/$fileId');
    final response = await _httpClient.delete(uri);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(
        'Box delete failed: ${response.statusCode} — ${response.body}',
      );
    }
    _resolver.invalidate(remotePath);
  }

  // ---------- internals ----------

  String _fileName(String remotePath) {
    final lastSlash = remotePath.lastIndexOf('/');
    return lastSlash < 0 ? remotePath : remotePath.substring(lastSlash + 1);
  }

  Future<String?> _fetchSha256Metadata(String fileId) async {
    final uri = Uri.parse(
      '${config.baseUrl}/files/$fileId/metadata/global/properties',
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) return null;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['sha256'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setSha256Metadata(String fileId, String hash) async {
    final uri = Uri.parse(
      '${config.baseUrl}/files/$fileId/metadata/global/properties',
    );
    // Try POST (create). If 409 (already exists), PUT with JSON Patch.
    final createResponse = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sha256': hash}),
    );
    if (createResponse.statusCode >= 200 && createResponse.statusCode < 300) {
      return;
    }
    if (createResponse.statusCode == 409) {
      final patchRequest = http.Request('PUT', uri);
      patchRequest.headers['Content-Type'] = 'application/json-patch+json';
      patchRequest.body = jsonEncode([
        {'op': 'replace', 'path': '/sha256', 'value': hash},
      ]);
      final streamed = await _httpClient.send(patchRequest);
      final patchResponse = await http.Response.fromStream(streamed);
      if (patchResponse.statusCode < 200 || patchResponse.statusCode >= 300) {
        throw Exception(
          'Box metadata update failed: ${patchResponse.statusCode} '
          '— ${patchResponse.body}',
        );
      }
      return;
    }
    throw Exception(
      'Box metadata create failed: ${createResponse.statusCode} '
      '— ${createResponse.body}',
    );
  }

  Future<String> _uploadNew(
    String parentId,
    String name,
    List<int> content,
  ) async {
    final uri = Uri.parse('${config.uploadUrl}/files/content');
    final request = http.MultipartRequest('POST', uri);
    request.fields['attributes'] = jsonEncode({
      'name': name,
      'parent': {'id': parentId},
    });
    request.files.add(
      http.MultipartFile.fromBytes('file', content, filename: name),
    );
    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Box upload failed: ${response.statusCode} — ${response.body}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = body['entries'] as List;
    return (entries.first as Map<String, dynamic>)['id'] as String;
  }

  Future<String> _uploadVersion(
    String fileId,
    String name,
    List<int> content,
  ) async {
    final uri = Uri.parse('${config.uploadUrl}/files/$fileId/content');
    final request = http.MultipartRequest('POST', uri);
    request.fields['attributes'] = jsonEncode({'name': name});
    request.files.add(
      http.MultipartFile.fromBytes('file', content, filename: name),
    );
    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Box version upload failed: ${response.statusCode} — ${response.body}',
      );
    }
    return fileId;
  }
}
