import 'package:test/test.dart';
import 'package:cloud_sync_s3/src/aws_sigv4.dart';

/// AWS-published test vectors verify that our canonical-request and signature
/// computation match the reference algorithm byte-for-byte.
///
/// Vectors sourced from AWS's official SigV4 documentation:
/// https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
void main() {
  group('AwsSigV4 — S3 GET object test vector', () {
    // From AWS docs "Example: GET Object"
    // https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
    const accessKey = 'AKIAIOSFODNN7EXAMPLE';
    const secretKey = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
    const region = 'us-east-1';
    const service = 's3';
    final timestamp = DateTime.utc(2013, 5, 24, 0, 0, 0);

    test('computes expected Authorization header for GET Object with Range', () {
      final uri = Uri.parse(
        'https://examplebucket.s3.amazonaws.com/test.txt',
      );

      final headers = AwsSigV4.signRequest(
        method: 'GET',
        uri: uri,
        payload: const [],
        additionalHeaders: {'Range': 'bytes=0-9'},
        region: region,
        service: service,
        accessKeyId: accessKey,
        secretAccessKey: secretKey,
        timestamp: timestamp,
      );

      expect(
        headers['X-Amz-Content-Sha256'],
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(headers['X-Amz-Date'], '20130524T000000Z');
      expect(
        headers['Authorization'],
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, '
        'SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, '
        'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
      );
    });

    test('computes expected Authorization header for GET without Range', () {
      // Same vector but without the Range header — signed headers shrink.
      final uri = Uri.parse(
        'https://examplebucket.s3.amazonaws.com/test.txt',
      );

      final headers = AwsSigV4.signRequest(
        method: 'GET',
        uri: uri,
        payload: const [],
        region: region,
        service: service,
        accessKeyId: accessKey,
        secretAccessKey: secretKey,
        timestamp: timestamp,
      );

      // Signed headers should be: host;x-amz-content-sha256;x-amz-date
      expect(
        headers['Authorization'],
        contains(
          'SignedHeaders=host;x-amz-content-sha256;x-amz-date',
        ),
      );
      expect(headers['Authorization'], contains('AKIAIOSFODNN7EXAMPLE'));
      expect(headers['Authorization'], contains('20130524/us-east-1/s3'));
    });
  });

  group('AwsSigV4 — STS session token handling', () {
    test('includes X-Amz-Security-Token when sessionToken provided', () {
      final uri = Uri.parse('https://example.com/');
      final headers = AwsSigV4.signRequest(
        method: 'GET',
        uri: uri,
        payload: const [],
        region: 'us-east-1',
        service: 's3',
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'secret',
        sessionToken: 'FAKE-SESSION-TOKEN',
        timestamp: DateTime.utc(2026, 4, 18),
      );

      expect(headers['X-Amz-Security-Token'], 'FAKE-SESSION-TOKEN');
      // Signed headers must include x-amz-security-token
      expect(
        headers['Authorization'],
        contains('x-amz-security-token'),
      );
    });

    test('omits X-Amz-Security-Token when no sessionToken', () {
      final uri = Uri.parse('https://example.com/');
      final headers = AwsSigV4.signRequest(
        method: 'GET',
        uri: uri,
        payload: const [],
        region: 'us-east-1',
        service: 's3',
        accessKeyId: 'AKIDEXAMPLE',
        secretAccessKey: 'secret',
        timestamp: DateTime.utc(2026, 4, 18),
      );

      expect(headers.containsKey('X-Amz-Security-Token'), false);
    });
  });

  group('AwsSigV4 — path canonicalization', () {
    test('empty path becomes /', () {
      final uri = Uri.parse('https://example.com');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[1], '/');
    });

    test('preserves slashes between segments', () {
      final uri = Uri.parse('https://example.com/bucket/key/file.txt');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[1], '/bucket/key/file.txt');
    });

    test('encodes spaces as %20', () {
      final uri = Uri.parse('https://example.com/a%20b');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[1], '/a%20b');
    });

    test('encodes unicode (re-encodes from decoded form)', () {
      // Uri.parse decodes percent-escapes; our canonicalizer re-encodes.
      final uri = Uri.parse('https://example.com/foo%E2%98%83bar');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[1], '/foo%E2%98%83bar');
    });

    test('preserves unreserved characters', () {
      final uri = Uri.parse('https://example.com/-._~abc123XYZ');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[1], '/-._~abc123XYZ');
    });
  });

  group('AwsSigV4 — query canonicalization', () {
    test('sorts query params by name', () {
      final uri = Uri.parse('https://example.com/?z=1&a=2&m=3');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[2], 'a=2&m=3&z=1');
    });

    test('empty query produces empty canonical line', () {
      final uri = Uri.parse('https://example.com/path');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[2], '');
    });

    test('encodes query values with special characters', () {
      final uri = Uri.parse('https://example.com/?key=a+b&other=c%20d');
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      // `a+b` in query = space "a b"; re-encoded as %20
      expect(cr.split('\n')[2], 'key=a%20b&other=c%20d');
    });

    test('handles ListObjectsV2-style query', () {
      final uri = Uri.parse(
        'https://example.com/?list-type=2&prefix=data/&max-keys=100',
      );
      final cr = AwsSigV4.canonicalRequest(
        method: 'GET',
        uri: uri,
        signedHeaderMap: {'host': 'example.com'},
        payloadHash: 'hash',
      );
      expect(cr.split('\n')[2], 'list-type=2&max-keys=100&prefix=data%2F');
    });
  });
}
