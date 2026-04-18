# cloud_sync_drive

Google Drive adapter for the [`cloud_sync`](https://github.com/arcanelabsio/cloud_sync) family. Implements `StorageAdapter` from [`cloud_sync_core`](https://pub.dev/packages/cloud_sync_core) and plugs directly into `SyncClient`.

Supersedes [`drive_sync_flutter`](https://pub.dev/packages/drive_sync_flutter) (frozen at 1.2.0).

## Features

- **Three OAuth scope modes** — `drive` (full), `drive.file` (app-created files only), `drive.appdata` (hidden app folder). Pick based on architecture and compliance needs — see [OAuth Scopes & CASA](#oauth-scopes--casa).
- **Nested folder support** — `basePath` / `subPath` are created on demand; no flat-folder restriction.
- **SHA256 change detection** — handled by `cloud_sync_core`; only changed files are uploaded or downloaded.
- **Path-traversal and query-injection protection** — always on, across every scope mode.
- **Scope-mismatch diagnostics** — `403` from Drive is re-raised as `DriveScopeError` with a remediation message pointing at the expected scope.

## Install

```yaml
dependencies:
  cloud_sync_core: ^0.1.1
  cloud_sync_drive: ^0.1.1
  google_sign_in: ^6.0.0   # or any OAuth2 client that yields an authenticated http.Client
```

## Quick start

```dart
import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_drive/cloud_sync_drive.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 1. Authenticate with the scope that matches the adapter mode you want.
final signIn = GoogleSignIn(scopes: [
  'https://www.googleapis.com/auth/drive.file',   // for .appFiles()
]);
final account = await signIn.signIn();
final authClient = DriveAuthClient(await account!.authHeaders);

// 2. Build an adapter.
final adapter = DriveAdapter.appFiles(
  httpClient: authClient,
  folderName: 'MyApp',
  subPath: 'Backups',
);

// 3. Sync.
final client = SyncClient(adapter: adapter);
final result = await client.sync(localPath: '/path/to/data');
print('${result.filesUploaded} uploaded, ${result.filesDownloaded} downloaded');
```

## Scope modes

| Factory | OAuth scope | App sees | User sees in Drive UI | CASA needed? |
|---|---|---|---|---|
| `DriveAdapter.userDrive(basePath:)` | `drive` (full) | Everything in the user's Drive | Files visible | **Yes** for public distribution |
| `DriveAdapter.appFiles(folderName:)` | `drive.file` | Only files this app created | Files visible | No |
| `DriveAdapter.appData(subPath:)` | `drive.appdata` | Only contents of hidden `appDataFolder` | **Nothing** (folder hidden) | No |

### Which one should I pick?

**Use `.appFiles()` if:** Your app is the *only* writer. No CLI tool, no companion web app, no Drive Desktop drops, no manual user uploads to the sync folder. Lowest compliance burden. The 80% case.

**Use `.userDrive()` if:** Files in the sync folder are written by more than one OAuth client — e.g., a CLI tool on a laptop plus a mobile app, or Drive Desktop drops the app needs to read. Full `drive` is the only scope that lets the app see files created by other identities. This is a *restricted* scope; public distribution triggers CASA ([details below](#casa-and-the-restricted-scope-tax)).

**Use `.appData()` if:** You're syncing internal state the user should never see — app config, caches, encrypted blobs. The `appDataFolder` is invisible in the Drive UI, quota-separate from the user's Drive, and strictly scoped to this OAuth client ID.

### The visibility trap with `.appFiles()`

`drive.file` is scoped by **creating OAuth client ID**, not by path. If *any* actor other than your Flutter app writes into the folder — the user manually, Drive Desktop syncing up a local file, a companion CLI tool — those files are **invisible** to your app's `listFiles()` call, even if they live in the same folder.

If your architecture has multiple writers (common for "sync my CLI output to my phone" patterns), `.appFiles()` will silently hide the other writers' files. You'll only discover this in production, when a user says "where are my plans?" Use `.userDrive()` instead.

## OAuth Scopes & CASA

### CASA and the restricted-scope tax

`.userDrive()` uses the `drive` scope, which Google classifies as *restricted*. Public distribution requires:

1. **Google OAuth verification** — one-time review, free, takes 1–4 weeks. Brand/domain verification + privacy-policy review + scope-justification video.
2. **Annual CASA** (Cloud Application Security Assessment) — third-party security audit by a Google-approved lab (Bishop Fox, Leviathan, NCC Group, Security Innovation, etc.). Tier 2 is the common minimum: ~$5K–$20K/year. Covers pen test, SAST/DAST scan, token-storage review, deletion-flow review.

**Can you skip CASA?** Yes, if you keep your OAuth client in **Testing** publishing status. Constraints:

- Up to 100 test users (listed by Gmail address)
- Users see a "Google hasn't verified this app" warning on first sign-in (one-time per user)
- Refresh tokens for restricted scopes expire every 7 days — users re-sign-in weekly

Testing mode is the legitimate path for personal apps, family tools, and small-circle distribution. The 100-user cap is the hard ceiling.

**Workspace escape hatch:** If you have a Google Workspace domain and all users have accounts on it, you can set the consent-screen user type to `Internal`. Internal apps skip verification entirely — no CASA, no 100-user cap, no 7-day re-auth. Only works if your user base is inside a Workspace org.

## Drive folder layouts

```
.userDrive(basePath: '.app/longeviti', subPath: 'plans')
└── User's Google Drive
    └── .app/
        └── longeviti/
            └── plans/           ← synced files here

.appFiles(folderName: 'MyApp', subPath: 'Backups')
└── User's Google Drive
    └── MyApp/
        └── Backups/             ← synced files here
                                    (visible to user; app sees only its own files)

.appData(subPath: 'cache')
└── Hidden appDataFolder (invisible to user)
    └── cache/                   ← synced files here
```

## Security

### Path validation (always on)

Every mode validates all path arguments before construction. These rules apply uniformly across `.userDrive()`, `.appFiles()`, and `.appData()`:

- **No path traversal** — `..` segments rejected
- **No absolute paths** — leading `/` rejected
- **No empty segments** — `//` rejected
- **No trailing slash** — `path/` rejected
- **No dot segments** — `.` rejected
- **Query injection prevention** — all file names and folder names escaped before interpolation into Drive API queries

Invalid arguments throw `ArgumentError` before any adapter instance is created — no Drive API calls are made until you try to sync.

### Scope-mismatch error mapping

If the auth client's actual scope doesn't match the adapter's declared scope, the first Drive API call returns 403. The library catches this and re-raises as `DriveScopeError` with a clear remediation message:

```
DriveScopeError(declared=DriveScope.fullDrive): Drive API returned 403 (...).
The auth client likely does not have the required OAuth scope for this
adapter mode (declared: DriveScope.fullDrive). Verify the http.Client was
obtained with the matching scope.
```

## API

### DriveAdapter

Three factory constructors, one per OAuth scope.

```dart
// drive.file — recommended default. No CASA. App sees only its own files.
final adapter = DriveAdapter.appFiles(
  httpClient: authClient,
  folderName: 'MyApp',
  subPath: 'data',
);

// Full drive — when multiple OAuth clients write to the same folder.
final adapter = DriveAdapter.userDrive(
  httpClient: authClient,
  basePath: '.app/longeviti',   // any path — no fixed prefix
  subPath: 'plans',
);

// drive.appdata — hidden per-client folder, invisible to user.
final adapter = DriveAdapter.appData(
  httpClient: authClient,
  subPath: 'cache',
);
```

Inspect the declared scope on an existing adapter:

```dart
final adapter = DriveAdapter.appFiles(httpClient: c, folderName: 'MyApp');
print(adapter.scope);        // DriveScope.driveFile
print(adapter.folderPath);   // 'MyApp'
```

### DriveAuthClient

Convenience wrapper that injects Google auth headers into HTTP requests. Bridges `google_sign_in` with the Drive API.

```dart
final account = await GoogleSignIn(scopes: ['drive']).signIn();
final authClient = DriveAuthClient(await account!.authHeaders);
// Pass authClient to DriveAdapter.appFiles() / .userDrive() / .appData()
```

For JWT service-account auth or other OAuth flows, build your own `http.Client` and pass it directly — `DriveAuthClient` is a convenience, not a requirement.

## Migration from `drive_sync_flutter`

| Old (`drive_sync_flutter`) | New (`cloud_sync_*`) | Package |
|---|---|---|
| `DriveSyncClient` | `SyncClient` | `cloud_sync_core` |
| `DriveAdapter` (interface) | `StorageAdapter` | `cloud_sync_core` |
| `GoogleDriveAdapter` | `DriveAdapter` | `cloud_sync_drive` |
| `GoogleAuthClient` | `DriveAuthClient` | `cloud_sync_drive` |
| `SandboxValidator` | `PathValidator` | `cloud_sync_core` |
| `DriveScope`, `DriveScopeError` | (unchanged) | `cloud_sync_drive` |

**Dropped**: the deprecated `.sandboxed()`, positional `GoogleDriveAdapter()`, and `.withPath()` constructors. Use `.userDrive()`, `.appFiles()`, or `.appData()` explicitly.

Behavior is unchanged — same manifest format, same conflict strategies, same scope semantics. An existing `_sync_manifest.json` from `drive_sync_flutter` is readable by `cloud_sync_core` without modification.

## License

MIT
