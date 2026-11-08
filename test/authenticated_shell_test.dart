import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/screens/authenticated_shell.dart';
import 'package:tripmate/services/trips_service.dart';
import 'package:tripmate/services/notifications_service.dart';
import 'package:tripmate/widgets/tripmate_notification_button.dart';

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

  testWidgets('alternar abas mantém uma única shell e Início volta direto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedShell(
          tripsService: _FakeTripsService(),
          authService: _FakeAuthService(),
          notificationsService: _FakeNotificationsService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Olá,'), findsOneWidget);

    await tester.tap(find.text('Amigos').first);
    await tester.pumpAndSettle();
    expect(find.text('Seus amigos'), findsOneWidget);

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.byType(TripMateNotificationButton), findsOneWidget);
    await tester.tap(find.byType(TripMateNotificationButton));
    await tester.pumpAndSettle();
    expect(find.text('Você está em dia'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Início').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Olá,'), findsOneWidget);
    expect(find.byType(AuthenticatedShell), findsOneWidget);
    expect(find.text('Ver todas'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Ver todas')).style?.fontSize, 14);
    expect(find.text('Você ainda não criou nenhuma viagem.'), findsOneWidget);
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('Olá,'), findsOneWidget);
  });

  testWidgets('o sino recebe a contagem não lida real compartilhada', (
    tester,
  ) async {
    final notifications = _FakeNotificationsService()..unreadCount = 3;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedShell(
          tripsService: _FakeTripsService(),
          authService: _FakeAuthService(),
          notificationsService: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                const Color(0xFFDE3B3D),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Amigos').first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                const Color(0xFFDE3B3D),
      ),
      findsOneWidget,
    );
  });

  testWidgets('eventos de notificação abrem destinos atuais e autorizados', (
    tester,
  ) async {
    Future<void> open(Map<String, dynamic> notification) async {
      final notifications = _FakeNotificationsService()
        ..unreadCount = 1
        ..items = [notification];
      await tester.pumpWidget(
        MaterialApp(
          home: AuthenticatedShell(
            key: ValueKey(notification['event_type']),
            tripsService: _FakeTripsService()
              ..invitations = [
                TripInvitation(
                  tripId: 17,
                  name: 'Convite acessível',
                  destination: 'Paraty',
                  startDate: DateTime(2026, 8, 10),
                  endDate: DateTime(2026, 8, 12),
                  organizer: const TripParticipant(id: 2, name: 'Marina'),
                ),
              ],
            authService: _FakeAuthService(),
            notificationsService: notifications,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TripMateNotificationButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(notification['title'] as String));
      await tester.pumpAndSettle();
    }

    await open(_notice('friend_request', 'Pedido de amizade', 'friendship', 8));
    expect(find.text('Solicitações'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await open(_notice('trip_invitation', 'Convite de viagem', 'trip', 17));
    expect(find.text('Convite acessível'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await open(
      _notice(
        'settlement_pending',
        'Acerto pendente',
        'settlement',
        3,
        contextId: 17,
      ),
    );
    expect(find.text('Sugestões de acerto'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await open(
      _notice('organizer_transferred', 'Organização transferida', 'trip', 17),
    );
    expect(find.text('Viagem aceita'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'aceitar convite atualiza Home e o contador de viagens do Perfil',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _FakeTripsService()
        ..invitations = [
          TripInvitation(
            tripId: 17,
            name: 'Viagem aceita',
            destination: 'Paraty, Brasil',
            startDate: DateTime(2026, 8, 10),
            endDate: DateTime(2026, 8, 12),
            organizer: const TripParticipant(id: 2, name: 'Marina'),
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: AuthenticatedShell(
            tripsService: service,
            authService: _FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trip-invitations-entry')));
      await tester.pumpAndSettle();
      expect(find.text('Viagem aceita'), findsOneWidget);
      expect(service.getTripCalls, 0);
      await tester.tap(find.text('Aceitar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Viagem aceita'), findsOneWidget);
      expect(service.invitations, isEmpty);
      expect(find.text('1'), findsNothing);
      await tester.tap(find.text('Perfil').last);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeTripsService extends TripsService {
  List<Trip> trips = const [];
  List<TripInvitation> invitations = const [];
  int getTripCalls = 0;

  @override
  Future<List<Trip>> getTrips() async => trips;

  @override
  Future<List<TripInvitation>> getInvitations() async => invitations;

  @override
  Future<Map<String, dynamic>> respondToInvitation(
    int tripId, {
    required bool accept,
  }) async {
    invitations = const [];
    if (accept) trips = [_acceptedTrip()];
    return {'trip_id': tripId, 'status': accept ? 'accepted' : 'rejected'};
  }

  @override
  Future<Trip> getTrip(int tripId) async {
    getTripCalls++;
    return _acceptedTrip();
  }

  @override
  Future<Map<String, dynamic>> getFinanceSummary(int tripId) async => const {
    'budget_amount': null,
    'total_spent': '0.00',
    'remaining_budget': null,
    'consumed_percent': null,
    'expense_count': 0,
    'participants': [],
    'proposals': [],
  };

  @override
  Future<List<Map<String, dynamic>>> getExpenses(int tripId) async => const [];

  @override
  Future<List<Map<String, dynamic>>> getSettlementProposals(int tripId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getSettlements(int tripId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getFinanceHistory(int tripId) async =>
      const [];
}

Trip _acceptedTrip() => Trip(
  id: 17,
  name: 'Viagem aceita',
  destination: 'Paraty, Brasil',
  startDate: DateTime(2026, 8, 10),
  endDate: DateTime(2026, 8, 12),
  description: '',
  createdAt: DateTime.utc(2026, 6, 1),
  organizerId: 2,
  acceptedParticipantsCount: 2,
  acceptedParticipants: const [
    TripParticipant(id: 2, name: 'Marina'),
    TripParticipant(id: 1, name: 'Usuário'),
  ],
);

class _FakeAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>?> getSavedUser() async => {
    'id': 1,
    'name': 'Lucas',
  };
}

class _FakeNotificationsService extends NotificationsService {
  _FakeNotificationsService() : super();

  int unreadCount = 0;
  List<Map<String, dynamic>> items = const [];

  @override
  Future<int> getUnreadCount() async => unreadCount;

  @override
  Future<NotificationsPage> getPage({int page = 1}) async =>
      NotificationsPage(results: items, count: items.length, nextPage: null);

  @override
  Future<Map<String, dynamic>> markAsRead(int notificationId) async => {
    'id': notificationId,
    'is_read': true,
  };

  @override
  void close() {}
}

Map<String, dynamic> _notice(
  String eventType,
  String title,
  String resourceType,
  int resourceId, {
  int? contextId,
}) => {
  'id': 1,
  'event_type': eventType,
  'title': title,
  'message': 'Aviso de teste.',
  'resource_type': resourceType,
  'resource_id': resourceId,
  'context_id': contextId,
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'read_at': null,
  'is_read': false,
};
