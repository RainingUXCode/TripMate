import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/screens/all_trips_screen.dart';
import 'package:tripmate/screens/authenticated_shell.dart';
import 'package:tripmate/screens/home_screen.dart';
import 'package:tripmate/screens/profile_screen.dart';
import 'package:tripmate/screens/trip_details_screen.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/services/friends_service.dart';
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

  testWidgets(
    'Home mostra no máximo duas viagens reais e Ver todas lista todas',
    (tester) async {
      final trips = [_trip(3), _trip(2), _trip(1)];
      final service = _FakeTripsService(trips);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthenticatedShell(
            tripsService: service,
            authService: _FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-card-1')), findsNothing);
      expect(find.text('R\$ 2.680,00'), findsNothing);
      expect(find.text('R\$ 4.120,00'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('all-trips-button')));
      await tester.pumpAndSettle();
      expect(find.byType(AllTripsScreen), findsOneWidget);
      for (final trip in trips) {
        expect(find.byKey(ValueKey('trip-card-${trip.id}')), findsOneWidget);
      }

      await tester.tap(find.byKey(const ValueKey('trip-card-2')));
      await tester.pumpAndSettle();
      final details = tester.widget<TripDetailsScreen>(
        find.byType(TripDetailsScreen),
      );
      expect(details.tripId, 2);
    },
  );

  testWidgets('Perfil mostra — sem dados e atualiza a contagem real', (
    tester,
  ) async {
    final service = _FakeTripsService([_trip(1), _trip(2)]);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          tripsService: service,
          authService: _FakeAuthService(),
          friendsService: _FakeFriendsService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tripsStat = find
        .ancestor(of: find.text('Viagens'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: tripsStat, matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('Perfil preserva contagem em erro e limpa ao trocar de conta', (
    tester,
  ) async {
    final auth = _MutableAuthService();
    final service = _SequencedTripsService([
      [_trip(1), _trip(2)],
      Exception('API indisponível'),
    ]);

    Widget profile(int activationVersion) => MaterialApp(
      home: ProfileScreen(
        authService: auth,
        tripsService: service,
        friendsService: _FakeFriendsService(),
        activationVersion: activationVersion,
      ),
    );

    await tester.pumpWidget(profile(0));
    await tester.pumpAndSettle();
    _expectTripCount(tester, '2');

    auth.userId = 8;
    await tester.pumpWidget(profile(1));
    await tester.pumpAndSettle();
    _expectTripCount(tester, '—');
  });
}

void _expectTripCount(WidgetTester tester, String expected) {
  final tripsStat = find
      .ancestor(of: find.text('Viagens'), matching: find.byType(Column))
      .first;
  expect(
    find.descendant(of: tripsStat, matching: find.text(expected)),
    findsOneWidget,
  );
}

Trip _trip(int id) => Trip(
  id: id,
  name: 'Viagem $id',
  destination: 'Destino $id',
  startDate: DateTime(2026, 12, 10),
  endDate: DateTime(2026, 12, 15),
  description: '',
  createdAt: DateTime.utc(2026, 11, id),
  organizerId: 7,
  acceptedParticipantsCount: 1,
);

class _FakeTripsService extends TripsService {
  _FakeTripsService(this.trips);

  final List<Trip> trips;

  @override
  Future<List<Trip>> getTrips() async => trips;

  @override
  Future<Trip> getTrip(int tripId) async =>
      trips.firstWhere((trip) => trip.id == tripId);
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

class _MutableAuthService extends AuthService {
  int userId = 7;

  @override
  Future<Map<String, dynamic>?> getSavedUser() async => {
    'id': userId,
    'name': 'Teste',
  };

  @override
  Future<Map<String, dynamic>> getCurrentUser() async => {
    'id': userId,
    'name': 'Teste',
  };
}

class _SequencedTripsService extends TripsService {
  _SequencedTripsService(this._results);

  final List<Object> _results;

  @override
  Future<List<Trip>> getTrips() async {
    final result = _results.removeAt(0);
    if (result is Exception) throw result;
    return result as List<Trip>;
  }
}

class _FakeFriendsService extends FriendsService {
  @override
  Future<List<Map<String, dynamic>>> getFriends() async => const [];
}
