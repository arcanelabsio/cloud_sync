import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_sync_drive/cloud_sync_drive.dart';

class _NoOpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError('Should not be called in validation tests');
  }
}

void main() {
  late http.Client mockClient;

  setUp(() {
    mockClient = _NoOpClient();
  });

  group('DriveScope enum', () {
    test('exposes three modes', () {
      expect(DriveScope.values, hasLength(3));
      expect(DriveScope.values, contains(DriveScope.fullDrive));
      expect(DriveScope.values, contains(DriveScope.driveFile));
      expect(DriveScope.values, contains(DriveScope.appData));
    });
  });

  group('DriveAdapter.userDrive', () {
    test('declares fullDrive scope', () {
      final adapter = DriveAdapter.userDrive(
        httpClient: mockClient,
        basePath: 'MyApp',
      );
      expect(adapter.scope, DriveScope.fullDrive);
    });

    test('accepts single-segment basePath', () {
      final adapter = DriveAdapter.userDrive(
        httpClient: mockClient,
        basePath: 'MyApp',
      );
      expect(adapter.folderPath, 'MyApp');
    });

    test('accepts multi-segment basePath', () {
      final adapter = DriveAdapter.userDrive(
        httpClient: mockClient,
        basePath: 'Longeviti/data',
      );
      expect(adapter.folderPath, 'Longeviti/data');
    });

    test('accepts .app/ style basePath', () {
      final adapter = DriveAdapter.userDrive(
        httpClient: mockClient,
        basePath: '.app/longeviti',
      );
      expect(adapter.folderPath, '.app/longeviti');
    });

    test('joins basePath and subPath', () {
      final adapter = DriveAdapter.userDrive(
        httpClient: mockClient,
        basePath: '.app/longeviti',
        subPath: 'plans',
      );
      expect(adapter.folderPath, '.app/longeviti/plans');
    });

    test('accepts uppercase segments in basePath', () {
      final adapter = DriveAdapter.userDrive(
        httpClient: mockClient,
        basePath: 'MyCompany/MyApp',
      );
      expect(adapter.folderPath, 'MyCompany/MyApp');
    });

    test('accepts segments with spaces', () {
      final adapter = DriveAdapter.userDrive(
        httpClient: mockClient,
        basePath: 'My App',
        subPath: 'Weekly Plans',
      );
      expect(adapter.folderPath, 'My App/Weekly Plans');
    });

    test('rejects empty basePath', () {
      expect(
        () => DriveAdapter.userDrive(httpClient: mockClient, basePath: ''),
        throwsArgumentError,
      );
    });

    test('rejects basePath with path traversal', () {
      expect(
        () => DriveAdapter.userDrive(
          httpClient: mockClient,
          basePath: '../hack',
        ),
        throwsArgumentError,
      );
      expect(
        () => DriveAdapter.userDrive(
          httpClient: mockClient,
          basePath: 'a/../b',
        ),
        throwsArgumentError,
      );
    });

    test('rejects absolute basePath', () {
      expect(
        () => DriveAdapter.userDrive(
          httpClient: mockClient,
          basePath: '/absolute',
        ),
        throwsArgumentError,
      );
    });

    test('rejects basePath with double slashes', () {
      expect(
        () => DriveAdapter.userDrive(
          httpClient: mockClient,
          basePath: 'a//b',
        ),
        throwsArgumentError,
      );
    });

    test('rejects basePath with trailing slash', () {
      expect(
        () => DriveAdapter.userDrive(
          httpClient: mockClient,
          basePath: 'MyApp/',
        ),
        throwsArgumentError,
      );
    });

    test('rejects subPath with traversal', () {
      expect(
        () => DriveAdapter.userDrive(
          httpClient: mockClient,
          basePath: 'MyApp',
          subPath: '../escape',
        ),
        throwsArgumentError,
      );
    });
  });

  group('DriveAdapter.appFiles', () {
    test('declares driveFile scope', () {
      final adapter = DriveAdapter.appFiles(
        httpClient: mockClient,
        folderName: 'MyApp',
      );
      expect(adapter.scope, DriveScope.driveFile);
    });

    test('accepts simple folder name', () {
      final adapter = DriveAdapter.appFiles(
        httpClient: mockClient,
        folderName: 'MyApp',
      );
      expect(adapter.folderPath, 'MyApp');
    });

    test('accepts folderName with subPath', () {
      final adapter = DriveAdapter.appFiles(
        httpClient: mockClient,
        folderName: 'MyApp',
        subPath: 'Backups',
      );
      expect(adapter.folderPath, 'MyApp/Backups');
    });

    test('accepts nested subPath', () {
      final adapter = DriveAdapter.appFiles(
        httpClient: mockClient,
        folderName: 'MyApp',
        subPath: 'data/2026',
      );
      expect(adapter.folderPath, 'MyApp/data/2026');
    });

    test('rejects empty folderName', () {
      expect(
        () => DriveAdapter.appFiles(httpClient: mockClient, folderName: ''),
        throwsArgumentError,
      );
    });

    test('rejects folderName with slashes', () {
      expect(
        () => DriveAdapter.appFiles(
          httpClient: mockClient,
          folderName: 'MyApp/Sub',
        ),
        throwsArgumentError,
      );
    });

    test('rejects folderName of "." or ".."', () {
      expect(
        () => DriveAdapter.appFiles(
          httpClient: mockClient,
          folderName: '.',
        ),
        throwsArgumentError,
      );
      expect(
        () => DriveAdapter.appFiles(
          httpClient: mockClient,
          folderName: '..',
        ),
        throwsArgumentError,
      );
    });

    test('rejects subPath with traversal', () {
      expect(
        () => DriveAdapter.appFiles(
          httpClient: mockClient,
          folderName: 'MyApp',
          subPath: '../hack',
        ),
        throwsArgumentError,
      );
    });
  });

  group('DriveAdapter.appData', () {
    test('declares appData scope', () {
      final adapter = DriveAdapter.appData(httpClient: mockClient);
      expect(adapter.scope, DriveScope.appData);
    });

    test('has empty folderPath when no subPath (appDataFolder root)', () {
      final adapter = DriveAdapter.appData(httpClient: mockClient);
      expect(adapter.folderPath, '');
    });

    test('accepts subPath for nesting within appDataFolder', () {
      final adapter = DriveAdapter.appData(
        httpClient: mockClient,
        subPath: 'cache',
      );
      expect(adapter.folderPath, 'cache');
    });

    test('accepts nested subPath', () {
      final adapter = DriveAdapter.appData(
        httpClient: mockClient,
        subPath: 'state/v2',
      );
      expect(adapter.folderPath, 'state/v2');
    });

    test('rejects subPath with traversal', () {
      expect(
        () => DriveAdapter.appData(
          httpClient: mockClient,
          subPath: '../escape',
        ),
        throwsArgumentError,
      );
    });

    test('rejects absolute subPath', () {
      expect(
        () => DriveAdapter.appData(httpClient: mockClient, subPath: '/abs'),
        throwsArgumentError,
      );
    });
  });
}
