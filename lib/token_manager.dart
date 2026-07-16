import 'dart:convert';
import 'dart:io';

import 'api_config.dart';

class TokenManager {
  static String? _accessToken;
  static int? _expMillis;
  static Future<String?>? _refreshFuture;

  static Future<String?> getValidToken() async {
    final token = _accessToken;
    final expMillis = _expMillis;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (token != null && expMillis != null && expMillis - 30000 > now) {
      return token;
    }

    return refreshToken();
  }

  static Future<String?> refreshToken() async {
    if (_refreshFuture != null) return _refreshFuture!;
    _refreshFuture = _refreshTokenInternal();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<String?> _refreshTokenInternal() async {
    if (ApiConfig.tokenEndpoint.trim().isEmpty) return null;
    if (ApiConfig.username.trim().isEmpty || ApiConfig.password.trim().isEmpty) {
      return null;
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(ApiConfig.tokenEndpoint));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

      request.add(
        utf8.encode(
          jsonEncode(
            {
              'username': ApiConfig.username,
              'password': ApiConfig.password,
            },
          ),
        ),
      );

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final json = jsonDecode(responseBody);
      if (json is! Map) return null;

      final accessToken = json['access_token']?.toString();
      if (accessToken == null || accessToken.trim().isEmpty) return null;

      final exp = _parseJwtExpMillis(accessToken);
      _accessToken = accessToken;
      _expMillis = exp;
      return accessToken;
    } finally {
      client.close(force: true);
    }
  }

  static int? _parseJwtExpMillis(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    if (json is! Map) return null;

    final exp = json['exp'];
    if (exp is int) return exp * 1000;
    if (exp is String) {
      final v = int.tryParse(exp);
      return v == null ? null : v * 1000;
    }
    return null;
  }
}
