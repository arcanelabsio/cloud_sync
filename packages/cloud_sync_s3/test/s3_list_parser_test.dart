import 'package:test/test.dart';
import 'package:cloud_sync_s3/src/s3_list_parser.dart';

void main() {
  group('S3ListParser — basic parsing', () {
    test('parses a single-file response', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>my-bucket</Name>
  <KeyCount>1</KeyCount>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>data.json</Key>
    <LastModified>2026-04-18T12:00:00.000Z</LastModified>
    <ETag>"abc123"</ETag>
    <Size>42</Size>
  </Contents>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml);
      expect(result.files, hasLength(1));
      expect(result.files['data.json']!.sizeBytes, 42);
      expect(
        result.files['data.json']!.lastModified,
        DateTime.utc(2026, 4, 18, 12, 0, 0),
      );
      expect(result.files['data.json']!.sha256, isNull);
      expect(result.nextContinuationToken, isNull);
    });

    test('parses empty response (zero files)', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>my-bucket</Name>
  <KeyCount>0</KeyCount>
  <IsTruncated>false</IsTruncated>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml);
      expect(result.files, isEmpty);
      expect(result.nextContinuationToken, isNull);
    });

    test('parses multiple files', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <KeyCount>3</KeyCount>
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
  <Contents>
    <Key>data/nested.json</Key>
    <LastModified>2026-04-18T12:00:00.000Z</LastModified>
    <Size>30</Size>
  </Contents>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml);
      expect(result.files, hasLength(3));
      expect(result.files['a.json']!.sizeBytes, 10);
      expect(result.files['b.json']!.sizeBytes, 20);
      expect(result.files['data/nested.json']!.sizeBytes, 30);
    });
  });

  group('S3ListParser — pagination', () {
    test('extracts NextContinuationToken when truncated', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <KeyCount>1</KeyCount>
  <IsTruncated>true</IsTruncated>
  <NextContinuationToken>token-abc-123</NextContinuationToken>
  <Contents>
    <Key>page1.json</Key>
    <LastModified>2026-04-18T10:00:00.000Z</LastModified>
    <Size>5</Size>
  </Contents>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml);
      expect(result.files, hasLength(1));
      expect(result.nextContinuationToken, 'token-abc-123');
    });

    test('no token when IsTruncated is false', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <KeyCount>0</KeyCount>
  <IsTruncated>false</IsTruncated>
  <NextContinuationToken>ignored-because-not-truncated</NextContinuationToken>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml);
      expect(result.nextContinuationToken, isNull);
    });
  });

  group('S3ListParser — prefix stripping', () {
    test('strips prefix from keys', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <KeyCount>2</KeyCount>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>backups/data.json</Key>
    <LastModified>2026-04-18T10:00:00.000Z</LastModified>
    <Size>10</Size>
  </Contents>
  <Contents>
    <Key>backups/nested/file.json</Key>
    <LastModified>2026-04-18T11:00:00.000Z</LastModified>
    <Size>20</Size>
  </Contents>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml, prefix: 'backups');
      expect(result.files.keys,
          unorderedEquals(['data.json', 'nested/file.json']));
    });

    test('accepts prefix with or without trailing slash', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>backups/data.json</Key>
    <LastModified>2026-04-18T10:00:00.000Z</LastModified>
    <Size>10</Size>
  </Contents>
</ListBucketResult>''';

      final withSlash = S3ListParser.parse(xml, prefix: 'backups/');
      final withoutSlash = S3ListParser.parse(xml, prefix: 'backups');
      expect(withSlash.files.keys, ['data.json']);
      expect(withoutSlash.files.keys, ['data.json']);
    });

    test('skips the prefix "folder" entry itself', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>backups/</Key>
    <LastModified>2026-04-18T10:00:00.000Z</LastModified>
    <Size>0</Size>
  </Contents>
  <Contents>
    <Key>backups/data.json</Key>
    <LastModified>2026-04-18T11:00:00.000Z</LastModified>
    <Size>10</Size>
  </Contents>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml, prefix: 'backups');
      expect(result.files.keys, ['data.json']);
    });
  });

  group('S3ListParser — edge cases', () {
    test('handles keys with spaces and special characters', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>my folder/file with spaces.txt</Key>
    <LastModified>2026-04-18T10:00:00.000Z</LastModified>
    <Size>100</Size>
  </Contents>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml);
      expect(result.files.keys, ['my folder/file with spaces.txt']);
    });

    test('handles very small ISO timestamps (S3 variation)', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>file.txt</Key>
    <LastModified>2009-10-12T17:50:30Z</LastModified>
    <Size>1</Size>
  </Contents>
</ListBucketResult>''';

      final result = S3ListParser.parse(xml);
      expect(
        result.files['file.txt']!.lastModified,
        DateTime.utc(2009, 10, 12, 17, 50, 30),
      );
    });
  });
}
