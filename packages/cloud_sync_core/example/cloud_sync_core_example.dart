/// Minimal example showing the engine in isolation with an in-memory adapter.
///
/// This example does not use `SyncClient` (which reaches into the local
/// filesystem via `dart:io`). Instead it feeds the [SyncEngine] explicit
/// `readLocalFile` / `writeLocalFile` callbacks, which is the pure-Dart
/// integration path used in tests and isolates.
///
/// For a file-backed version that walks a local directory on disk, see
/// `SyncClient` in this same package.
library;

import 'dart:convert';

import 'package:cloud_sync_core/cloud_sync_core.dart';

/// In-memory adapter — no network, no disk, just a map. Useful for examples,
/// isolate-safe smoke tests, and any integration that already has its own
/// storage abstraction.
class InMemoryAdapter implements StorageAdapter {
  final Map<String, List<int>> _files = {};
  final Map<String, DateTime> _modified = {};

  @override
  Future<void> ensureFolder() async {}

  @override
  Future<Map<String, RemoteFileInfo>> listFiles() async => _files.map(
    (path, bytes) => MapEntry(
      path,
      RemoteFileInfo(
        path: path,
        lastModified: _modified[path] ?? DateTime.now(),
        sizeBytes: bytes.length,
      ),
    ),
  );

  @override
  Future<void> uploadFile(String remotePath, List<int> content) async {
    _files[remotePath] = content;
    _modified[remotePath] = DateTime.now();
  }

  @override
  Future<List<int>> downloadFile(String remotePath) async =>
      _files[remotePath] ?? (throw Exception('not found: $remotePath'));

  @override
  Future<void> deleteFile(String remotePath) async {
    _files.remove(remotePath);
    _modified.remove(remotePath);
  }
}

Future<void> main() async {
  final adapter = InMemoryAdapter();
  final engine = SyncEngine(adapter: adapter);

  // Simulated local state: two files the engine should push to the remote.
  final localFiles = <String, List<int>>{
    'data.json': utf8.encode('{"key":"value"}'),
    'tracking/2026-04-18.json': utf8.encode('{"weight":130}'),
  };
  final localManifest = SyncManifest(
    files: {
      for (final entry in localFiles.entries)
        entry.key: SyncFileEntry(
          path: entry.key,
          sha256: 'sha-stub-${entry.key}',
          lastModified: DateTime.now(),
        ),
    },
    lastSynced: DateTime.now(),
  );

  final result = await engine.sync(
    localPath: '/ignored-since-callbacks-are-explicit',
    localManifest: localManifest,
    direction: SyncDirection.push,
    readLocalFile: (path) async =>
        localFiles[path] ?? (throw Exception('not in local: $path')),
  );

  print('Sync complete.');
  print('  uploaded:   ${result.filesUploaded}');
  print('  downloaded: ${result.filesDownloaded}');
  print('  errors:     ${result.errors.length}');
}
