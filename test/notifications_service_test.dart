import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/services/notifications_service.dart';

void main() {
  test('loads real unread count and paginated notification rows', () async {
    final requests = <http.Request>[];
    final service = NotificationsService(
      authService: _FakeAuthService(),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/unread-count/')) {
          return http.Response('{"unread_count":2}', 200);
        }
        return http.Response(
          jsonEncode({
            'count': 21,
            'next': 'http://127.0.0.1:8000/api/notifications/?page=2',
            'previous': null,
            'results': [_notification()],
          }),
          200,
        );
      }),
    );

    final count = await service.getUnreadCount();
    final page = await service.getPage();

    expect(count, 2);
    expect(page.count, 21);
    expect(page.results.single['event_type'], 'friend_request');
    expect(page.nextPage, 2);
    expect(requests.map((request) => request.method), ['GET', 'GET']);
    expect(requests.last.url.queryParameters['page'], '1');
  });

  test(
    'reading endpoints use the authenticated user and expected methods',
    () async {
      final requests = <http.Request>[];
      final service = NotificationsService(
        authService: _FakeAuthService(),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"id":5,"is_read":true}', 200);
        }),
      );

      await service.markAsRead(5);
      await service.markAllAsRead();

      expect(requests.map((request) => request.method), ['POST', 'POST']);
      expect(requests.map((request) => request.url.path), [
        '/api/notifications/5/read/',
        '/api/notifications/read-all/',
      ]);
      expect(
        requests.every(
          (request) => request.headers['Authorization'] == 'Bearer token',
        ),
        isTrue,
      );
    },
  );

  test('does not hide HTTP authorization and connection errors', () async {
    final service = NotificationsService(
      authService: _FakeAuthService(),
      client: MockClient(
        (_) async => http.Response('{"detail":"Indisponível."}', 404),
      ),
    );
    await expectLater(
      service.markAsRead(77),
      throwsA(
        isA<NotificationsServiceException>().having(
          (error) => error.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });
}

Map<String, dynamic> _notification() => {
  'id': 5,
  'event_type': 'friend_request',
  'title': 'Nova solicitação de amizade',
  'message': 'Marina enviou uma solicitação.',
  'resource_type': 'friendship',
  'resource_id': 8,
  'context_id': null,
  'created_at': '2026-11-07T10:00:00Z',
  'read_at': null,
  'is_read': false,
};

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'token';
}
