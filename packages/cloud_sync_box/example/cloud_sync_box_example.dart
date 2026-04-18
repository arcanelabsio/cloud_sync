/// Example showing [BoxAdapter] set up against the Box Content API.
///
/// Substitute a real Box OAuth2 access token below. For JWT App Auth
/// (server-to-server), construct your own `http.Client` that signs requests
/// with a JWT and pass it to [BoxAdapter] directly — the adapter itself
/// doesn't manage token lifecycle.
library;

import 'package:cloud_sync_core/cloud_sync_core.dart';
import 'package:cloud_sync_box/cloud_sync_box.dart';

Future<void> main() async {
  // Simple case: Bearer-token OAuth2. BoxAuthClient attaches
  // 'Authorization: Bearer ...' to every outgoing request.
  final authClient = BoxAuthClient(accessToken: 'YOUR_BOX_ACCESS_TOKEN');

  // rootFolderId '0' is the user's Box root. Use a sub-folder's ID to
  // sandbox the adapter to a specific area.
  final adapter = BoxAdapter(
    config: BoxConfig(rootFolderId: '0'),
    httpClient: authClient,
  );

  final client = SyncClient(adapter: adapter);

  // A real run would point at a local directory:
  //   await client.sync(localPath: '/Users/you/MyApp/data');
  print('Box adapter configured. Ready to sync.');
  print('  rootFolderId: ${adapter.config.rootFolderId}');
  print('  client:       $client');
}
