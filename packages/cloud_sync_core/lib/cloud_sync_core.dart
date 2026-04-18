/// Storage-agnostic core for the cloud_sync family.
///
/// Defines the [StorageAdapter] interface and the sync machinery that works
/// against any backend implementing it. Concrete backends (Drive, S3, Box)
/// live in sibling packages.
library;

export 'src/models.dart';
export 'src/storage_adapter.dart';
export 'src/path_validator.dart';
export 'src/manifest_differ.dart';
export 'src/conflict_resolver.dart';
export 'src/sync_engine.dart';
export 'src/sync_client.dart';
