
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';

class AuthService {
  static const String baseUrl = '${ApiConfig.host}/api/auth';

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _accessKey =
      'tripmate_access_token';

  static const String _refreshKey =
      'tripmate_refresh_token';

  static const String _userKey =
      'tripmate_user';

  // ==========================================
  // CADASTRO
  // ==========================================

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register/'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    final data =
    jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      return data;
    }

    String message = 'Não foi possível criar sua conta.';

    if (data['email'] is List &&
        (data['email'] as List).isNotEmpty) {
      message = data['email'][0].toString();
    } else if (data['password'] is List &&
        (data['password'] as List).isNotEmpty) {
      message = data['password'][0].toString();
    } else if (data['name'] is List &&
        (data['name'] as List).isNotEmpty) {
      message = data['name'][0].toString();
    } else if (data['detail'] != null) {
      message = data['detail'].toString();
    }

    throw Exception(message);
  }

  // ==========================================
  // LOGIN
  // ==========================================

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    final data =
    jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final access = data['access'];
      final refresh = data['refresh'];
      final user = data['user'];

      if (access is! String ||
          refresh is! String ||
          user is! Map<String, dynamic>) {
        throw Exception(
          'A resposta de autenticação está incompleta.',
        );
      }

      await _storage.write(
        key: _accessKey,
        value: access,
      );

      await _storage.write(
        key: _refreshKey,
        value: refresh,
      );

      await _saveUser(user);

      return data;
    }

    throw Exception(
      data['detail']?.toString() ??
          'Não foi possível realizar o login.',
    );
  }

  // ==========================================
  // ARMAZENAMENTO DA SESSÃO
  // ==========================================

  Future<void> _saveUser(
      Map<String, dynamic> user,
      ) async {
    await _storage.write(
      key: _userKey,
      value: jsonEncode(user),
    );
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshKey);
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    final userJson = await _storage.read(
      key: _userKey,
    );

    if (userJson == null) return null;

    try {
      final decoded = jsonDecode(userJson);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return null;
    } on FormatException {
      return null;
    }
  }

  Future<bool> hasSavedSession() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();

    return access != null &&
        access.isNotEmpty &&
        refresh != null &&
        refresh.isNotEmpty;
  }

  // ==========================================
  // RENOVAÇÃO DO TOKEN JWT
  // ==========================================

  Future<bool> refreshSession() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null ||
        refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)
        as Map<String, dynamic>;

        final newAccessToken = data['access'];

        if (newAccessToken is! String ||
            newAccessToken.isEmpty) {
          return false;
        }

        await _storage.write(
          key: _accessKey,
          value: newAccessToken,
        );

        final newRefreshToken = data['refresh'];

        if (newRefreshToken is String &&
            newRefreshToken.isNotEmpty) {
          await _storage.write(
            key: _refreshKey,
            value: newRefreshToken,
          );
        }

        return true;
      }

      if (response.statusCode == 401 ||
          response.statusCode == 400) {
        await logout();
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // CONSULTAR DADOS ATUAIS DO USUÁRIO
  // GET /api/auth/me/
  // ==========================================

  Future<Map<String, dynamic>> getCurrentUser() async {
    var token = await getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    var response = await http.get(
      Uri.parse('$baseUrl/me/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshSession();

      if (!refreshed) {
        throw Exception(
          'Sua sessão expirou. Faça login novamente.',
        );
      }

      token = await getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Não foi possível renovar sua sessão.',
        );
      }

      response = await http.get(
        Uri.parse('$baseUrl/me/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível atualizar os dados do perfil.',
      );
    }

    final user = jsonDecode(response.body)
    as Map<String, dynamic>;

    await _saveUser(user);

    return user;
  }

  // ==========================================
  // ENVIAR OU SUBSTITUIR FOTO DE PERFIL
  // PATCH /api/auth/me/avatar/
  // ==========================================

  Future<Map<String, dynamic>> uploadAvatar(
      XFile image,
      ) async {
    var token = await getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    Future<http.Response> sendImage(
        String accessToken,
        ) async {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/me/avatar/'),
      );

      request.headers['Authorization'] =
      'Bearer $accessToken';

      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          image.path,
          filename: image.name,
        ),
      );

      final streamedResponse = await request.send();

      return http.Response.fromStream(
        streamedResponse,
      );
    }

    var response = await sendImage(token);

    if (response.statusCode == 401) {
      final refreshed = await refreshSession();

      if (!refreshed) {
        throw Exception(
          'Sua sessão expirou. Faça login novamente.',
        );
      }

      token = await getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Não foi possível renovar sua sessão.',
        );
      }

      response = await sendImage(token);
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)
      as Map<String, dynamic>;

      final user = data['user'];

      if (user is! Map<String, dynamic>) {
        throw Exception(
          'O servidor não retornou os dados do usuário.',
        );
      }

      await _saveUser(user);

      return user;
    }

    if (response.statusCode == 400) {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        final avatarErrors = data['avatar'];

        if (avatarErrors is List &&
            avatarErrors.isNotEmpty) {
          throw Exception(
            avatarErrors.first.toString(),
          );
        }
      }
    }

    throw Exception(
      'Não foi possível enviar a foto de perfil.',
    );
  }

  // ==========================================
  // REMOVER FOTO DE PERFIL
  // DELETE /api/auth/me/avatar/
  // ==========================================

  Future<Map<String, dynamic>> removeAvatar() async {
    var token = await getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    var response = await http.delete(
      Uri.parse('$baseUrl/me/avatar/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      final refreshed = await refreshSession();

      if (!refreshed) {
        throw Exception(
          'Sua sessão expirou. Faça login novamente.',
        );
      }

      token = await getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Não foi possível renovar sua sessão.',
        );
      }

      response = await http.delete(
        Uri.parse('$baseUrl/me/avatar/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível remover a foto de perfil.',
      );
    }

    final data = jsonDecode(response.body)
    as Map<String, dynamic>;

    final user = data['user'];

    if (user is! Map<String, dynamic>) {
      throw Exception(
        'O servidor não retornou os dados do usuário.',
      );
    }

    await _saveUser(user);

    return user;
  }

  // ==========================================
  // ATUALIZAR NOME E E-MAIL
  // PATCH /api/auth/me/
  // ==========================================

  Future<Map<String, dynamic>> updateAccount({
    required String name,
    required String email,
    String? currentPassword,
  }) async {
    var token = await getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
    };

    if (currentPassword != null &&
        currentPassword.isNotEmpty) {
      body['current_password'] = currentPassword;
    }

    Future<http.Response> sendRequest(
        String accessToken,
        ) {
      return http.patch(
        Uri.parse('$baseUrl/me/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    }

    var response = await sendRequest(token);

    if (response.statusCode == 401) {
      final refreshed = await refreshSession();

      if (!refreshed) {
        throw Exception(
          'Sua sessão expirou. Faça login novamente.',
        );
      }

      token = await getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Não foi possível renovar sua sessão.',
        );
      }

      response = await sendRequest(token);
    }

    final data = jsonDecode(response.body)
    as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final user = data['user'];

      if (user is! Map<String, dynamic>) {
        throw Exception(
          'O servidor não retornou os dados atualizados.',
        );
      }

      await _saveUser(user);

      return user;
    }

    throw Exception(
      _accountErrorMessage(
        data,
        'Não foi possível atualizar seus dados.',
      ),
    );
  }

  // ==========================================
  // ALTERAR SENHA
  // POST /api/auth/me/password/
  // ==========================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    var token = await getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Sessão não encontrada. Faça login novamente.',
      );
    }

    final body = {
      'current_password': currentPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    };

    Future<http.Response> sendRequest(
        String accessToken,
        ) {
      return http.post(
        Uri.parse('$baseUrl/me/password/'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    }

    var response = await sendRequest(token);

    if (response.statusCode == 401) {
      final refreshed = await refreshSession();

      if (!refreshed) {
        throw Exception(
          'Sua sessão expirou. Faça login novamente.',
        );
      }

      token = await getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Não foi possível renovar sua sessão.',
        );
      }

      response = await sendRequest(token);
    }

    if (response.statusCode == 200) {
      // Solicita novo login após alterar a senha.
      await logout();
      return;
    }

    final data = jsonDecode(response.body)
    as Map<String, dynamic>;

    throw Exception(
      _accountErrorMessage(
        data,
        'Não foi possível alterar sua senha.',
      ),
    );
  }

  // ==========================================
  // MENSAGENS DE VALIDAÇÃO DA API
  // ==========================================

  String _accountErrorMessage(
      Map<String, dynamic> data,
      String fallback,
      ) {
    const fields = [
      'name',
      'email',
      'current_password',
      'new_password',
      'confirm_password',
      'non_field_errors',
      'detail',
    ];

    for (final field in fields) {
      final error = data[field];

      if (error is List && error.isNotEmpty) {
        return error.first.toString();
      }

      if (error is String && error.isNotEmpty) {
        return error;
      }
    }

    return fallback;
  }

  // ==========================================
  // SAIR DA CONTA
  // ==========================================

  Future<void> logout() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}
