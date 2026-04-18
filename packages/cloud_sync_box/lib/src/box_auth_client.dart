import 'package:http/http.dart' as http;

/// An [http.BaseClient] that injects a Box OAuth2 Bearer token into every
/// outgoing request.
///
/// Convenience for the simple case — the caller has a valid access token
/// and doesn't need refresh handling. For JWT App Auth or refreshable
/// tokens, build your own `http.BaseClient` and pass it to `BoxAdapter`
/// instead of using this class.
class BoxAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner;

  BoxAuthClient({required this.accessToken, http.Client? inner})
      : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
