import 'dart:convert';
import 'package:http/http.dart' as http;

/// A Box file or folder item discovered during tree traversal.
class BoxItem {
  /// Path relative to the resolver's root folder.
  final String path;

  /// Box object ID.
  final String id;

  /// `"file"` or `"folder"`.
  final String type;

  /// Size in bytes. Folders have size 0 (ignored by sync anyway).
  final int size;

  /// Last modification timestamp from Box.
  final DateTime modifiedAt;

  const BoxItem({
    required this.path,
    required this.id,
    required this.type,
    required this.size,
    required this.modifiedAt,
  });
}

/// Translates between path-based sync operations and Box's ID-based API.
///
/// On first access, performs a recursive walk below `rootFolderId` and
/// populates an in-memory `path → id` cache. Subsequent lookups are O(1).
/// New files and folders created during the session register themselves
/// in the cache via [register].
///
/// Single-client assumption: mutations from other Box clients won't
/// invalidate this cache automatically. For that, reconstruct the resolver.
class BoxPathResolver {
  final http.Client httpClient;
  final String baseUrl;
  final String rootFolderId;
  static const _pageLimit = 1000;

  final Map<String, String> _pathToId = {};
  final Map<String, BoxItem> _items = {};
  bool _walked = false;

  BoxPathResolver({
    required this.httpClient,
    required this.baseUrl,
    required this.rootFolderId,
  }) {
    _pathToId[''] = rootFolderId;
  }

  /// Return all file items discovered under the root. Triggers a lazy
  /// recursive walk on first call.
  Future<List<BoxItem>> allFiles() async {
    await _ensureWalked();
    return _items.values.where((i) => i.type == 'file').toList();
  }

  /// Resolve an existing path to its Box ID, or null if no such path exists.
  /// Triggers a walk if the cache hasn't been populated yet.
  Future<String?> resolveExisting(String path) async {
    await _ensureWalked();
    return _pathToId[path];
  }

  /// Ensure every folder in the parent chain of [path] exists, creating
  /// missing folders as needed. Returns the ID of the directly-containing
  /// parent folder.
  ///
  /// Example: for path `"backups/2026/april.json"`, creates `backups`
  /// and `backups/2026` if they don't exist, and returns the ID of
  /// `backups/2026`.
  Future<String> ensureParent(String path) async {
    await _ensureWalked();

    final lastSlash = path.lastIndexOf('/');
    if (lastSlash < 0) return rootFolderId;
    final parentPath = path.substring(0, lastSlash);

    if (_pathToId.containsKey(parentPath)) return _pathToId[parentPath]!;

    // Walk the path, creating missing segments.
    final segments = parentPath.split('/');
    String parentId = rootFolderId;
    String accumulated = '';
    for (final segment in segments) {
      accumulated = accumulated.isEmpty ? segment : '$accumulated/$segment';
      if (_pathToId.containsKey(accumulated)) {
        parentId = _pathToId[accumulated]!;
        continue;
      }
      parentId = await _createFolder(parentId, segment);
      _pathToId[accumulated] = parentId;
    }
    return parentId;
  }

  /// Register a newly-created path → ID mapping (e.g., after upload).
  void register(String path, String id, {BoxItem? item}) {
    _pathToId[path] = id;
    if (item != null) _items[path] = item;
  }

  /// Remove a path from the cache (e.g., after delete).
  void invalidate(String path) {
    _pathToId.remove(path);
    _items.remove(path);
  }

  /// Force a fresh walk on next lookup.
  void reset() {
    _pathToId
      ..clear()
      ..[''] = rootFolderId;
    _items.clear();
    _walked = false;
  }

  // ---------- internals ----------

  Future<void> _ensureWalked() async {
    if (_walked) return;
    await _walkRecursive(rootFolderId, '');
    _walked = true;
  }

  Future<void> _walkRecursive(String folderId, String prefix) async {
    var offset = 0;
    while (true) {
      final uri = Uri.parse(
        '$baseUrl/folders/$folderId/items'
        '?offset=$offset&limit=$_pageLimit'
        '&fields=id,name,type,size,modified_at',
      );
      final response = await httpClient.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
          'Box folder list failed: ${response.statusCode} — ${response.body}',
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = (body['entries'] as List).cast<Map<String, dynamic>>();

      for (final entry in entries) {
        final id = entry['id'] as String;
        final name = entry['name'] as String;
        final type = entry['type'] as String;
        final path = prefix.isEmpty ? name : '$prefix/$name';
        _pathToId[path] = id;

        if (type == 'file') {
          _items[path] = BoxItem(
            path: path,
            id: id,
            type: type,
            size: (entry['size'] as num?)?.toInt() ?? 0,
            modifiedAt: entry['modified_at'] != null
                ? DateTime.parse(entry['modified_at'] as String)
                : DateTime.now(),
          );
        } else if (type == 'folder') {
          await _walkRecursive(id, path);
        }
      }

      if (entries.length < _pageLimit) break;
      offset += _pageLimit;
    }
  }

  Future<String> _createFolder(String parentId, String name) async {
    final uri = Uri.parse('$baseUrl/folders');
    final response = await httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'parent': {'id': parentId},
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Box create folder failed: ${response.statusCode} — ${response.body}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['id'] as String;
  }
}
