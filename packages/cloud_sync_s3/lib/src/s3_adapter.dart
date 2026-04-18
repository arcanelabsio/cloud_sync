import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 's3_auth_client.dart';
import 's3_config.dart';
import 's3_credentials.dart';
import 's3_list_parser.dart';

/// S3 implementation of [StorageAdapter].
///
/// Works against AWS S3 and any S3-compatible service (R2, MinIO, B2,
/// Wasabi, DO Spaces) — customize via [S3Config].
///
/// SHA256 preservation:
/// - On `uploadFile`, the adapter computes the payload's SHA256 and stores
///   it in `x-amz-meta-sha256` custom metadata.
/// - On `listFiles`, after the ListObjectsV2 pass, each object is queried
///   with HeadObject to read the metadata back. Files uploaded outside
///   this library (without the metadata) surface with `sha256 == null`,
///   at which point the engine falls back to download-and-hash.
///
/// File size ceiling: ~50MB. The adapter uses single-request `PutObject`;
/// larger files may fail or exhaust memory. Multipart upload is planned
/// for a future release.
class S3Adapter implements StorageAdapter {
  final S3Config config;
  final http.Client _httpClient;

  /// Primary constructor — signs every request with SigV4.
  S3Adapter({
    required this.config,
    required S3Credentials credentials,
    http.Client? innerClient,
  }) : _httpClient = S3AuthClient(
         config: config,
         credentials: credentials,
         inner: innerClient,
       );

  /// Test-only constructor that skips SigV4 signing. Use when driving the
  /// adapter with a mock HTTP client to assert request shape without having
  /// to reconstruct the signature in tests.
  @visibleForTesting
  S3Adapter.withHttpClient({
    required this.config,
    required http.Client httpClient,
  }) : _httpClient = httpClient;

  @override
  Future<void> ensureFolder() async {
    final uri = config.bucketUri();
    final response = await _httpClient.head(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'S3 bucket "${config.bucket}" not accessible '
        '(${response.statusCode}). Verify the bucket exists, the region is '
        'correct, and the credentials grant s3:ListBucket.',
      );
    }
  }

  @override
  Future<Map<String, RemoteFileInfo>> listFiles() async {
    final results = <String, RemoteFileInfo>{};
    String? continuationToken;

    do {
      final queryParams = <String, String>{'list-type': '2'};
      if (config.prefix != null && config.prefix!.isNotEmpty) {
        queryParams['prefix'] = config.prefix!.endsWith('/')
            ? config.prefix!
            : '${config.prefix!}/';
      }
      if (continuationToken != null) {
        queryParams['continuation-token'] = continuationToken;
      }

      final uri = config.bucketUri(queryParameters: queryParams);
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
          'ListObjectsV2 failed: ${response.statusCode} — ${response.body}',
        );
      }

      final parsed = S3ListParser.parse(response.body, prefix: config.prefix);

      for (final entry in parsed.files.entries) {
        final sha256Hex = await _fetchSha256Metadata(entry.key);
        results[entry.key] = RemoteFileInfo(
          path: entry.key,
          sha256: sha256Hex,
          lastModified: entry.value.lastModified,
          sizeBytes: entry.value.sizeBytes,
        );
      }

      continuationToken = parsed.nextContinuationToken;
    } while (continuationToken != null);

    return results;
  }

  /// HeadObject on the given key. Returns the value of `x-amz-meta-sha256`
  /// if present, otherwise null (engine will fall back to download-hash).
  Future<String?> _fetchSha256Metadata(String key) async {
    final uri = config.objectUri(key);
    final response = await _httpClient.head(uri);
    if (response.statusCode != 200) return null;
    return response.headers['x-amz-meta-sha256'];
  }

  @override
  Future<void> uploadFile(String remotePath, List<int> content) async {
    final uri = config.objectUri(remotePath);
    final hash = sha256.convert(content).toString();

    final request = http.Request('PUT', uri);
    request.bodyBytes = content;
    request.headers['x-amz-meta-sha256'] = hash;

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'PutObject failed: ${response.statusCode} — ${response.body}',
      );
    }
  }

  @override
  Future<List<int>> downloadFile(String remotePath) async {
    final uri = config.objectUri(remotePath);
    final response = await _httpClient.get(uri);
    if (response.statusCode == 404) {
      throw Exception('File not found in S3: $remotePath');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'GetObject failed: ${response.statusCode} — ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final uri = config.objectUri(remotePath);
    final response = await _httpClient.delete(uri);
    // S3 returns 204 No Content on successful delete, or 200 for some compat
    // services. Both count as success.
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'DeleteObject failed: ${response.statusCode} — ${response.body}',
      );
    }
  }
}
