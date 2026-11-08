
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class FriendsService {
  static const String baseUrl = '${ApiConfig.host}/api/friends';

  final AuthService _authService = AuthService();

  // ==========================================
  // REQUISIÇÕES AUTENTICADAS
  // ==========================================

  Future<http.Response> _request(
      String method,
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    var token = await _authService.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    Future<http.Response> send(String accessToken) {
      final uri = Uri.parse('$baseUrl$endpoint');

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

      switch (method) {
        case 'GET':
          return http.get(uri, headers: headers);

        case 'POST':
          return http.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );

        case 'DELETE':
          return http.delete(uri, headers: headers);

        default:
          throw Exception(
            'Método HTTP não suportado.',
          );
      }
    }

    var response = await send(token);

    if (response.statusCode == 401) {
      final refreshed =
      await _authService.refreshSession();

      if (!refreshed) {
        throw Exception(
          'Sua sessão expirou. Faça login novamente.',
        );
      }

      token = await _authService.getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Não foi possível renovar sua sessão.',
        );
      }

      response = await send(token);
    }

    return response;
  }

  // ==========================================
  // TRATAMENTO DE RESPOSTAS
  // ==========================================

  Map<String, dynamic> _decodeResponse(
      http.Response response,
      ) {
    if (response.statusCode == 204) {
      return {};
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Resposta inesperada do servidor.',
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['detail']?.toString() ??
          data['message']?.toString() ??
          'Não foi possível concluir a operação.',
    );
  }

  // ==========================================
  // BUSCAR USUÁRIOS
  // ==========================================

  Future<List<Map<String, dynamic>>> searchUsers(
      String query,
      ) async {
    if (query.trim().length < 2) {
      return [];
    }

    final encodedQuery =
    Uri.encodeQueryComponent(query.trim());

    final response = await _request(
      'GET',
      '/search/?q=$encodedQuery',
    );

    final data = _decodeResponse(response);

    return (data['results'] as List)
        .map(
          (item) => Map<String, dynamic>.from(item),
    )
        .toList();
  }

  // ==========================================
  // LISTAR AMIGOS CONFIRMADOS
  // ==========================================

  Future<List<Map<String, dynamic>>> getFriends() async {
    final response = await _request('GET', '/');

    final data = _decodeResponse(response);

    return (data['results'] as List)
        .map(
          (item) => Map<String, dynamic>.from(item),
    )
        .toList();
  }

  // ==========================================
  // SOLICITAÇÕES RECEBIDAS E ENVIADAS
  // ==========================================

  Future<Map<String, dynamic>> getRequests() async {
    final response = await _request(
      'GET',
      '/requests/',
    );

    return _decodeResponse(response);
  }

  // ==========================================
  // ENVIAR SOLICITAÇÃO DE AMIZADE
  // ==========================================

  Future<Map<String, dynamic>> sendFriendRequest(
      int receiverId,
      ) async {
    final response = await _request(
      'POST',
      '/requests/send/',
      body: {
        'receiver_id': receiverId,
      },
    );

    return _decodeResponse(response);
  }

  // ==========================================
  // ACEITAR SOLICITAÇÃO
  // ==========================================

  Future<Map<String, dynamic>> acceptFriendRequest(
      int friendshipId,
      ) async {
    final response = await _request(
      'POST',
      '/requests/$friendshipId/accept/',
    );

    return _decodeResponse(response);
  }

  // ==========================================
  // RECUSAR SOLICITAÇÃO
  // ==========================================

  Future<Map<String, dynamic>> rejectFriendRequest(
      int friendshipId,
      ) async {
    final response = await _request(
      'POST',
      '/requests/$friendshipId/reject/',
    );

    return _decodeResponse(response);
  }

  // ==========================================
  // CANCELAR SOLICITAÇÃO OU REMOVER AMIGO
  // ==========================================

  Future<void> deleteFriendship(
      int friendshipId,
      ) async {
    final response = await _request(
      'DELETE',
      '/requests/$friendshipId/',
    );

    _decodeResponse(response);
  }
}
