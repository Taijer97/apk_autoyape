import 'dart:convert';
import 'dart:io';

import 'api_config.dart';
import 'models/notification_item.dart';
import 'token_manager.dart';

Future<List<NotificationItem>> fetchNotificationsFromApi() async {
  if (ApiConfig.listenersEndpoint.trim().isEmpty) return [];

  final client = HttpClient();
  try {
    final uri = Uri.parse(ApiConfig.listenersEndpoint);
    final json = await _getJson(client, uri, retryOnUnauthorized: true);
    if (json is! List) return [];

    final items = <NotificationItem>[];
    for (final e in json) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final timestamp = map['timestamp'];
      final fechaRaw = map['fecha'];

      DateTime fecha;
      if (timestamp is int) {
        fecha = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (fechaRaw is String) {
        fecha = DateTime.tryParse(fechaRaw) ?? DateTime.now();
      } else {
        fecha = DateTime.now();
      }

      final item = NotificationItem(
        app: (map['app'] ?? '').toString(),
        nombre: (map['nombre'] ?? '').toString(),
        monto: (map['monto'] ?? '').toString(),
        codigoSeguridad: (map['codigoSeguridad'] ?? '').toString(),
        fecha: fecha,
      );
      items.add(item);
    }

    items.sort((a, b) => b.fecha.compareTo(a.fecha));
    return items;
  } finally {
    client.close(force: true);
  }
}

Future<void> sendNotificationToApi(NotificationItem item) async {
  if (ApiConfig.transactionsEndpoint.trim().isEmpty) return;

  final client = HttpClient();
  try {
    final uri = Uri.parse(ApiConfig.transactionsEndpoint);
    await _postJson(client, uri, item.toJson(), retryOnUnauthorized: true);
  } finally {
    client.close(force: true);
  }
}

Future<dynamic> _getJson(
  HttpClient client,
  Uri uri, {
  required bool retryOnUnauthorized,
}) async {
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

  final token = await TokenManager.getValidToken();
  if (token != null && token.trim().isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }

  final response = await request.close();
  final responseBody = await utf8.decoder.bind(response).join();

  if (response.statusCode == 401 && retryOnUnauthorized) {
    await TokenManager.refreshToken();
    return _getJson(client, uri, retryOnUnauthorized: false);
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    return null;
  }

  return jsonDecode(responseBody);
}

Future<void> _postJson(
  HttpClient client,
  Uri uri,
  Map<String, dynamic> body, {
  required bool retryOnUnauthorized,
}) async {
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

  final token = await TokenManager.getValidToken();
  if (token != null && token.trim().isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }

  request.add(utf8.encode(jsonEncode(body)));
  final response = await request.close();
  await response.drain();

  if (response.statusCode == 401 && retryOnUnauthorized) {
    await TokenManager.refreshToken();
    await _postJson(client, uri, body, retryOnUnauthorized: false);
  }
}
