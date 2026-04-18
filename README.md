# cloud_sync

Bidirectional file sync for Dart and Flutter, across multiple cloud storage backends. Path-based manifest diffing, SHA256 change detection, pluggable conflict resolution — implemented once in a storage-agnostic core and reused across every backend.

- **Storage-agnostic core** — diff, resolve, transfer logic lives in `cloud_sync_core` and has zero knowledge of any specific backend.
- **One small interface per backend** — 5 methods (`ensureFolder`, `listFiles`, `uploadFile`, `downloadFile`, `deleteFile`).
- **Swap adapters without touching your app code** — the same `SyncClient` works against Google Drive today, S3 tomorrow, Box the day after.
- **Opaque bytes** — the engine never reads file contents. Works identically for JSON, binary, or pre-encrypted blobs.

---

## Packages

| Package | Description | pub.dev |
|---|---|---|
| [`cloud_sync_core`](packages/cloud_sync_core) | Core interfaces (`StorageAdapter`), sync engine, manifest differ, conflict resolver, `SyncClient`. No backend logic. | [![pub](https://img.shields.io/pub/v/cloud_sync_core.svg)](https://pub.dev/packages/cloud_sync_core) |
| [`cloud_sync_drive`](packages/cloud_sync_drive) | Google Drive adapter. `drive`, `drive.file`, `drive.appdata` scopes supported. | [![pub](https://img.shields.io/pub/v/cloud_sync_drive.svg)](https://pub.dev/packages/cloud_sync_drive) |
| [`cloud_sync_s3`](packages/cloud_sync_s3) | AWS S3 + S3-compatible adapter (R2, MinIO, Backblaze B2, Wasabi, DO Spaces). | [![pub](https://img.shields.io/pub/v/cloud_sync_s3.svg)](https://pub.dev/packages/cloud_sync_s3) |
| [`cloud_sync_box`](packages/cloud_sync_box) | Box Content API adapter. | [![pub](https://img.shields.io/pub/v/cloud_sync_box.svg)](https://pub.dev/packages/cloud_sync_box) |

All four packages live at `0.1.x` and follow independent semver — you can pin `cloud_sync_drive` while upgrading `cloud_sync_s3`.

---

## Install

```yaml
dependencies:
  cloud_sync_core: ^0.1.1
  cloud_sync_drive: ^0.1.1     # add the adapter(s) you need
  # cloud_sync_s3: ^0.1.1
  # cloud_sync_box: ^0.1.1
```

You only need `cloud_sync_core` + at least one adapter package. The core itself does nothing useful without an adapter.

---

## Quick start — Google Drive

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_drive/cloud_sync_drive.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 1. Authenticate with any scope that matches the adapter mode you want.
final signIn = GoogleSignIn(scopes: [
  'https://www.googleapis.com/auth/drive.file',      // for .appFiles()
]);
final account = await signIn.signIn();
final authClient = DriveAuthClient(await account!.authHeaders);

// 2. Build an adapter.
final adapter = DriveAdapter.appFiles(
  httpClient: authClient,
  folderName: 'MyApp',
  subPath: 'backups',
);

// 3. Sync.
final client = SyncClient(adapter: adapter);
final result = await client.sync(localPath: '/path/to/data');
print('${result.filesUploaded} uploaded, ${result.filesDownloaded} downloaded');
```

Swap the adapter (`DriveAdapter` → `S3Adapter` → `BoxAdapter`) and the rest of the code is identical.

---

## The unified `SyncClient` API

`SyncClient` is the top-level type every adapter plugs into. Once you have an adapter, the operations are the same across backends:

```dart
final client = SyncClient(
  adapter: adapter,
  defaultStrategy: ConflictStrategy.newerWins,
);

// Bidirectional sync — new files go both ways, conflicts resolved by strategy
final result = await client.sync(localPath: '/data');

// Push only — local overwrites remote
await client.push(localPath: '/data');

// Pull only — remote overwrites local
await client.pull(localPath: '/data');

// Dry-run: see what would change
final status = await client.status(localPath: '/data');
print('Pending: ${status.pendingChanges?.totalChanges ?? 0}');
```

### Change detection

A JSON manifest (`_sync_manifest.json`) is kept alongside your local data and records `{path, sha256, lastModified}` for every synced file. On each run the engine diffs local vs. remote vs. manifest and only transfers files that actually changed. Unchanged files incur no network I/O.

### Conflict resolution

When both sides modified the same file, `SyncClient` **picks one version** — it never merges content. It compares SHA256 checksums (to detect changes) and `lastModified` timestamps (to pick a winner), so it works on binary, JSON, or encrypted blobs.

| Strategy | Behavior |
|---|---|
| `newerWins` | Most recent `lastModified` wins. Ties go to local. |
| `localWins` | Always keep the local version; remote is overwritten. |
| `remoteWins` | Always keep the remote version; local is overwritten. |
| `askUser` | Skip the file and return it in `result.unresolvedConflicts` for your UI to handle. |

If you need to preserve both versions, use `askUser` and implement your own merge or backup policy.

---

## Google Drive — OAuth scopes & CASA

`cloud_sync_drive` supports all three Drive OAuth scopes via three factory constructors. Your choice determines what files the app can see, whether you need CASA (annual security audit), and what tradeoffs you're making. This is the area with the highest compliance blast radius, so read carefully before picking one.

### At a glance

| Factory | OAuth scope | App sees | User sees in Drive UI | CASA needed? |
|---|---|---|---|---|
| `DriveAdapter.userDrive(basePath:)` | `drive` (full) | Everything in the user's Drive | Files visible | **Yes** for public distribution |
| `DriveAdapter.appFiles(folderName:)` | `drive.file` | Only files this app created | Files visible | No |
| `DriveAdapter.appData(subPath:)` | `drive.appdata` | Only contents of hidden `appDataFolder` | **Nothing** (folder hidden) | No |

### Which should I pick?

- **`.appFiles()`** — The 80% case and lowest compliance burden. Your app is the *only* writer. No CLI, no companion web app, no Drive Desktop drops into the sync folder.
- **`.userDrive()`** — Multiple OAuth clients write to the same folder (e.g. a CLI tool on a laptop plus a mobile app, or Drive Desktop drops that the app needs to read). Full `drive` is the only scope that lets the app see files created by other identities. Restricted-scope: public distribution requires OAuth verification *plus* annual CASA (details below).
- **`.appData()`** — Internal state the user should never see — app config, caches, encrypted blobs. The `appDataFolder` is invisible in the Drive UI, quota-separate from the user's Drive, and strictly scoped to this OAuth client ID.

### The visibility trap with `.appFiles()`

`drive.file` is scoped by **creating OAuth client ID**, not by path. If anything other than your Flutter app writes into the folder — the user manually, Drive Desktop, a companion CLI — those files are **invisible** to your app's `listFiles()`, even if they live in the same folder. You'll only discover this in production, when a user says "where are my plans?"

If your architecture has multiple writers, use `.userDrive()` instead.

### CASA and the restricted-scope tax

`.userDrive()` uses the `drive` scope, which Google classifies as *restricted*. Public distribution requires:

1. **Google OAuth verification** — one-time review, free, takes 1–4 weeks. Brand/domain verification + privacy policy review + scope-justification video.
2. **Annual CASA** (Cloud Application Security Assessment) — third-party security audit by a Google-approved lab. Tier 2 is the common minimum: ~$5K–$20K/year. Covers pen test, SAST/DAST scan, token-storage review, deletion-flow review.

**Can you skip CASA?** Yes, by keeping your OAuth client in **Testing** publishing status:

- Up to 100 test users (listed by Gmail address).
- Users see a "Google hasn't verified this app" warning on first sign-in.
- Refresh tokens for restricted scopes expire every 7 days — users re-sign-in weekly.

Testing mode is the legitimate path for personal apps, family tools, and small-circle distribution. **Workspace escape hatch:** if all users belong to a Google Workspace domain, set the consent screen user type to `Internal` and skip verification + CASA + the 100-user cap entirely.

### Folder layouts

```
.userDrive(basePath: '.app/longeviti', subPath: 'plans')
└── User's Google Drive
    └── .app/
        └── longeviti/
            └── plans/           ← synced files here

.appFiles(folderName: 'MyApp', subPath: 'backups')
└── User's Google Drive
    └── MyApp/
        └── backups/             ← synced files here
                                    (visible to user; app sees only its own files)

.appData(subPath: 'cache')
└── Hidden appDataFolder (invisible to user)
    └── cache/                   ← synced files here
```

### Scope-mismatch errors

If the auth client's actual scope doesn't match the adapter's declared scope, the first Drive API call returns 403. The library catches this and re-raises as `DriveScopeError` with a remediation message pointing at the expected scope.

---

## Amazon S3 + S3-compatible services

`cloud_sync_s3` supports AWS S3 and every S3-compatible service we've tested: Cloudflare R2, MinIO (local dev), Backblaze B2, Wasabi, DigitalOcean Spaces. See [`cloud_sync_s3/README.md`](packages/cloud_sync_s3/README.md) for endpoint-by-endpoint config snippets.

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_s3/cloud_sync_s3.dart';

final adapter = S3Adapter(
  config: S3Config(region: 'us-east-1', bucket: 'my-sync-bucket'),
  credentials: S3Credentials(accessKeyId: 'AKIA...', secretAccessKey: '...'),
);
final client = SyncClient(adapter: adapter);
await client.sync(localPath: '/data');
```

The adapter ships a SigV4 implementation validated against AWS's official test vector and preserves SHA256 via `x-amz-meta-sha256`.

---

## Box

`cloud_sync_box` speaks the Box Content API and caches path-to-ID resolution on first use (Box's API is ID-based; the sync contract is path-based).

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_box/cloud_sync_box.dart';

final authClient = BoxAuthClient(accessToken: 'your-oauth2-access-token');
final adapter = BoxAdapter(
  config: BoxConfig(rootFolderId: '0'),   // "0" = user's Box root
  httpClient: authClient,
);
final client = SyncClient(adapter: adapter);
await client.sync(localPath: '/data');
```

Box provides SHA1 natively; `cloud_sync_box` preserves SHA256 by stashing it under custom metadata (`/files/{id}/metadata/global/properties`). See [`cloud_sync_box/README.md`](packages/cloud_sync_box/README.md) for details.

---

## Architecture

```
SyncClient                <- high-level API (sync/push/pull/status)
   └─ SyncEngine          <- orchestrates diff → resolve → transfer
        ├─ ManifestDiffer       <- compares file states
        ├─ ConflictResolver     <- applies conflict strategy
        └─ StorageAdapter       <- backend interface (5 methods)
              ├─ DriveAdapter   (cloud_sync_drive)
              ├─ S3Adapter      (cloud_sync_s3)
              └─ BoxAdapter     (cloud_sync_box)
```

Everything above `StorageAdapter` is backend-free. Everything below is backend-specific. Implementing a new adapter means filling in 5 methods against `StorageAdapter`.

---

## Scope & boundaries

### What cloud_sync does

- Syncs **files** (any format — JSON, YAML, images, binary, encrypted blobs) between a local directory and a cloud folder.
- Detects changes via SHA256 — only transfers files that actually differ.
- Resolves conflicts by strategy when both sides modified the same file.
- Creates nested folder hierarchies on the remote automatically.
- Tracks sync state via a local manifest file (`_sync_manifest.json`).
- Validates paths structurally — rejects traversal, absolute paths, empty segments; escapes backend query strings.

### What cloud_sync does **not** do

- **No encryption.** Files are transferred as-is. Encrypt before syncing and decrypt after pulling if you need it.
- **No content merging.** Conflict resolution picks one version; it never merges file contents.
- **No authentication.** You supply an authenticated `http.Client` / credentials.
- **No background sync.** Sync is triggered explicitly by your code.
- **No partial / resumable transfers.** Files are up/downloaded in full. ~50MB per file is the practical ceiling in v1.
- **No file locking or concurrency control.** Designed for single-device / single-writer use.

### Who handles what

| Concern | Who |
|---|---|
| OAuth flow (sign-in, token refresh) | **You** — use `google_sign_in` or equivalent |
| Providing an authenticated HTTP client / credentials | **You** — wrap with `DriveAuthClient` / `S3AuthClient` / `BoxAuthClient` or your own |
| Encryption of sensitive data | **You** — encrypt before sync, decrypt after pull |
| File format and schema validation | **You** — library treats files as opaque bytes |
| Retry logic on network failure | **You** — library returns errors in `SyncResult.errors` |
| Background/periodic sync scheduling | **You** — call `sync()` when appropriate |
| Change detection (SHA256) | Library |
| Manifest tracking | Library |
| Conflict resolution | Library (configurable strategy) |
| Backend CRUD (list/upload/download/delete) | Library (per-adapter) |
| Path validation & query-injection prevention | Library (`PathValidator` in `cloud_sync_core`) |
| Per-file error reporting | Library (`SyncResult.errors`) |

---

## Migration from `drive_sync_flutter`

[`drive_sync_flutter`](https://pub.dev/packages/drive_sync_flutter) is frozen at 1.2.0. `cloud_sync_drive` is its successor. The public surface was renamed to drop the Drive-specific prefix and make room for other backends.

| `drive_sync_flutter` (old) | `cloud_sync_*` (new) | Lives in |
|---|---|---|
| `DriveSyncClient` | `SyncClient` | `cloud_sync_core` |
| `DriveAdapter` (interface) | `StorageAdapter` | `cloud_sync_core` |
| `GoogleDriveAdapter` | `DriveAdapter` | `cloud_sync_drive` |
| `GoogleAuthClient` | `DriveAuthClient` | `cloud_sync_drive` |
| `SandboxValidator` | `PathValidator` | `cloud_sync_core` |
| `DriveScope`, `DriveScopeError` | (unchanged) | `cloud_sync_drive` |

**Dropped**: the deprecated `GoogleDriveAdapter.sandboxed()`, positional `GoogleDriveAdapter()`, and `.withPath()` constructors. Use `DriveAdapter.userDrive()`, `.appFiles()`, or `.appData()` explicitly — clean-slate API.

**Steps**:

1. In `pubspec.yaml`, replace `drive_sync_flutter: ^1.2.0` with `cloud_sync_core: ^0.1.1` + `cloud_sync_drive: ^0.1.1`.
2. Rename imports: `package:drive_sync_flutter/...` → `package:cloud_sync_core/cloud_sync_core.dart` + `package:cloud_sync_drive/cloud_sync_drive.dart`.
3. Rename types per the table above.
4. Replace deprecated constructors with the equivalent `.userDrive()` / `.appFiles()` / `.appData()` call.

Behavior is unchanged — same manifest format, same conflict strategies, same scope semantics. An existing `_sync_manifest.json` from `drive_sync_flutter` is readable by `cloud_sync_core` without modification.

---

## Development

This is a [melos](https://melos.invertase.dev/)-managed monorepo.

```bash
dart pub global activate melos
melos bootstrap          # link workspace packages
melos run analyze        # dart analyze across all packages
melos run test           # dart test across all packages
melos run format         # check formatting
```

Or via the top-level `Makefile`:

```bash
make bootstrap
make analyze
make test
make pre-release         # analyze + test + publish dry-run — run before tagging
```

`make help` lists every target.

### Tests

157 tests across 4 packages:

- `cloud_sync_core`: 62 — manifest diffing, conflict resolution, sync engine flows, path validation.
- `cloud_sync_drive`: 28 — all three scope modes, scope-mismatch error mapping, query injection prevention, `DriveSyncClient` lifecycle.
- `cloud_sync_s3`: 48 — SigV4 signing (against AWS's official test vector), adapter CRUD, SHA256 preservation, all S3-compatible endpoints.
- `cloud_sync_box`: 19 — path-to-ID cache, metadata-backed SHA256, adapter CRUD.

---

## Release workflow

Each package releases independently. Tagging is gated on a clean tree, synced main, and a pubspec version that isn't already on pub.dev.

```bash
# 1. Bump version in packages/<pkg>/pubspec.yaml + update CHANGELOG.md
# 2. git commit + git push main
# 3. Preflight (analyze + test + publish dry-run):
make pre-release
# 4. Tag + push; publish.yaml on GitHub Actions publishes to pub.dev:
make release PKG=drive    # or: core | s3 | box
```

The tag pattern is `<package>-v<semver>` (e.g. `cloud_sync_drive-v0.1.1`). [`.github/workflows/publish.yaml`](.github/workflows/publish.yaml) parses the tag, re-runs analyze + test, verifies the pubspec version matches, and publishes via pub.dev OIDC trusted publishing — no long-lived secrets.

---

## License

MIT. See [`LICENSE`](LICENSE).
