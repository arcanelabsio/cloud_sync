import 'dart:convert';
import 'package:cloud_sync_box/src/box_adapter.dart';
import 'package:cloud_sync_box/src/box_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const baseUrl = 'https://api.box.example/2.0';
  const uploadUrl = 'https://upload.box.example/api/2.0';
  final config = BoxConfig(
    rootFolderId: '0',
    baseUrl: baseUrl,
    uploadUrl: uploadUrl,
  );

  String itemsJson(List<Map<String, dynamic>> entries) =>
      jsonEncode({'entries': entries, 'total_count': entries.length});

  group('BoxAdapter.ensureFolder', () {
    test('succeeds when root folder accessible', () async {
      final client = MockClient((req) async {
        if (req.method == 'GET' && req.url.path.endsWith('/folders/0')) {
          return http.Response(jsonEncode({'id': '0', 'type': 'folder'}), 200);
        }
        return http.Response('unexpected', 500);
      });
      final adapter = BoxAdapter(config: config, httpClient: client);
      await adapter.ensureFolder();
    });

    test('throws on 404', () async {
      final client = MockClient((req) async => http.Response('Not Found', 404));
      final adapter = BoxAdapter(config: config, httpClient: client);
      await expectLater(adapter.ensureFolder(), throwsA(isA<Exception>()));
    });
  });

  group('BoxAdapter.uploadFile', () {
    test('uploads new file with SHA256 metadata', () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((req) async {
        requests.add(req);
        final url = req.url.toString();

        if (req.method == 'GET' && url.contains('/folders/0/items')) {
          return http.Response(itemsJson([]), 200);
        }
        if (req.method == 'POST' && url == '$uploadUrl/files/content') {
          return http.Response(
            jsonEncode({
              'entries': [
                {'id': '900', 'type': 'file', 'name': 'data.json'},
              ],
            }),
            201,
          );
        }
        if (req.method == 'POST' &&
            url == '$baseUrl/files/900/metadata/global/properties') {
          return http.Response(jsonEncode({'sha256': 'stored'}), 201);
        }
        return http.Response('unexpected $url', 500);
      });

      final adapter = BoxAdapter(config: config, httpClient: client);
      await adapter.uploadFile('data.json', utf8.encode('{"k":"v"}'));

      final methods = requests.map((r) => '${r.method} ${r.url.path}').toList();
      expect(methods, contains('GET /2.0/folders/0/items'));
      expect(methods, contains('POST /api/2.0/files/content'));
      expect(
        methods,
        contains('POST /2.0/files/900/metadata/global/properties'),
      );
    });

    test('uploads version (replaces existing) when file already exists',
        () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((req) async {
        requests.add(req);
        final url = req.url.toString();

        if (req.method == 'GET' && url.contains('/folders/0/items')) {
          return http.Response(
            itemsJson([
              {
                'id': '500',
                'name': 'existing.json',
                'type': 'file',
                'size': 10,
                'modified_at': '2026-04-18T10:00:00Z',
              },
            ]),
            200,
          );
        }
        if (req.method == 'POST' && url == '$uploadUrl/files/500/content') {
          return http.Response(
            jsonEncode({
              'entries': [
                {'id': '500', 'type': 'file'},
              ],
            }),
            200,
          );
        }
        if (url.contains('/metadata/global/properties')) {
          return http.Response(jsonEncode({'sha256': 'stored'}), 201);
        }
        return http.Response('unexpected $url', 500);
      });

      final adapter = BoxAdapter(config: config, httpClient: client);
      await adapter.uploadFile('existing.json', utf8.encode('new content'));

      // Version endpoint hit (upload/files/{id}/content), not /files/content
      final uploadHit = requests.any(
        (r) =>
            r.method == 'POST' &&
            r.url.toString() == '$uploadUrl/files/500/content',
      );
      expect(uploadHit, isTrue);
    });

    test('falls back to PUT JSON Patch when metadata POST returns 409',
        () async {
      final metadataRequests = <http.BaseRequest>[];
      final client = MockClient((req) async {
        final url = req.url.toString();
        if (req.method == 'GET' && url.contains('/folders/0/items')) {
          return http.Response(itemsJson([]), 200);
        }
        if (req.method == 'POST' && url == '$uploadUrl/files/content') {
          return http.Response(
            jsonEncode({
              'entries': [
                {'id': '700', 'type': 'file', 'name': 'a.json'},
              ],
            }),
            201,
          );
        }
        if (url.contains('/metadata/global/properties')) {
          metadataRequests.add(req);
          if (req.method == 'POST') {
            return http.Response('conflict', 409);
          }
          if (req.method == 'PUT') {
            return http.Response(
              jsonEncode({'sha256': 'updated'}),
              200,
            );
          }
        }
        return http.Response('unexpected $url', 500);
      });

      final adapter = BoxAdapter(config: config, httpClient: client);
      await adapter.uploadFile('a.json', utf8.encode('x'));

      final methods = metadataRequests.map((r) => r.method).toList();
      expect(methods, ['POST', 'PUT']);
    });
  });

  group('BoxAdapter.downloadFile', () {
    test('GETs /files/{id}/content after resolving path', () async {
      final client = MockClient((req) async {
        final url = req.url.toString();
        if (req.method == 'GET' && url.contains('/folders/0/items')) {
          return http.Response(
            itemsJson([
              {
                'id': '800',
                'name': 'hello.txt',
                'type': 'file',
                'size': 5,
                'modified_at': '2026-04-18T10:00:00Z',
              },
            ]),
            200,
          );
        }
        if (req.method == 'GET' && url == '$baseUrl/files/800/content') {
          return http.Response.bytes(utf8.encode('hello'), 200);
        }
        return http.Response('unexpected $url', 500);
      });

      final adapter = BoxAdapter(config: config, httpClient: client);
      final bytes = await adapter.downloadFile('hello.txt');
      expect(utf8.decode(bytes), 'hello');
    });

    test('throws on missing path', () async {
      final client = MockClient(
        (req) async => http.Response(itemsJson([]), 200),
      );
      final adapter = BoxAdapter(config: config, httpClient: client);
      await expectLater(
        adapter.downloadFile('missing.json'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('BoxAdapter.deleteFile', () {
    test('DELETEs /files/{id} and invalidates cache', () async {
      final client = MockClient((req) async {
        final url = req.url.toString();
        if (req.method == 'GET' && url.contains('/folders/0/items')) {
          return http.Response(
            itemsJson([
              {
                'id': '600',
                'name': 'goodbye.txt',
                'type': 'file',
                'size': 5,
                'modified_at': '2026-04-18T10:00:00Z',
              },
            ]),
            200,
          );
        }
        if (req.method == 'DELETE' && url == '$baseUrl/files/600') {
          return http.Response('', 204);
        }
        return http.Response('unexpected $url', 500);
      });

      final adapter = BoxAdapter(config: config, httpClient: client);
      await adapter.deleteFile('goodbye.txt');
      // After delete, resolver should no longer know about this path
      expect(await adapter.resolver.resolveExisting('goodbye.txt'), isNull);
    });

    test('no-op when path does not exist', () async {
      final client = MockClient(
        (req) async => http.Response(itemsJson([]), 200),
      );
      final adapter = BoxAdapter(config: config, httpClient: client);
      // Should not throw
      await adapter.deleteFile('nonexistent.json');
    });
  });

  group('BoxAdapter.listFiles', () {
    test('returns files with sha256 from metadata', () async {
      final client = MockClient((req) async {
        final url = req.url.toString();
        if (req.method == 'GET' && url.contains('/folders/0/items')) {
          return http.Response(
            itemsJson([
              {
                'id': '10',
                'name': 'a.json',
                'type': 'file',
                'size': 100,
                'modified_at': '2026-04-18T10:00:00Z',
              },
              {
                'id': '11',
                'name': 'b.json',
                'type': 'file',
                'size': 200,
                'modified_at': '2026-04-18T11:00:00Z',
              },
            ]),
            200,
          );
        }
        if (url == '$baseUrl/files/10/metadata/global/properties') {
          return http.Response(jsonEncode({'sha256': 'hash-a'}), 200);
        }
        if (url == '$baseUrl/files/11/metadata/global/properties') {
          // Simulates a file uploaded outside the library — no metadata
          return http.Response('Not found', 404);
        }
        return http.Response('unexpected $url', 500);
      });

      final adapter = BoxAdapter(config: config, httpClient: client);
      final files = await adapter.listFiles();

      expect(files, hasLength(2));
      expect(files['a.json']!.sha256, 'hash-a');
      expect(files['a.json']!.sizeBytes, 100);
      expect(files['b.json']!.sha256, isNull);
    });
  });
}
