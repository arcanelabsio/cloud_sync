import 'package:test/test.dart';
import 'package:cloud_sync_core/cloud_sync_core.dart';

void main() {
  group('PathValidator.validateAppName', () {
    test('accepts valid lowercase snake_case names', () {
      expect(
        () => PathValidator.validateAppName('longeviti'),
        returnsNormally,
      );
      expect(() => PathValidator.validateAppName('my_app'), returnsNormally);
      expect(() => PathValidator.validateAppName('app123'), returnsNormally);
      expect(() => PathValidator.validateAppName('a'), returnsNormally);
    });

    test('rejects empty string', () {
      expect(() => PathValidator.validateAppName(''), throwsArgumentError);
    });

    test('rejects uppercase', () {
      expect(
        () => PathValidator.validateAppName('MyApp'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateAppName('MYAPP'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateAppName('myApp'),
        throwsArgumentError,
      );
    });

    test('rejects hyphens', () {
      expect(
        () => PathValidator.validateAppName('my-app'),
        throwsArgumentError,
      );
    });

    test('rejects spaces', () {
      expect(
        () => PathValidator.validateAppName('my app'),
        throwsArgumentError,
      );
      expect(() => PathValidator.validateAppName(' '), throwsArgumentError);
    });

    test('rejects path traversal', () {
      expect(() => PathValidator.validateAppName('..'), throwsArgumentError);
      expect(
        () => PathValidator.validateAppName('../hack'),
        throwsArgumentError,
      );
    });

    test('rejects slashes', () {
      expect(
        () => PathValidator.validateAppName('app/sub'),
        throwsArgumentError,
      );
    });

    test('rejects names starting with digit', () {
      expect(
        () => PathValidator.validateAppName('123abc'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateAppName('1app'),
        throwsArgumentError,
      );
    });

    test('rejects names starting with underscore', () {
      expect(
        () => PathValidator.validateAppName('_app'),
        throwsArgumentError,
      );
    });

    test('rejects special characters', () {
      expect(
        () => PathValidator.validateAppName("app'name"),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateAppName('app"name'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateAppName('app@name'),
        throwsArgumentError,
      );
    });
  });

  group('PathValidator.validateSubPath', () {
    test('accepts null and empty', () {
      expect(() => PathValidator.validateSubPath(null), returnsNormally);
      expect(() => PathValidator.validateSubPath(''), returnsNormally);
    });

    test('accepts valid paths', () {
      expect(() => PathValidator.validateSubPath('Plans'), returnsNormally);
      expect(
        () => PathValidator.validateSubPath('Backups'),
        returnsNormally,
      );
      expect(
        () => PathValidator.validateSubPath('deep/nested/path'),
        returnsNormally,
      );
      expect(
        () => PathValidator.validateSubPath('Longevity Plans'),
        returnsNormally,
      );
    });

    test('rejects path traversal', () {
      expect(() => PathValidator.validateSubPath('..'), throwsArgumentError);
      expect(
        () => PathValidator.validateSubPath('../etc'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateSubPath('a/../b'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateSubPath('a/../../root'),
        throwsArgumentError,
      );
    });

    test('rejects absolute paths', () {
      expect(
        () => PathValidator.validateSubPath('/absolute'),
        throwsArgumentError,
      );
      expect(() => PathValidator.validateSubPath('/'), throwsArgumentError);
    });

    test('rejects empty segments (double slashes)', () {
      expect(
        () => PathValidator.validateSubPath('a//b'),
        throwsArgumentError,
      );
    });

    test('rejects dot segments', () {
      expect(() => PathValidator.validateSubPath('.'), throwsArgumentError);
      expect(
        () => PathValidator.validateSubPath('a/./b'),
        throwsArgumentError,
      );
    });
  });

  group('PathValidator.buildSandboxPath', () {
    test('builds path without subPath', () {
      expect(PathValidator.buildSandboxPath('my_app', null), '.app/my_app');
      expect(PathValidator.buildSandboxPath('my_app', ''), '.app/my_app');
    });

    test('builds path with subPath', () {
      expect(
        PathValidator.buildSandboxPath('my_app', 'Plans'),
        '.app/my_app/Plans',
      );
      expect(
        PathValidator.buildSandboxPath('my_app', 'deep/nested'),
        '.app/my_app/deep/nested',
      );
    });

    test('validates appName during build', () {
      expect(
        () => PathValidator.buildSandboxPath('', null),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.buildSandboxPath('BadName', null),
        throwsArgumentError,
      );
    });

    test('validates subPath during build', () {
      expect(
        () => PathValidator.buildSandboxPath('app', '../etc'),
        throwsArgumentError,
      );
    });
  });

  group('PathValidator.validateBasePath', () {
    test('accepts simple names', () {
      expect(() => PathValidator.validateBasePath('MyApp'), returnsNormally);
      expect(() => PathValidator.validateBasePath('app'), returnsNormally);
    });

    test('accepts dotfile prefix', () {
      expect(
        () => PathValidator.validateBasePath('.app/longeviti'),
        returnsNormally,
      );
    });

    test('accepts mixed case and spaces', () {
      expect(
        () => PathValidator.validateBasePath('My Company/My App'),
        returnsNormally,
      );
    });

    test('rejects empty', () {
      expect(() => PathValidator.validateBasePath(''), throwsArgumentError);
    });

    test('rejects traversal', () {
      expect(
        () => PathValidator.validateBasePath('../hack'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateBasePath('a/..'),
        throwsArgumentError,
      );
    });

    test('rejects absolute', () {
      expect(
        () => PathValidator.validateBasePath('/abs'),
        throwsArgumentError,
      );
    });

    test('rejects trailing slash', () {
      expect(
        () => PathValidator.validateBasePath('path/'),
        throwsArgumentError,
      );
    });
  });

  group('PathValidator.validateFolderName', () {
    test('accepts simple names', () {
      expect(
        () => PathValidator.validateFolderName('MyApp'),
        returnsNormally,
      );
      expect(
        () => PathValidator.validateFolderName('Backups 2026'),
        returnsNormally,
      );
    });

    test('rejects empty, slashes, dot segments', () {
      expect(
        () => PathValidator.validateFolderName(''),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateFolderName('a/b'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateFolderName('..'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.validateFolderName('.'),
        throwsArgumentError,
      );
    });
  });

  group('PathValidator.joinBasePath', () {
    test('joins base and subPath', () {
      expect(
        PathValidator.joinBasePath('MyApp', 'Backups'),
        'MyApp/Backups',
      );
    });

    test('returns base unchanged when subPath null/empty', () {
      expect(PathValidator.joinBasePath('MyApp', null), 'MyApp');
      expect(PathValidator.joinBasePath('MyApp', ''), 'MyApp');
    });

    test('validates both components', () {
      expect(
        () => PathValidator.joinBasePath('', 'sub'),
        throwsArgumentError,
      );
      expect(
        () => PathValidator.joinBasePath('MyApp', '../hack'),
        throwsArgumentError,
      );
    });
  });
}
