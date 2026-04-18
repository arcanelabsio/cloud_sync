/// AWS credentials for S3 request signing.
///
/// Long-term credentials (IAM user) require only [accessKeyId] and
/// [secretAccessKey]. STS temporary credentials additionally require
/// [sessionToken].
class S3Credentials {
  final String accessKeyId;
  final String secretAccessKey;

  /// STS session token. Required for temporary credentials obtained via
  /// STS AssumeRole, GetSessionToken, or instance metadata. Omit for
  /// long-term IAM user credentials.
  final String? sessionToken;

  const S3Credentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
  });
}
