import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/screens/authenticated_shell.dart';
import 'package:tripmate/screens/profile_screen.dart';
import 'package:tripmate/services/friends_service.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/services/trips_service.dart';

void main() {
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('exibe zero quando não há amizades confirmadas', (tester) async {
    final service = _FakeFriendsService([<Map<String, dynamic>>[]]);
    await tester.pumpWidget(_profile(service));
    await tester.pumpAndSettle();

    _expectFriendCount(tester, '0');
  });

  testWidgets('conta amigos confirmados e ignora solicitações pendentes', (
    tester,
  ) async {
    final service = _FakeFriendsService([_confirmedFriends(2)])
      ..pendingRequests = 3;

    await tester.pumpWidget(_profile(service));
    await tester.pumpAndSettle();

    _expectFriendCount(tester, '2');
    expect(service.getRequestsCalls, 0);
  });

  testWidgets('atualiza a contagem ao reativar a aba Perfil', (tester) async {
    final service = _FakeFriendsService([
      <Map<String, dynamic>>[],
      _confirmedFriends(2),
    ]);
    await tester.pumpWidget(_shell(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    _expectFriendCount(tester, '0');

    await tester.tap(find.text('Início').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    _expectFriendCount(tester, '2');
    expect(service.getFriendsCalls, 2);
  });

  testWidgets('falha inicial mostra marcador neutro sem bloquear o Perfil', (
    tester,
  ) async {
    final service = _FakeFriendsService([Exception('API indisponível')]);
    await tester.pumpWidget(_profile(service));
    await tester.pumpAndSettle();

    _expectFriendCount(tester, '—');
    expect(find.text('Dados cadastrais'), findsOneWidget);
  });

  testWidgets('falha posterior preserva a última contagem válida', (
    tester,
  ) async {
    final service = _FakeFriendsService([
      _confirmedFriends(2),
      Exception('API indisponível'),
    ]);
    await tester.pumpWidget(_shell(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    _expectFriendCount(tester, '2');

    await tester.tap(find.text('Início').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();

    _expectFriendCount(tester, '2');
  });
}

Widget _profile(FriendsService service) {
  return MaterialApp(
    home: ProfileScreen(
      showBottomNavigation: false,
      friendsService: service,
      tripsService: _FakeTripsService(),
      authService: _FakeAuthService(),
    ),
  );
}

Widget _shell(FriendsService service) {
  return MaterialApp(
    home: AuthenticatedShell(
      friendsService: service,
      tripsService: _FakeTripsService(),
      authService: _FakeAuthService(),
    ),
  );
}

List<Map<String, dynamic>> _confirmedFriends(int count) => [
  for (var index = 0; index < count; index++)
    {'id': index + 1, 'status': 'accepted'},
];

void _expectFriendCount(WidgetTester tester, String expected) {
  final statColumn = find
      .ancestor(of: find.text('Amigos'), matching: find.byType(Column))
      .first;
  expect(
    find.descendant(of: statColumn, matching: find.text(expected)),
    findsOneWidget,
  );
}

class _FakeFriendsService extends FriendsService {
  _FakeFriendsService(Iterable<Object> results)
    : _results = Queue<Object>.of(results);

  final Queue<Object> _results;
  int getFriendsCalls = 0;
  int getRequestsCalls = 0;
  int pendingRequests = 0;

  @override
  Future<List<Map<String, dynamic>>> getFriends() async {
    getFriendsCalls++;
    final result = _results.removeFirst();
    if (result is Exception) throw result;
    return result as List<Map<String, dynamic>>;
  }

  @override
  Future<Map<String, dynamic>> getRequests() async {
    getRequestsCalls++;
    return {
      'received': List.filled(pendingRequests, <String, dynamic>{}),
      'sent': <Map<String, dynamic>>[],
    };
  }
}

class _FakeTripsService extends TripsService {
  @override
  Future<List<Trip>> getTrips() async => const [];
}

class _FakeAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>?> getSavedUser() async => {
    'id': 7,
    'name': 'Teste',
  };

  @override
  Future<Map<String, dynamic>> getCurrentUser() async => {
    'id': 7,
    'name': 'Teste',
  };
}
