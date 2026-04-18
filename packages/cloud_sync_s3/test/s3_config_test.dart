import 'package:test/test.dart';
import 'package:cloud_sync_s3/src/s3_config.dart';

void main() {
  group('S3Config — defaults', () {
    test('defaults to AWS virtual-hosted endpoint when endpoint null', () {
      final config = S3Config(region: 'us-east-1', bucket: 'my-bucket');
      expect(config.baseUri.toString(), 'https://s3.us-east-1.amazonaws.com');
    });

    test('respects explicit endpoint (R2 style)', () {
      final config = S3Config(
        endpoint: 'https://abc123.r2.cloudflarestorage.com',
        region: 'auto',
        bucket: 'my-bucket',
      );
      expect(
        config.baseUri.toString(),
        'https://abc123.r2.cloudflarestorage.com',
      );
    });

    test('respects explicit endpoint (MinIO local)', () {
      final config = S3Config(
        endpoint: 'http://localhost:9000',
        region: 'us-east-1',
        bucket: 'my-bucket',
        usePathStyle: true,
      );
      expect(config.baseUri.toString(), 'http://localhost:9000');
    });
  });

  group('S3Config.objectUri', () {
    test('virtual-hosted style: bucket becomes subdomain', () {
      final config = S3Config(region: 'us-east-1', bucket: 'my-bucket');
      final uri = config.objectUri('data/file.json');
      expect(uri.host, 'my-bucket.s3.us-east-1.amazonaws.com');
      expect(uri.path, '/data/file.json');
    });

    test('path style: bucket is first path segment', () {
      final config = S3Config(
        endpoint: 'http://localhost:9000',
        region: 'us-east-1',
        bucket: 'my-bucket',
        usePathStyle: true,
      );
      final uri = config.objectUri('data/file.json');
      expect(uri.host, 'localhost');
      expect(uri.path, '/my-bucket/data/file.json');
    });

    test('applies prefix with trailing slash handling', () {
      final config = S3Config(
        region: 'us-east-1',
        bucket: 'my-bucket',
        prefix: 'backups',
      );
      expect(config.objectUri('data.json').path, '/backups/data.json');
    });

    test('applies prefix that already has trailing slash (normalizes)', () {
      final config = S3Config(
        region: 'us-east-1',
        bucket: 'my-bucket',
        prefix: 'backups/',
      );
      expect(config.objectUri('data.json').path, '/backups/data.json');
    });

    test('no prefix → bare key', () {
      final config = S3Config(region: 'us-east-1', bucket: 'my-bucket');
      expect(config.objectUri('file.json').path, '/file.json');
    });
  });

  group('S3Config.bucketUri', () {
    test('virtual-hosted style: no bucket in path', () {
      final config = S3Config(region: 'us-east-1', bucket: 'my-bucket');
      final uri = config.bucketUri();
      expect(uri.host, 'my-bucket.s3.us-east-1.amazonaws.com');
      expect(uri.path, '');
    });

    test('path style: bucket as path segment', () {
      final config = S3Config(
        endpoint: 'http://localhost:9000',
        region: 'us-east-1',
        bucket: 'my-bucket',
        usePathStyle: true,
      );
      final uri = config.bucketUri();
      expect(uri.host, 'localhost');
      expect(uri.path, '/my-bucket');
    });

    test('appends query parameters for ListObjectsV2', () {
      final config = S3Config(region: 'us-east-1', bucket: 'my-bucket');
      final uri = config.bucketUri(
        queryParameters: {'list-type': '2', 'prefix': 'data/'},
      );
      expect(uri.queryParameters['list-type'], '2');
      expect(uri.queryParameters['prefix'], 'data/');
    });
  });
}
