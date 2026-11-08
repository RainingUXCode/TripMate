import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripmate/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> storage;
  late AuthService service;

  setUp(() {
    storage = {
      'tripmate_access_token': 'access-old',
      'tripmate_refresh_token': 'refresh-old',
      'tripmate_user': jsonEncode({'id': 7, 'name': 'QA User'}),
    };
    FlutterSecureStorage.setMockInitialValues(storage);
    service = AuthService();
  });

  test('renova e grava access e refresh tokens novos', () async {
    final result = await _withClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/token/refresh/');
      expect(jsonDecode(request.body), {'refresh': 'refresh-old'});
      return http.Response(
        jsonEncode({'access': 'access-new', 'refresh': 'refresh-new'}),
        200,
      );
    }, service.refreshSession);

    expect(result, isTrue);
    expect(storage['tripmate_access_token'], 'access-new');
    expect(storage['tripmate_refresh_token'], 'refresh-new');
  });

  test('sessão expirada limpa dados locais', () async {
    final result = await _withClient((request) async {
      expect(request.url.path, '/api/auth/token/refresh/');
      return http.Response(jsonEncode({'detail': 'Token inválido'}), 401);
    }, service.refreshSession);

    expect(result, isFalse);
    expect(storage, isEmpty);
    expect(await service.hasSavedSession(), isFalse);
    expect(await service.getSavedUser(), isNull);
  });

  test(
    'falha de conexão no refresh preserva a sessão para nova tentativa',
    () async {
      final result = await _withClient((_) async {
        throw http.ClientException('connection reset');
      }, service.refreshSession);

      expect(result, isFalse);
      expect(storage['tripmate_access_token'], 'access-old');
      expect(storage['tripmate_refresh_token'], 'refresh-old');
    },
  );

  test(
    'perfil renova uma vez após 401 e persiste a resposta do usuário',
    () async {
      var profileCalls = 0;
      final user = {'id': 7, 'name': 'Updated QA', 'email': 'qa@example.test'};
      final actualUser = await _withClient((request) async {
        if (request.url.path.endsWith('/token/refresh/')) {
          return http.Response(jsonEncode({'access': 'access-new'}), 200);
        }
        profileCalls++;
        expect(request.url.path, '/api/auth/me/');
        if (profileCalls == 1) {
          expect(request.headers['Authorization'], 'Bearer access-old');
          return http.Response('{}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer access-new');
        return http.Response(jsonEncode(user), 200);
      }, service.getCurrentUser);

      expect(actualUser, user);
      expect(profileCalls, 2);
      expect(storage['tripmate_access_token'], 'access-new');
      expect(jsonDecode(storage['tripmate_user']!), user);
    },
  );

  test(
    'falha de refresh ao consultar perfil não apaga conta por erro de rede',
    () async {
      final error = await _withClient(
        (request) async {
          if (request.url.path.endsWith('/token/refresh/')) {
            throw http.ClientException('offline');
          }
          return http.Response('{}', 401);
        },
        () => service.getCurrentUser(),
      ).then<Object?>((_) => null, onError: (e) => e);

      expect(error, isA<Exception>());
      expect('$error', contains('Sua sessão expirou'));
      expect(storage['tripmate_refresh_token'], 'refresh-old');
    },
  );

  test(
    'updateAccount envia valores normalizados e tratamento de erro HTTP',
    () async {
      final user = {'id': 7, 'name': 'QA Name', 'email': 'qa@example.test'};
      final updated = await _withClient(
        (request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/auth/me/');
          expect(request.headers['Authorization'], 'Bearer access-old');
          expect(jsonDecode(request.body), {
            'name': 'QA Name',
            'email': 'qa@example.test',
          });
          return http.Response(jsonEncode({'user': user}), 200);
        },
        () => service.updateAccount(
          name: ' QA Name ',
          email: ' QA@EXAMPLE.TEST ',
        ),
      );

      expect(updated, user);
      expect(jsonDecode(storage['tripmate_user']!), user);

      final error = await _withClient(
        (_) async {
          return http.Response(
            jsonEncode({
              'email': ['E-mail em uso'],
            }),
            400,
          );
        },
        () =>
            service.updateAccount(name: 'QA Name', email: 'other@example.test'),
      ).then<Object?>((_) => null, onError: (e) => e);
      expect('$error', contains('E-mail em uso'));
    },
  );

  test(
    'alteração de senha limpa tokens e usuário para exigir novo login',
    () async {
      await _withClient(
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/me/password/');
          expect(request.headers['Authorization'], 'Bearer access-old');
          expect(jsonDecode(request.body), {
            'current_password': 'old-password',
            'new_password': 'new-password',
            'confirm_password': 'new-password',
          });
          return http.Response(jsonEncode({'message': 'ok'}), 200);
        },
        () => service.changePassword(
          currentPassword: 'old-password',
          newPassword: 'new-password',
          confirmPassword: 'new-password',
        ),
      );

      expect(storage, isEmpty);
      expect(await service.hasSavedSession(), isFalse);
    },
  );
}

Future<T> _withClient<T>(
  Future<http.Response> Function(http.Request) handler,
  Future<T> Function() callback,
) async {
  final client = MockClient(handler);
  try {
    return await http.runWithClient(callback, () => client);
  } finally {
    client.close();
  }
}
