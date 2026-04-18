import 'dart:convert';
import 'package:cloud_sync_box/src/box_path_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const baseUrl = 'https://api.box.example/2.0';

  MockClient handlerWith(Map<String, http.Response> byUrl) {
    return MockClient((req) async {
      final url = req.url.toString();
      // Strip query params for matching, but preserve them for assertions
      final pathOnly = Uri.parse(url).replace(queryParameters: null).toString();
      return byUrl[url] ?? byUrl[pathOnly] ?? http.Response('not mocked: $url', 500);
    });
  }

  String itemsJson(List<Map<String, dynamic>> entries) =>
      jsonEncode({'entries': entries, 'total_count': entries.length});

  group('BoxPathResolver — basic walk', () {
    test('empty folder returns no files', () async {
      final client = handlerWith({
        '$baseUrl/folders/0/items?offset=0&limit=1000&fields=id,name,type,size,modified_at':
            http.Response(itemsJson([]), 200),
      });
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );
      expect(await resolver.allFiles(), isEmpty);
    });

    test('flat folder with files', () async {
      final client = handlerWith({
        '$baseUrl/folders/0/items?offset=0&limit=1000&fields=id,name,type,size,modified_at':
            http.Response(
              itemsJson([
                {
                  'id': '100',
                  'name': 'a.json',
                  'type': 'file',
                  'size': 10,
                  'modified_at': '2026-04-18T10:00:00Z',
                },
                {
                  'id': '101',
                  'name': 'b.json',
                  'type': 'file',
                  'size': 20,
                  'modified_at': '2026-04-18T11:00:00Z',
                },
              ]),
              200,
            ),
      });
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );
      final files = await resolver.allFiles();
      expect(files, hasLength(2));
      expect(files.map((f) => f.path), unorderedEquals(['a.json', 'b.json']));
      expect(await resolver.resolveExisting('a.json'), '100');
      expect(await resolver.resolveExisting('b.json'), '101');
    });

    test('nested folders recursively walked', () async {
      final client = handlerWith({
        '$baseUrl/folders/0/items?offset=0&limit=1000&fields=id,name,type,size,modified_at':
            http.Response(
              itemsJson([
                {
                  'id': '200',
                  'name': 'backups',
                  'type': 'folder',
                  'size': 0,
                  'modified_at': '2026-04-18T10:00:00Z',
                },
              ]),
              200,
            ),
        '$baseUrl/folders/200/items?offset=0&limit=1000&fields=id,name,type,size,modified_at':
            http.Response(
              itemsJson([
                {
                  'id': '201',
                  'name': 'data.json',
                  'type': 'file',
                  'size': 42,
                  'modified_at': '2026-04-18T10:30:00Z',
                },
              ]),
              200,
            ),
      });
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );
      final files = await resolver.allFiles();
      expect(files, hasLength(1));
      expect(files.first.path, 'backups/data.json');
      expect(files.first.size, 42);
      expect(await resolver.resolveExisting('backups'), '200');
      expect(await resolver.resolveExisting('backups/data.json'), '201');
    });
  });

  group('BoxPathResolver — caching', () {
    test('second allFiles() call does not re-fetch', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(itemsJson([]), 200);
      });
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );

      await resolver.allFiles();
      await resolver.allFiles();

      expect(calls, 1);
    });

    test('reset() forces fresh walk', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(itemsJson([]), 200);
      });
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );

      await resolver.allFiles();
      resolver.reset();
      await resolver.allFiles();

      expect(calls, 2);
    });

    test('register() makes new paths resolvable without re-walking', () async {
      final client = MockClient(
        (req) async => http.Response(itemsJson([]), 200),
      );
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );

      await resolver.allFiles();
      resolver.register('new.json', '999');
      expect(await resolver.resolveExisting('new.json'), '999');
    });
  });

  group('BoxPathResolver — ensureParent creates missing folders', () {
    test('returns root ID when path has no slash', () async {
      final client = MockClient(
        (req) async => http.Response(itemsJson([]), 200),
      );
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );
      expect(await resolver.ensureParent('data.json'), '0');
    });

    test('returns existing folder ID when parent exists in cache', () async {
      final client = handlerWith({
        '$baseUrl/folders/0/items?offset=0&limit=1000&fields=id,name,type,size,modified_at':
            http.Response(
              itemsJson([
                {
                  'id': '300',
                  'name': 'backups',
                  'type': 'folder',
                  'size': 0,
                  'modified_at': '2026-04-18T10:00:00Z',
                },
              ]),
              200,
            ),
        '$baseUrl/folders/300/items?offset=0&limit=1000&fields=id,name,type,size,modified_at':
            http.Response(itemsJson([]), 200),
      });
      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );

      expect(await resolver.ensureParent('backups/data.json'), '300');
    });

    test('creates missing folder segments', () async {
      final postRequests = <http.Request>[];
      final client = MockClient((req) async {
        if (req.method == 'GET' &&
            req.url.toString().startsWith('$baseUrl/folders/') &&
            req.url.toString().contains('/items')) {
          return http.Response(itemsJson([]), 200);
        }
        if (req.method == 'POST' && req.url.toString() == '$baseUrl/folders') {
          postRequests.add(req);
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final name = body['name'] as String;
          // Fabricate new IDs based on request order
          final newId = '5${postRequests.length}';
          return http.Response(
            jsonEncode({'id': newId, 'name': name, 'type': 'folder'}),
            201,
          );
        }
        return http.Response('unexpected', 500);
      });

      final resolver = BoxPathResolver(
        httpClient: client,
        baseUrl: baseUrl,
        rootFolderId: '0',
      );

      final parentId = await resolver.ensureParent('a/b/c/data.json');
      expect(postRequests, hasLength(3));
      expect(parentId, '53'); // third folder created
      // Cache is populated for each segment
      expect(await resolver.resolveExisting('a'), '51');
      expect(await resolver.resolveExisting('a/b'), '52');
      expect(await resolver.resolveExisting('a/b/c'), '53');
    });
  });
}
