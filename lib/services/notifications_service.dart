import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class NotificationsServiceException implements Exception {
  final String message;
  final int? statusCode;

  const NotificationsServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NotificationsPage {
  final List<Map<String, dynamic>> results;
  final int count;
  final int? nextPage;

  const NotificationsPage({
    required this.results,
    required this.count,
    required this.nextPage,
  });
}

class NotificationsService {
  static const String baseUrl = '${ApiConfig.host}/api/notifications';

  final AuthService _authService;
  final http.Client _client;
  final bool _ownsClient;

  NotificationsService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<int> getUnreadCount() async {
    final result = await _request('GET', Uri.parse('$baseUrl/unread-count/'));
    return int.tryParse('${result['unread_count']}') ?? 0;
  }

  Future<NotificationsPage> getPage({int page = 1}) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {'page': '$page'});
    final result = await _request('GET', uri);
    final raw = result['results'];
    if (raw is! List) {
      throw const NotificationsServiceException(
        'A resposta de notificações é inválida.',
      );
    }
    return NotificationsPage(
      results: raw
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      count: int.tryParse('${result['count']}') ?? raw.length,
      nextPage: _pageFromUrl(result['next']?.toString()),
    );
  }

  Future<Map<String, dynamic>> markAsRead(int notificationId) => _request(
    'POST',
    Uri.parse('$baseUrl/$notificationId/read/'),
    body: const {},
  );

  Future<void> markAllAsRead() async {
    await _request('POST', Uri.parse('$baseUrl/read-all/'), body: const {});
  }

  int? _pageFromUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(Uri.tryParse(value)?.queryParameters['page'] ?? '');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    var token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const NotificationsServiceException(
        'Faça login para ver notificações.',
      );
    }

    Future<http.Response> send(String accessToken) {
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
      if (method == 'GET') return _client.get(uri, headers: headers);
      return _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? const {}),
      );
    }

    http.Response response;
    try {
      response = await send(token);
      if (response.statusCode == 401) {
        final refreshed = await _authService.refreshSession();
        if (!refreshed) {
          throw const NotificationsServiceException(
            'Sua sessão expirou. Faça login novamente.',
            statusCode: 401,
          );
        }
        token = await _authService.getAccessToken();
        if (token == null || token.isEmpty) {
          throw const NotificationsServiceException(
            'Não foi possível renovar sua sessão.',
            statusCode: 401,
          );
        }
        response = await send(token);
      }
    } on NotificationsServiceException {
      rethrow;
    } catch (_) {
      throw const NotificationsServiceException(
        'Não foi possível conectar ao servidor de notificações.',
      );
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw NotificationsServiceException(
        'Resposta inválida do servidor.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotificationsServiceException(
        data['detail']?.toString() ?? 'Não foi possível carregar notificações.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }
}
