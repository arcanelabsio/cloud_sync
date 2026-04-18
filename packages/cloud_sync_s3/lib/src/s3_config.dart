/// Configuration for an S3 or S3-compatible endpoint.
///
/// The defaults target AWS S3 at the virtual-hosted-style endpoint for the
/// given region. Override [endpoint] for S3-compatible services (R2, MinIO,
/// B2, Wasabi, DO Spaces) and set [usePathStyle] when the service requires
/// path-style addressing (e.g., MinIO by default).
class S3Config {
  /// Full base endpoint URL. If null, defaults to
  /// `https://s3.<region>.amazonaws.com`.
  ///
  /// Examples:
  /// - AWS S3: leave null
  /// - Cloudflare R2: `https://<account-id>.r2.cloudflarestorage.com`
  /// - MinIO: `http://localhost:9000`
  /// - Backblaze B2: `https://s3.us-west-002.backblazeb2.com`
  final String? endpoint;

  /// AWS region code (e.g., "us-east-1", "eu-west-1", "auto" for R2).
  final String region;

  /// Bucket name. Must exist before calling sync.
  final String bucket;

  /// Optional key prefix. All object keys get `${prefix}/` prepended.
  final String? prefix;

  /// Use path-style addressing (`{endpoint}/{bucket}/{key}`) instead of
  /// virtual-hosted style (`{bucket}.{endpoint}/{key}`).
  ///
  /// Required for MinIO (default config). Some S3-compatible services
  /// support both; check their docs.
  final bool usePathStyle;

  const S3Config({
    required this.region,
    required this.bucket,
    this.endpoint,
    this.prefix,
    this.usePathStyle = false,
  });

  /// Resolve the base URI for this config (without bucket or key).
  Uri get baseUri {
    if (endpoint != null) return Uri.parse(endpoint!);
    return Uri.parse('https://s3.$region.amazonaws.com');
  }

  /// Build the full URI for a given object key.
  ///
  /// Respects [usePathStyle] and [prefix]. The key is joined with `/`
  /// after prefix. Does not URI-encode the key — the HTTP client handles
  /// that when building the request.
  Uri objectUri(String key) {
    final fullKey = prefix == null || prefix!.isEmpty
        ? key
        : '${prefix!.replaceAll(RegExp(r'/$'), '')}/$key';

    final base = baseUri;
    if (usePathStyle) {
      return base.replace(
        pathSegments: [
          ...base.pathSegments.where((s) => s.isNotEmpty),
          bucket,
          ...fullKey.split('/'),
        ],
      );
    }
    // Virtual-hosted style: bucket becomes subdomain
    return base.replace(
      host: '$bucket.${base.host}',
      pathSegments: fullKey.split('/'),
    );
  }

  /// Build the URI for bucket-level operations (ListObjectsV2, HeadBucket).
  Uri bucketUri({Map<String, String>? queryParameters}) {
    final base = baseUri;
    Uri uri;
    if (usePathStyle) {
      uri = base.replace(
        pathSegments: [
          ...base.pathSegments.where((s) => s.isNotEmpty),
          bucket,
        ],
      );
    } else {
      uri = base.replace(host: '$bucket.${base.host}');
    }
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }
}
