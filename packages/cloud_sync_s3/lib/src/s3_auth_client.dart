import 'package:http/http.dart' as http;

import 'aws_sigv4.dart';
import 's3_config.dart';
import 's3_credentials.dart';

/// An [http.BaseClient] that signs every outgoing request with AWS SigV4.
///
/// Intercepts each request, computes the signature from [config] + [credentials],
/// attaches `Authorization`, `X-Amz-Date`, `X-Amz-Content-Sha256`, and
/// (if using STS) `X-Amz-Security-Token`, then forwards to the inner client.
///
/// Does not stream-sign — reads the full body into memory before signing.
/// This is appropriate for the cloud_sync_s3 adapter's 50MB file ceiling.
class S3AuthClient extends http.BaseClient {
  final S3Config config;
  final S3Credentials credentials;
  final http.Client _inner;

  S3AuthClient({
    required this.config,
    required this.credentials,
    http.Client? inner,
  }) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload = _extractBody(request);

    final additionalHeaders = <String, String>{};
    request.headers.forEach((name, value) {
      final lower = name.toLowerCase();
      // Skip headers the signer computes itself
      if (lower == 'host' ||
          lower == 'x-amz-date' ||
          lower == 'x-amz-content-sha256' ||
          lower == 'x-amz-security-token' ||
          lower == 'authorization') {
        return;
      }
      // Sign x-amz-* (required by S3) and any other explicit headers
      if (lower.startsWith('x-amz-')) {
        additionalHeaders[name] = value;
      }
    });

    final signed = AwsSigV4.signRequest(
      method: request.method,
      uri: request.url,
      payload: payload,
      additionalHeaders: additionalHeaders,
      region: config.region,
      service: 's3',
      accessKeyId: credentials.accessKeyId,
      secretAccessKey: credentials.secretAccessKey,
      sessionToken: credentials.sessionToken,
    );

    request.headers.addAll(signed);
    return _inner.send(request);
  }

  List<int> _extractBody(http.BaseRequest request) {
    if (request is http.Request) return request.bodyBytes;
    // For GET/HEAD/DELETE the body is empty. Streaming uploads are not
    // supported in v1 (50MB ceiling — caller reads body into memory first).
    return const [];
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
