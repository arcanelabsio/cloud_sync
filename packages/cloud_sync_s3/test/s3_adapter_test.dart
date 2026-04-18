import 'dart:convert';
import 'package:cloud_sync_s3/src/s3_adapter.dart';
import 'package:cloud_sync_s3/src/s3_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Captures every request and dispatches to a per-test handler.
/// Uses `package:http/testing.dart` MockClient — simpler than hand-rolling
/// BaseClient, and keeps test assertions focused on request shape.
MockClient mockClient(Future<http.Response> Function(http.Request) handler) {
  return MockClient(handler);
}

void main() {
  final config = S3Config(region: 'us-east-1', bucket: 'my-bucket');

  group('S3Adapter.ensureFolder', () {
    test('sends HEAD to bucket URI, succeeds on 200', () async {
      http.Request? captured;
      final client = mockClient((req) async {
        captured = req;
        return http.Response('', 200);
      });
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      await adapter.ensureFolder();

      expect(captured!.method, 'HEAD');
      expect(captured!.url.host, 'my-bucket.s3.us-east-1.amazonaws.com');
    });

    test('throws on 404 bucket not found', () async {
      final client = mockClient((req) async => http.Response('Not Found', 404));
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      await expectLater(
        adapter.ensureFolder(),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on 403 access denied', () async {
      final client = mockClient((req) async => http.Response('Forbidden', 403));
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      await expectLater(
        adapter.ensureFolder(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('S3Adapter.uploadFile', () {
    test('PUTs to object URI with x-amz-meta-sha256 header', () async {
      http.BaseRequest? captured;
      final client = mockClient((req) async {
        captured = req;
        return http.Response('', 200);
      });
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      final content = utf8.encode('{"data":1}');
      await adapter.uploadFile('data.json', content);

      expect(captured!.method, 'PUT');
      expect(captured!.url.host, 'my-bucket.s3.us-east-1.amazonaws.com');
      expect(captured!.url.path, '/data.json');
      // SHA256 of '{"data":1}' = precomputed
      expect(
        captured!.headers['x-amz-meta-sha256'],
        isA<String>().having((s) => s.length, 'length', 64),
      );
    });

    test('uploads to path-style URL when usePathStyle=true', () async {
      final pathConfig = S3Config(
        endpoint: 'http://localhost:9000',
        region: 'us-east-1',
        bucket: 'my-bucket',
        usePathStyle: true,
      );
      http.BaseRequest? captured;
      final client = mockClient((req) async {
        captured = req;
        return http.Response('', 200);
      });
      final adapter = S3Adapter.withHttpClient(
        config: pathConfig,
        httpClient: client,
      );

      await adapter.uploadFile('data.json', utf8.encode('x'));

      expect(captured!.url.host, 'localhost');
      expect(captured!.url.path, '/my-bucket/data.json');
    });

    test('respects prefix in object URL', () async {
      final prefixedConfig = S3Config(
        region: 'us-east-1',
        bucket: 'my-bucket',
        prefix: 'backups',
      );
      http.BaseRequest? captured;
      final client = mockClient((req) async {
        captured = req;
        return http.Response('', 200);
      });
      final adapter = S3Adapter.withHttpClient(
        config: prefixedConfig,
        httpClient: client,
      );

      await adapter.uploadFile('data.json', utf8.encode('x'));

      expect(captured!.url.path, '/backups/data.json');
    });

    test('throws on 5xx error', () async {
      final client = mockClient(
        (req) async => http.Response('Server error', 500),
      );
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      await expectLater(
        adapter.uploadFile('data.json', utf8.encode('x')),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('S3Adapter.downloadFile', () {
    test('GETs object URI and returns body bytes', () async {
      final client = mockClient(
        (req) async => http.Response.bytes(utf8.encode('{"hello":"world"}'), 200),
      );
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      final bytes = await adapter.downloadFile('data.json');
      expect(utf8.decode(bytes), '{"hello":"world"}');
    });

    test('throws on 404', () async {
      final client = mockClient(
        (req) async => http.Response('Not Found', 404),
      );
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      await expectLater(
        adapter.downloadFile('missing.json'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('S3Adapter.deleteFile', () {
    test('DELETEs object URI, succeeds on 204', () async {
      http.BaseRequest? captured;
      final client = mockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      await adapter.deleteFile('data.json');

      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/data.json');
    });

    test('succeeds on 200 (S3-compatible services may return 200)', () async {
      final client = mockClient((req) async => http.Response('', 200));
      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      await adapter.deleteFile('data.json');
    });
  });

  group('S3Adapter.listFiles', () {
    const listResponse = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <KeyCount>2</KeyCount>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>a.json</Key>
    <LastModified>2026-04-18T10:00:00.000Z</LastModified>
    <Size>10</Size>
  </Contents>
  <Contents>
    <Key>b.json</Key>
    <LastModified>2026-04-18T11:00:00.000Z</LastModified>
    <Size>20</Size>
  </Contents>
</ListBucketResult>''';

    test('parses files and fetches sha256 from HeadObject per file', () async {
      final requests = <http.BaseRequest>[];
      final client = mockClient((req) async {
        requests.add(req);
        if (req.method == 'GET' && req.url.queryParameters['list-type'] == '2') {
          return http.Response(listResponse, 200);
        }
        if (req.method == 'HEAD' && req.url.path == '/a.json') {
          return http.Response(
            '',
            200,
            headers: {'x-amz-meta-sha256': 'abc123'},
          );
        }
        if (req.method == 'HEAD' && req.url.path == '/b.json') {
          return http.Response(
            '',
            200,
            headers: {'x-amz-meta-sha256': 'def456'},
          );
        }
        return http.Response('unexpected', 500);
      });

      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      final files = await adapter.listFiles();

      expect(files, hasLength(2));
      expect(files['a.json']!.sha256, 'abc123');
      expect(files['b.json']!.sha256, 'def456');
      expect(files['a.json']!.sizeBytes, 10);
      // Confirms list + 2 head calls
      expect(requests.where((r) => r.method == 'GET'), hasLength(1));
      expect(requests.where((r) => r.method == 'HEAD'), hasLength(2));
    });

    test('leaves sha256 null when HeadObject lacks metadata', () async {
      final client = mockClient((req) async {
        if (req.method == 'GET') return http.Response(listResponse, 200);
        // HEAD returns 200 but no x-amz-meta-sha256 header
        return http.Response('', 200);
      });

      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      final files = await adapter.listFiles();
      expect(files['a.json']!.sha256, isNull);
      expect(files['b.json']!.sha256, isNull);
    });

    test('follows continuation token for pagination', () async {
      const page1 = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>true</IsTruncated>
  <NextContinuationToken>next-token-xyz</NextContinuationToken>
  <Contents>
    <Key>page1.json</Key>
    <LastModified>2026-04-18T10:00:00.000Z</LastModified>
    <Size>1</Size>
  </Contents>
</ListBucketResult>''';
      const page2 = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>page2.json</Key>
    <LastModified>2026-04-18T11:00:00.000Z</LastModified>
    <Size>2</Size>
  </Contents>
</ListBucketResult>''';

      var listCalls = 0;
      final client = mockClient((req) async {
        if (req.method == 'HEAD') return http.Response('', 200);
        listCalls++;
        final token = req.url.queryParameters['continuation-token'];
        if (token == null) return http.Response(page1, 200);
        if (token == 'next-token-xyz') return http.Response(page2, 200);
        return http.Response('unexpected token', 500);
      });

      final adapter = S3Adapter.withHttpClient(
        config: config,
        httpClient: client,
      );

      final files = await adapter.listFiles();
      expect(listCalls, 2);
      expect(files.keys, unorderedEquals(['page1.json', 'page2.json']));
    });
  });
}
