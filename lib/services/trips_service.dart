import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/trip.dart';
import 'api_config.dart';
import 'auth_service.dart';

class TripsServiceException implements Exception {
  final String message;
  final int? statusCode;

  const TripsServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class TripsService {
  static const String baseUrl = '${ApiConfig.host}/api/trips';

  static String? resolveMediaUrl(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme && uri.host.isNotEmpty) return uri.toString();

    final apiRoot = Uri.parse(baseUrl)
        .replace(path: '/', query: null, fragment: null);
    return apiRoot.resolveUri(uri).toString();
  }

  final AuthService _authService;
  final http.Client _client;
  final bool _ownsClient;

  TripsService({AuthService? authService, http.Client? client})
    : _authService = authService ?? AuthService(),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  void close() {
    if (_ownsClient) _client.close();
  }

  Uri _financeUri(int tripId, String path) =>
      Uri.parse('$baseUrl/$tripId/finance/$path');

  Future<Map<String, dynamic>> getFinanceSummary(int tripId) async =>
      _asMap(await _request('GET', _financeUri(tripId, 'summary/')));

  Future<Map<String, dynamic>> getFinanceBudget(int tripId) async =>
      _asMap(await _request('GET', _financeUri(tripId, 'budget/')));

  Future<Map<String, dynamic>> updateFinanceBudget(
    int tripId,
    String? amount,
  ) async => _asMap(
    await _request(
      'PUT',
      _financeUri(tripId, 'budget/'),
      body: {'budget_amount': amount},
    ),
  );

  Future<List<Map<String, dynamic>>> getExpenses(int tripId) async {
    final value = await _request('GET', _financeUri(tripId, 'expenses/'));
    if (value is! List) {
      throw const TripsServiceException('Lista de despesas inválida.');
    }
    return value.map((item) => _asMap(item)).toList(growable: false);
  }

  Future<Map<String, dynamic>> getExpense(int tripId, int expenseId) async =>
      _asMap(
        await _request('GET', _financeUri(tripId, 'expenses/$expenseId/')),
      );

  Future<Map<String, dynamic>> createExpense(
    int tripId,
    Map<String, dynamic> payload,
  ) async => _asMap(
    await _request('POST', _financeUri(tripId, 'expenses/'), body: payload),
  );

  Future<Map<String, dynamic>> updateExpense(
    int tripId,
    int expenseId,
    Map<String, dynamic> payload,
  ) async => _asMap(
    await _request(
      'PUT',
      _financeUri(tripId, 'expenses/$expenseId/'),
      body: payload,
    ),
  );

  Future<Map<String, dynamic>> cancelExpense(
    int tripId,
    int expenseId,
    int version,
  ) async => _asMap(
    await _request(
      'DELETE',
      _financeUri(tripId, 'expenses/$expenseId/'),
      body: {'version': version},
    ),
  );

  Future<List<Map<String, dynamic>>> getSettlementProposals(int tripId) async =>
      _asMapList(await _request('GET', _financeUri(tripId, 'proposals/')));

  Future<List<Map<String, dynamic>>> getSettlements(int tripId) async =>
      _asMapList(await _request('GET', _financeUri(tripId, 'settlements/')));

  Future<Map<String, dynamic>> getSettlement(
    int tripId,
    int settlementId,
  ) async => _asMap(
    await _request('GET', _financeUri(tripId, 'settlements/$settlementId/')),
  );

  Future<Map<String, dynamic>> createSettlement(
    int tripId,
    Map<String, dynamic> payload,
  ) async => _asMap(
    await _request('POST', _financeUri(tripId, 'settlements/'), body: payload),
  );

  Future<Map<String, dynamic>> confirmSettlement(
    int tripId,
    int settlementId,
  ) async => _asMap(
    await _request(
      'POST',
      _financeUri(tripId, 'settlements/$settlementId/confirm/'),
      body: const {},
    ),
  );

  Future<Map<String, dynamic>> cancelSettlement(
    int tripId,
    int settlementId,
  ) async => _asMap(
    await _request(
      'POST',
      _financeUri(tripId, 'settlements/$settlementId/cancel/'),
      body: const {},
    ),
  );

  Future<List<Map<String, dynamic>>> getFinanceHistory(int tripId) async =>
      _asMapList(await _request('GET', _financeUri(tripId, 'history/')));

  Future<Trip> createTrip({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String description = '',
    XFile? coverImage,
    List<int> inviteeIds = const [],
  }) async {
    final result = await _createTripRequest(
      name: name.trim(),
      destination: destination.trim(),
      startDate: startDate,
      endDate: endDate,
      description: description.trim(),
      coverImage: coverImage,
      inviteeIds: inviteeIds,
    );
    return Trip.fromJson(_asMap(result));
  }

  Future<dynamic> _createTripRequest({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    required XFile? coverImage,
    required List<int> inviteeIds,
  }) async {
    var token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const TripsServiceException(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    var response = await _sendTripMultipart(
      token: token,
      name: name,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      description: description,
      coverImage: coverImage,
      inviteeIds: inviteeIds,
    );

    if (response.statusCode == 401) {
      final refreshed = await _authService.refreshSession();
      if (!refreshed) {
        throw const TripsServiceException(
          'Sua sessão expirou. Faça login novamente.',
        );
      }
      token = await _authService.getAccessToken() ?? '';
      if (token.isEmpty) {
        throw const TripsServiceException(
          'Não foi possível renovar sua sessão.',
        );
      }
      // A 401 é uma resposta explícita de autenticação; reconstruímos o
      // multipart para o retry único. Erros de conexão nunca repetem o POST.
      response = await _sendTripMultipart(
        token: token,
        name: name,
        destination: destination,
        startDate: startDate,
        endDate: endDate,
        description: description,
        coverImage: coverImage,
        inviteeIds: inviteeIds,
      );
    }

    final decoded = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TripsServiceException(_errorMessage(decoded));
    }
    return decoded;
  }

  Future<http.Response> _sendTripMultipart({
    required String token,
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    required XFile? coverImage,
    required List<int> inviteeIds,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll({
        'name': name,
        'destination': destination,
        'start_date': _dateForApi(startDate),
        'end_date': _dateForApi(endDate),
        'description': description,
        'invitee_ids': jsonEncode(inviteeIds),
      });

    try {
      if (coverImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'cover_image',
            coverImage.path,
            filename: coverImage.name,
          ),
        );
      }
      final streamed = await _client.send(request);
      return await http.Response.fromStream(streamed);
    } on SocketException {
      throw const TripsServiceException(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    } on FileSystemException {
      throw const TripsServiceException(
        'Não foi possível ler a foto selecionada. Escolha-a novamente.',
      );
    } on http.ClientException {
      // Não repetir: o servidor pode ter recebido a criação antes da falha.
      throw const TripsServiceException(
        'A conexão foi interrompida. Verifique suas viagens antes de tentar novamente.',
      );
    }
  }

  Future<List<Trip>> getTrips() async {
    final result = await _request('GET', Uri.parse('$baseUrl/'));
    if (result is! List) {
      throw const TripsServiceException(
        'O servidor retornou uma lista de viagens inválida.',
      );
    }
    final trips = result.map((item) => _tripFromMap(_asMap(item))).toList();
    trips.sort((a, b) {
      final byCreatedAt = b.createdAt.compareTo(a.createdAt);
      return byCreatedAt != 0 ? byCreatedAt : b.id.compareTo(a.id);
    });
    return List<Trip>.unmodifiable(trips);
  }

  Future<Trip> getTrip(int tripId) async {
    final result = await _request('GET', Uri.parse('$baseUrl/$tripId/'));
    return _tripFromMap(_asMap(result));
  }

  Future<List<TripInvitation>> getInvitations() async {
    final result = await _request('GET', Uri.parse('$baseUrl/invitations/'));
    if (result is! List) {
      throw const TripsServiceException('Lista de convites inválida.');
    }
    return List<TripInvitation>.unmodifiable(
      result.map((item) {
        final invitation = TripInvitation.fromJson(_asMap(item));
        return TripInvitation(
          tripId: invitation.tripId,
          name: invitation.name,
          destination: invitation.destination,
          startDate: invitation.startDate,
          endDate: invitation.endDate,
          coverImageUrl: resolveMediaUrl(invitation.coverImageUrl),
          organizer: invitation.organizer,
        );
      }),
    );
  }

  Future<Map<String, dynamic>> respondToInvitation(
    int tripId, {
    required bool accept,
  }) async => _asMap(
    await _request(
      'POST',
      Uri.parse('$baseUrl/$tripId/invitation/${accept ? 'accept' : 'reject'}/'),
      body: const {},
    ),
  );

  Future<Trip> inviteUsers(int tripId, List<int> userIds) async => _tripFromMap(
    _asMap(
      await _request(
        'POST',
        Uri.parse('$baseUrl/$tripId/invitations/'),
        body: {'user_ids': userIds},
      ),
    ),
  );

  Future<Map<String, dynamic>> getLeaveEligibility(int tripId) async => _asMap(
    await _request('GET', Uri.parse('$baseUrl/$tripId/leave-eligibility/')),
  );

  Future<Map<String, dynamic>> leaveTrip(int tripId) async => _asMap(
    await _request(
      'POST',
      Uri.parse('$baseUrl/$tripId/leave/'),
      body: const {},
    ),
  );

  Future<Trip> transferOrganizer(int tripId, int newOrganizerId) async =>
      _tripFromMap(
        _asMap(
          await _request(
            'POST',
            Uri.parse('$baseUrl/$tripId/transfer-organizer/'),
            body: {'new_organizer_id': newOrganizerId},
          ),
        ),
      );

  Future<Map<String, dynamic>> removeParticipant(
    int tripId,
    int userId,
  ) async => _asMap(
    await _request('DELETE', Uri.parse('$baseUrl/$tripId/members/$userId/')),
  );

  Future<void> deleteTrip(int tripId) async {
    await _request('DELETE', Uri.parse('$baseUrl/$tripId/'));
  }

  Trip _tripFromMap(Map<String, dynamic> json) {
    return Trip.fromJson({
      ...json,
      'cover_image_url': resolveMediaUrl(json['cover_image_url']?.toString()),
    });
  }

  Future<dynamic> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    var token = await _authService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const TripsServiceException(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    var response = await _send(method, uri, token, body);
    if (response.statusCode == 401) {
      final refreshed = await _authService.refreshSession();
      if (!refreshed) {
        throw const TripsServiceException(
          'Sua sessão expirou. Faça login novamente.',
        );
      }

      token = await _authService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw const TripsServiceException(
          'Não foi possível renovar sua sessão.',
        );
      }
      response = await _send(method, uri, token, body);
    }

    final decoded = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TripsServiceException(
        _errorMessage(decoded),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    String token,
    Map<String, dynamic>? body,
  ) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    try {
      switch (method) {
        case 'GET':
          return await _client.get(uri, headers: headers);
        case 'POST':
          return await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
        case 'PUT':
          return await _client.put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
        case 'DELETE':
          return await _client.delete(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
        default:
          throw const TripsServiceException(
            'Operação de viagens não suportada.',
          );
      }
    } on SocketException {
      throw const TripsServiceException(
        'Não foi possível conectar ao servidor. Verifique sua conexão.',
      );
    } on http.ClientException {
      throw const TripsServiceException(
        'Não foi possível conectar ao servidor. Tente novamente.',
      );
    }
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const TripsServiceException(
          'O servidor retornou uma resposta inválida.',
        );
      }
      return null;
    }
  }

  String _errorMessage(dynamic decoded) {
    if (decoded is Map) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;

      for (final value in decoded.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const TripsServiceException(
      'O servidor retornou os dados da viagem em formato inválido.',
    );
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      throw const TripsServiceException('Lista financeira inválida.');
    }
    return value.map((item) => _asMap(item)).toList(growable: false);
  }

  String _dateForApi(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
