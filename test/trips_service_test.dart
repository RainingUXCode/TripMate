import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/services/trips_service.dart';

void main() {
  test('createTrip sends multipart fields, cover and invitation IDs', () async {
    final auth = _FakeAuthService();
    http.MultipartRequest? capturedRequest;
    final temp = await Directory.systemTemp.createTemp('tripmate-cover-test');
    final coverFile = File('${temp.path}${Platform.pathSeparator}cover.png');
    await coverFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));
    final client = MockClient.streaming((request, bodyStream) async {
      expect(request, isA<http.MultipartRequest>());
      capturedRequest = request as http.MultipartRequest;
      await bodyStream.drain<void>();
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(jsonEncode(_tripJson()))),
        201,
      );
    });
    final service = TripsService(authService: auth, client: client);

    final trip = await service.createTrip(
      name: '  Lisboa  ',
      destination: ' Lisboa, Portugal ',
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 15),
      coverImage: XFile(coverFile.path),
      inviteeIds: [12, 34],
    );

    expect(capturedRequest!.method, 'POST');
    expect(capturedRequest!.url.toString(), '${TripsService.baseUrl}/');
    expect(capturedRequest!.headers['Authorization'], 'Bearer access-token');
    expect(capturedRequest!.fields['name'], 'Lisboa');
    expect(capturedRequest!.fields['destination'], 'Lisboa, Portugal');
    expect(capturedRequest!.fields['start_date'], '2026-08-10');
    expect(capturedRequest!.fields['end_date'], '2026-08-15');
    expect(capturedRequest!.fields['invitee_ids'], '[12,34]');
    expect(capturedRequest!.fields.containsKey('created_by'), isFalse);
    expect(capturedRequest!.files.single.field, 'cover_image');
    expect(trip.id, 17);
    expect(trip.organizerId, 4);
    await temp.delete(recursive: true);
  });

  test('getTrips and getTrip parse API data and use their paths', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/17/')) {
        return http.Response(jsonEncode(_tripJson()), 200);
      }
      return http.Response(jsonEncode([_tripJson()]), 200);
    });
    final service = TripsService(
      authService: _FakeAuthService(),
      client: client,
    );

    final trips = await service.getTrips();
    final trip = await service.getTrip(17);

    expect(trips, hasLength(1));
    expect(trips.single.acceptedParticipantsCount, 3);
    expect(trips.single.acceptedParticipants, hasLength(1));
    expect(trips.single.acceptedParticipants.single.name, 'Amiga aceita');
    expect(
      trips.single.acceptedParticipants.single.avatarUrl,
      'https://example.test/avatar.jpg',
    );
    expect(trips.single.coverImageUrl, 'http://127.0.0.1:8000/media/capa.jpg');
    expect(
      trips.single.acceptedParticipants.any(
        (participant) => participant.name == 'Pendente',
      ),
      isFalse,
    );
    expect(trip.destination, 'Lisboa, Portugal');
    expect(trip.canDelete, isTrue);
    expect(trip.rejectedInvitees, hasLength(1));
    expect(trip.rejectedInvitees.single.id, 14);
    expect(requestedPaths, ['/api/trips/', '/api/trips/17/']);
  });

  test(
    'invitation APIs use documented paths, methods and public preview data',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/invitations/') &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'trip_id': 17,
                'name': 'Fim de semana',
                'destination': 'Paraty, Brasil',
                'start_date': '2026-08-10',
                'end_date': '2026-08-12',
                'cover_image_url': '/media/trip.jpg',
                'organizer': {'id': 4, 'name': 'Marina'},
                'created_at': '2026-06-01T10:00:00Z',
              },
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/invitations/')) {
          return http.Response(jsonEncode(_tripJson()), 201);
        }
        return http.Response('{"trip_id":17,"status":"accepted"}', 200);
      });
      final service = TripsService(
        authService: _FakeAuthService(),
        client: client,
      );

      final invitations = await service.getInvitations();
      await service.respondToInvitation(17, accept: true);
      await service.respondToInvitation(18, accept: false);
      final updatedTrip = await service.inviteUsers(17, [22, 33]);

      expect(invitations.single.tripId, 17);
      expect(invitations.single.organizer.name, 'Marina');
      expect(
        invitations.single.coverImageUrl,
        'http://127.0.0.1:8000/media/trip.jpg',
      );
      expect(requests.map((request) => request.method), [
        'GET',
        'POST',
        'POST',
        'POST',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/api/trips/invitations/',
        '/api/trips/17/invitation/accept/',
        '/api/trips/18/invitation/reject/',
        '/api/trips/17/invitations/',
      ]);
      expect(jsonDecode(requests.last.body), {
        'user_ids': [22, 33],
      });
      expect(updatedTrip.pendingInvites.map((person) => person.id), [13]);
    },
  );

  test(
    'keeps invitation conflict status for stale or already answered invites',
    () async {
      final client = MockClient(
        (_) async => http.Response('{"detail":"Not found."}', 404),
      );
      final service = TripsService(
        authService: _FakeAuthService(),
        client: client,
      );

      await expectLater(
        service.respondToInvitation(17, accept: true),
        throwsA(
          isA<TripsServiceException>().having(
            (error) => error.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    },
  );

  test(
    'exit and organizer transfer use documented endpoints and payloads',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/leave-eligibility/')) {
          return http.Response(
            '{"can_leave":false,"eligible":false,"reasons":["outstanding_debt"],"reason_messages":{"outstanding_debt":"Você ainda possui valores a pagar nesta viagem."}}',
            200,
          );
        }
        if (request.url.path.endsWith('/leave/')) {
          return http.Response('{"trip_id":17,"status":"left"}', 200);
        }
        return http.Response(jsonEncode(_tripJson()), 200);
      });
      final service = TripsService(
        authService: _FakeAuthService(),
        client: client,
      );

      final eligibility = await service.getLeaveEligibility(17);
      final left = await service.leaveTrip(17);
      final updated = await service.transferOrganizer(17, 21);

      expect(eligibility['reasons'], ['outstanding_debt']);
      expect(left['status'], 'left');
      expect(updated.organizerId, 4);
      expect(requests.map((request) => request.method), [
        'GET',
        'POST',
        'POST',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/api/trips/17/leave-eligibility/',
        '/api/trips/17/leave/',
        '/api/trips/17/transfer-organizer/',
      ]);
      expect(jsonDecode(requests[1].body), {});
      expect(jsonDecode(requests[2].body), {'new_organizer_id': 21});
    },
  );

  test(
    'member removal and trip deletion use authenticated DELETE endpoints',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/members/12/')) {
          return http.Response(
            '{"trip_id":17,"user_id":12,"status":"left"}',
            200,
          );
        }
        return http.Response('', 204);
      });
      final service = TripsService(
        authService: _FakeAuthService(),
        client: client,
      );

      final removed = await service.removeParticipant(17, 12);
      await service.deleteTrip(17);

      expect(removed, {'trip_id': 17, 'user_id': 12, 'status': 'left'});
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        ['DELETE /api/trips/17/members/12/', 'DELETE /api/trips/17/'],
      );
      expect(
        requests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer access-token',
        ),
        isTrue,
      );
    },
  );

  test('does not repeat ambiguous leave or transfer POSTs', () async {
    for (final operation in ['leave', 'transfer']) {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        throw const SocketException('connection lost after request');
      });
      final service = TripsService(
        authService: _FakeAuthService(),
        client: client,
      );

      await expectLater(
        operation == 'leave'
            ? service.leaveTrip(17)
            : service.transferOrganizer(17, 21),
        throwsA(isA<TripsServiceException>()),
      );
      expect(requests, 1, reason: operation);
    }
  });

  test('finance requests use real endpoints and preserve decimal strings and versions', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path.endsWith('/expenses/')) {
        return http.Response('[]', 200);
      }
      return http.Response('{"ok":true}', 200);
    });
    final service = TripsService(
      authService: _FakeAuthService(),
      client: client,
    );

    await service.getFinanceSummary(17);
    await service.getExpense(17, 31);
    await service.updateFinanceBudget(17, '4000.00');
    await service.createExpense(17, {
      'amount': '12.30',
      'mode': 'exact',
      'shares': [
        {'user_id': 12, 'value': '6.15'},
      ],
    });
    await service.updateExpense(17, 31, {'amount': '12.30', 'version': 4});
    await service.cancelExpense(17, 31, 5);

    expect(requests.map((request) => request.method), [
      'GET',
      'GET',
      'PUT',
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(requests.map((request) => request.url.path), [
      '/api/trips/17/finance/summary/',
      '/api/trips/17/finance/expenses/31/',
      '/api/trips/17/finance/budget/',
      '/api/trips/17/finance/expenses/',
      '/api/trips/17/finance/expenses/31/',
      '/api/trips/17/finance/expenses/31/',
    ]);
    expect(jsonDecode(requests[2].body)['budget_amount'], '4000.00');
    expect(jsonDecode(requests[3].body)['amount'], '12.30');
    expect(jsonDecode(requests[3].body)['shares'][0]['value'], '6.15');
    expect(jsonDecode(requests[4].body)['version'], 4);
    expect(jsonDecode(requests[5].body)['version'], 5);
  });

  test(
    'sorts trips newest first with descending ID as a stable tie breaker',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            _tripJson()..['id'] = 5,
            _tripJson()..['id'] = 9,
            _tripJson()
              ..['id'] = 2
              ..['created_at'] = '2026-06-02T10:00:00Z',
          ]),
          200,
        ),
      );
      final service = TripsService(
        authService: _FakeAuthService(),
        client: client,
      );

      final trips = await service.getTrips();

      expect(trips.map((trip) => trip.id), [2, 9, 5]);
    },
  );

  test('settlement service uses documented paths and payloads', () async {
    final captured = <http.Request>[];
    final client = MockClient((request) async {
      captured.add(request);
      if (request.method == 'GET' &&
          (request.url.path.endsWith('/proposals/') ||
              request.url.path.endsWith('/settlements/') ||
              request.url.path.endsWith('/history/'))) {
        return http.Response('[]', 200);
      }
      return http.Response('{"id":9,"status":"pending"}', 200);
    });
    final service = TripsService(
      authService: _FakeAuthService(),
      client: client,
    );

    await service.getSettlementProposals(17);
    await service.getSettlements(17);
    await service.getSettlement(17, 9);
    await service.createSettlement(17, {
      'debtor_id': 2,
      'creditor_id': 1,
      'amount': '50.00',
      'request_key': '8f6ee938-b5be-4e18-99b0-77ac22acdc24',
    });
    await service.confirmSettlement(17, 9);
    await service.cancelSettlement(17, 9);
    await service.getFinanceHistory(17);

    expect(captured.map((request) => '${request.method} ${request.url.path}'), [
      'GET /api/trips/17/finance/proposals/',
      'GET /api/trips/17/finance/settlements/',
      'GET /api/trips/17/finance/settlements/9/',
      'POST /api/trips/17/finance/settlements/',
      'POST /api/trips/17/finance/settlements/9/confirm/',
      'POST /api/trips/17/finance/settlements/9/cancel/',
      'GET /api/trips/17/finance/history/',
    ]);
    expect(jsonDecode(captured[3].body)['amount'], '50.00');
    expect(
      jsonDecode(captured[3].body)['request_key'],
      '8f6ee938-b5be-4e18-99b0-77ac22acdc24',
    );
    expect(jsonDecode(captured[4].body), isEmpty);
    expect(jsonDecode(captured[5].body), isEmpty);
  });

  test('resolves relative cover URLs against the API host', () {
    expect(
      TripsService.resolveMediaUrl('/media/trips/cover.jpg'),
      'http://127.0.0.1:8000/media/trips/cover.jpg',
    );
    expect(
      TripsService.resolveMediaUrl('https://cdn.example.test/cover.jpg'),
      'https://cdn.example.test/cover.jpg',
    );
    expect(TripsService.resolveMediaUrl(null), isNull);
  });

  test('retries once after refreshing an expired access token', () async {
    final auth = _FakeAuthService();
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        expect(request.headers['Authorization'], 'Bearer access-token');
        return http.Response('{"detail":"expired"}', 401);
      }
      expect(request.headers['Authorization'], 'Bearer refreshed-token');
      return http.Response(jsonEncode([_tripJson()]), 200);
    });
    final service = TripsService(authService: auth, client: client);

    await service.getTrips();

    expect(requestCount, 2);
    expect(auth.refreshCalls, 1);
  });

  test(
    'does not repeat create after an ambiguous connection failure',
    () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount++;
        throw const SocketException('connection lost after send');
      });
      final service = TripsService(
        authService: _FakeAuthService(),
        client: client,
      );

      await expectLater(
        service.createTrip(
          name: 'Lisboa',
          destination: 'Portugal',
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 15),
        ),
        throwsA(isA<TripsServiceException>()),
      );
      expect(requestCount, 1);
    },
  );

  test('uses the API detail for validation errors', () async {
    final client = MockClient(
      (_) async => http.Response('{"detail":"Dados inválidos."}', 400),
    );
    final service = TripsService(
      authService: _FakeAuthService(),
      client: client,
    );

    await expectLater(
      service.getTrips(),
      throwsA(
        isA<TripsServiceException>().having(
          (error) => error.message,
          'message',
          'Dados inválidos.',
        ),
      ),
    );
  });

  test('turns connection failures into a Portuguese service error', () async {
    final client = MockClient(
      (_) async => throw const SocketException('offline'),
    );
    final service = TripsService(
      authService: _FakeAuthService(),
      client: client,
    );

    await expectLater(
      service.getTrips(),
      throwsA(isA<TripsServiceException>()),
    );
  });
}

Map<String, dynamic> _tripJson() => {
  'id': 17,
  'name': 'Lisboa em grupo',
  'destination': 'Lisboa, Portugal',
  'start_date': '2026-08-10',
  'end_date': '2026-08-15',
  'description': '',
  'created_at': '2026-06-01T10:00:00Z',
  'created_by': 4,
  'accepted_participants_count': 3,
  'can_delete': true,
  'cover_image_url': '/media/capa.jpg',
  'accepted_participants': [
    {
      'id': 12,
      'name': 'Amiga aceita',
      'avatar_url': 'https://example.test/avatar.jpg',
    },
  ],
  'pending_invites': [
    {'id': 13, 'name': 'Pendente'},
  ],
  'rejected_invitees': [
    {'id': 14, 'name': 'Recusou convite'},
  ],
};

class _FakeAuthService extends AuthService {
  String _accessToken = 'access-token';
  int refreshCalls = 0;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<bool> refreshSession() async {
    refreshCalls++;
    _accessToken = 'refreshed-token';
    return true;
  }
}
