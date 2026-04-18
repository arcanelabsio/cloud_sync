/// Example showing [DriveAdapter] set up against Google Drive.
///
/// Run this with a real OAuth2 access token substituted below. The
/// [DriveAuthClient] wraps a Bearer-style auth-header map, which is what
/// `google_sign_in` (and most OAuth2 helpers) return. You can also build
/// your own `http.BaseClient` if you handle token refresh yourself.
///
/// Three scope modes are demonstrated — pick the one that matches your
/// app's compliance posture. See [DriveScope] for the full tradeoff
/// discussion.
library;

import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_drive/cloud_sync_drive.dart';

Future<void> main() async {
  // Replace with a real token from google_sign_in or another OAuth2 flow.
  // DriveAuthClient takes the auth headers Google's SDKs return (a single
  // 'Authorization: Bearer ...' entry is enough).
  final authClient = DriveAuthClient({
    'Authorization': 'Bearer YOUR_ACCESS_TOKEN_HERE',
  });

  // Mode 1: drive.file scope — app sees only files it created.
  //         No CASA required. Recommended for most apps.
  final adapter = DriveAdapter.appFiles(
    httpClient: authClient,
    folderName: 'MyApp',
    subPath: 'Backups',
  );

  final client = SyncClient(adapter: adapter);

  // A real run would point at a local directory that exists:
  //   await client.sync(localPath: '/Users/you/MyApp/data');
  // This demo just prints the wired-up configuration.
  print('Drive adapter configured:');
  print('  scope:      ${adapter.scope}');
  print('  folderPath: ${adapter.folderPath}');
  print('Ready to sync via: client.sync(localPath: ...)');
  print(client);
}
