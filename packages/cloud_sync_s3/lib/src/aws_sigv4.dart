import 'dart:convert';
import 'package:crypto/crypto.dart';

/// AWS Signature Version 4 (SigV4) request signing.
///
/// Implements the algorithm described at:
/// https://docs.aws.amazon.com/general/latest/gr/sigv4-signing.html
///
/// Stateless — [signRequest] takes the raw HTTP request inputs and returns
/// the headers to attach (Authorization, X-Amz-Date, X-Amz-Content-Sha256,
/// and X-Amz-Security-Token for STS credentials). The caller sends the
/// request with these headers merged into its own header set.
class AwsSigV4 {
  AwsSigV4._();

  static const _algorithm = 'AWS4-HMAC-SHA256';

  /// Sign an HTTP request. Returns the headers to add before sending.
  ///
  /// [method]: HTTP verb (GET, PUT, etc.)
  /// [uri]: full request URI (scheme, host, path, query)
  /// [payload]: request body bytes (empty list for GET/HEAD/DELETE)
  /// [additionalHeaders]: extra headers whose values must be signed (e.g.,
  /// `x-amz-meta-*` for S3 metadata). Header names are lowercased for
  /// signing; the caller is responsible for sending them with the request.
  /// [region]: AWS region code (e.g., "us-east-1")
  /// [service]: AWS service code (e.g., "s3")
  /// [accessKeyId], [secretAccessKey]: long-term or STS temporary creds
  /// [sessionToken]: required for STS temporary credentials
  /// [timestamp]: override signing time — tests only; defaults to `DateTime.now().toUtc()`
  static Map<String, String> signRequest({
    required String method,
    required Uri uri,
    required List<int> payload,
    Map<String, String> additionalHeaders = const {},
    required String region,
    required String service,
    required String accessKeyId,
    required String secretAccessKey,
    String? sessionToken,
    DateTime? timestamp,
  }) {
    final now = (timestamp ?? DateTime.now().toUtc()).toUtc();
    final dateStamp = _yyyymmdd(now);
    final amzDate = _amzDate(now);
    final credentialScope = '$dateStamp/$region/$service/aws4_request';

    final payloadHash = sha256.convert(payload).toString();

    final host = uri.host + (uri.hasPort && !_isDefaultPort(uri) ? ':${uri.port}' : '');
    final headersToSign = <String, String>{
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
    };
    if (sessionToken != null) {
      headersToSign['x-amz-security-token'] = sessionToken;
    }
    additionalHeaders.forEach((name, value) {
      headersToSign[name.toLowerCase()] = value.trim();
    });

    final sortedNames = headersToSign.keys.toList()..sort();
    final canonicalHeaders =
        '${sortedNames.map((n) => '$n:${headersToSign[n]}').join('\n')}\n';
    final signedHeaders = sortedNames.join(';');

    final canonicalUri = _canonicalizePath(uri);
    final canonicalQuery = _canonicalizeQuery(uri);

    final canonicalRequest = [
      method.toUpperCase(),
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final canonicalRequestHash =
        sha256.convert(utf8.encode(canonicalRequest)).toString();

    final stringToSign = [
      _algorithm,
      amzDate,
      credentialScope,
      canonicalRequestHash,
    ].join('\n');

    final kSecret = utf8.encode('AWS4$secretAccessKey');
    final kDate = _hmac(kSecret, utf8.encode(dateStamp));
    final kRegion = _hmac(kDate, utf8.encode(region));
    final kService = _hmac(kRegion, utf8.encode(service));
    final kSigning = _hmac(kService, utf8.encode('aws4_request'));

    final signatureBytes = _hmac(kSigning, utf8.encode(stringToSign));
    final signature = _hex(signatureBytes);

    final authorization =
        '$_algorithm Credential=$accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';

    final result = <String, String>{
      'Authorization': authorization,
      'X-Amz-Date': amzDate,
      'X-Amz-Content-Sha256': payloadHash,
    };
    if (sessionToken != null) {
      result['X-Amz-Security-Token'] = sessionToken;
    }
    return result;
  }

  // ---------- Internal: exposed as @visibleForTesting through test-only imports ----------

  /// Compute the canonical request string (first block of SigV4).
  /// Exposed for test vector validation.
  static String canonicalRequest({
    required String method,
    required Uri uri,
    required Map<String, String> signedHeaderMap,
    required String payloadHash,
  }) {
    final sortedNames = signedHeaderMap.keys.map((k) => k.toLowerCase()).toList()
      ..sort();
    final lowered = signedHeaderMap.map(
      (k, v) => MapEntry(k.toLowerCase(), v.trim()),
    );
    final canonicalHeaders =
        '${sortedNames.map((n) => '$n:${lowered[n]}').join('\n')}\n';
    final signedHeaders = sortedNames.join(';');

    return [
      method.toUpperCase(),
      _canonicalizePath(uri),
      _canonicalizeQuery(uri),
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
  }

  // ---------- helpers ----------

  static bool _isDefaultPort(Uri uri) {
    if (uri.scheme == 'https' && uri.port == 443) return true;
    if (uri.scheme == 'http' && uri.port == 80) return true;
    return false;
  }

  static String _yyyymmdd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String _amzDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$mi${s}Z';
  }

  static List<int> _hmac(List<int> key, List<int> data) {
    return Hmac(sha256, key).convert(data).bytes;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Canonicalize a URI path per SigV4 rules.
  /// - Empty path → `/`
  /// - Decode from the URI (Dart's pathSegments gives decoded segments)
  /// - Percent-encode each segment per RFC 3986 unreserved set
  /// - Preserve `/` as segment separator
  /// - Single-encoding (S3 SigV4 does not double-encode)
  static String _canonicalizePath(Uri uri) {
    if (uri.pathSegments.isEmpty) return '/';
    return '/${uri.pathSegments.map(_uriEncode).join('/')}';
  }

  /// Canonicalize a URI query string per SigV4 rules.
  /// - Sort params by name, then by value
  /// - URI-encode each key and value per RFC 3986 unreserved set
  static String _canonicalizeQuery(Uri uri) {
    if (uri.query.isEmpty) return '';
    final pairs = <List<String>>[];
    uri.queryParametersAll.forEach((k, values) {
      for (final v in values) {
        pairs.add([k, v]);
      }
    });
    pairs.sort((a, b) {
      final kc = a[0].compareTo(b[0]);
      return kc != 0 ? kc : a[1].compareTo(b[1]);
    });
    return pairs
        .map((p) => '${_uriEncode(p[0])}=${_uriEncode(p[1])}')
        .join('&');
  }

  /// URI-encode per RFC 3986 unreserved set.
  /// Unreserved: A-Z, a-z, 0-9, `-`, `.`, `_`, `~`.
  /// Everything else → `%XX` uppercase hex.
  static String _uriEncode(String input) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(input)) {
      if ((byte >= 0x41 && byte <= 0x5A) || // A-Z
          (byte >= 0x61 && byte <= 0x7A) || // a-z
          (byte >= 0x30 && byte <= 0x39) || // 0-9
          byte == 0x2D || // -
          byte == 0x2E || // .
          byte == 0x5F || // _
          byte == 0x7E) {
        // ~
        buffer.writeCharCode(byte);
      } else {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }
}
