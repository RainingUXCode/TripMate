import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/screens/trip_details_screen.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/services/friends_service.dart';
import 'package:tripmate/services/trips_service.dart';
import 'package:tripmate/widgets/user_avatar.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('exibe capa, dados e apenas participantes aceitos', (
    tester,
  ) async {
    final trip = _trip(
      coverImageUrl: 'https://media.example.test/trip.jpg',
      participants: _participants(),
    );
    final service = _FakeTripsService([trip]);
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(tripId: trip.id, tripsService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('trip-details-hero-image')),
      findsOneWidget,
    );
    expect(find.text('VIAGEM EM GRUPO · 10 – 15 MAI'), findsOneWidget);
    expect(find.text('Rio com os amigos'), findsOneWidget);
    expect(find.text('Rio de Janeiro, Brasil'), findsOneWidget);
    expect(find.text('4 participantes'), findsOneWidget);
    expect(find.text('Participantes'), findsOneWidget);
    expect(find.text('Marina'), findsOneWidget);
    expect(find.text('Organizador'), findsOneWidget);
    expect(find.text('Lucas'), findsOneWidget);
    expect(find.text('R\$ 0,00'), findsOneWidget);
    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(service.requestedIds, [trip.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('usa placeholder e apresenta estado real sem participantes', (
    tester,
  ) async {
    final trip = _trip(participants: const []);
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          key: const ValueKey('organizer'),
          tripId: trip.id,
          tripsService: _FakeTripsService([trip]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
    expect(find.text('0 participantes'), findsOneWidget);
    expect(find.text('Nenhum participante confirmado ainda.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orçamento e avatares do hero não são cortados', (tester) async {
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService(
      [trip],
      financeSummary: {
        'budget_amount': null,
        'total_spent': '123456789.00',
        'remaining_budget': null,
        'consumed_percent': null,
        'expense_count': 1,
        'participants': const [],
        'proposals': const [],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            textScaler: TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: service,
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = find.byKey(
      const ValueKey('trip-details-hero-participant-4'),
    );
    final avatarStack = find.ancestor(
      of: avatar,
      matching: find.byWidgetPredicate(
        (widget) => widget is Stack && widget.children.length == 4,
      ),
    );
    final avatarBounds = tester.getRect(avatar);
    final stackBounds = tester.getRect(avatarStack.first);
    expect(avatarBounds.width, 26);
    expect(avatarBounds.height, 26);
    expect(avatarBounds.right, lessThanOrEqualTo(stackBounds.right));
    expect(find.text('Despesas registradas'), findsOneWidget);
    expect(find.text('0 gastos'), findsOneWidget);
    expect(find.text('Gasto total do grupo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card do grupo mostra total e conta apenas despesas ativas', (
    tester,
  ) async {
    final scenarios = [
      (
        expenses: <Map<String, dynamic>>[],
        total: '0.00',
        displayTotal: 'R\$ 0,00',
        expected: '0 gastos',
      ),
      (
        expenses: <Map<String, dynamic>>[
          {'cancelled': false},
        ],
        total: '50.00',
        displayTotal: 'R\$ 50,00',
        expected: '1 gasto',
      ),
      (
        expenses: <Map<String, dynamic>>[
          {'cancelled': false},
          {'cancelled': true},
          {'cancelled': false},
        ],
        total: '125.75',
        displayTotal: 'R\$ 125,75',
        expected: '2 gastos',
      ),
    ];

    for (var index = 0; index < scenarios.length; index++) {
      final scenario = scenarios[index];
      final trip = _trip(participants: _participants());
      final service = _FakeTripsService(
        [trip],
        expenses: scenario.expenses,
        financeSummary: {
          'budget_amount': null,
          'total_spent': scenario.total,
          'remaining_budget': null,
          'consumed_percent': null,
          'expense_count': scenario.expenses.length,
          'participants': const [],
          'proposals': const [],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailsScreen(
            key: ValueKey('expense-count-$index'),
            tripId: trip.id,
            tripsService: service,
            authService: _FakeScreenAuthService(1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('group-expense-card')),
      );

      expect(find.text('Gasto total do grupo'), findsOneWidget);
      expect(find.text(scenario.displayTotal), findsOneWidget);
      expect(
        find.byKey(const ValueKey('finance-active-expense-count')),
        findsOneWidget,
      );
      expect(find.text(scenario.expected), findsOneWidget);
      final countBounds = tester.getRect(
        find.byKey(const ValueKey('finance-active-expense-count')),
      );
      final iconBounds = tester.getRect(
        find.byIcon(Icons.receipt_long_outlined),
      );
      final labelBounds = tester.getRect(find.text('Despesas registradas'));
      final cardBounds = tester.getRect(
        find.byKey(const ValueKey('group-expense-card')),
      );
      expect(labelBounds.left, closeTo(iconBounds.right + 8, 1));
      expect(countBounds.right, greaterThanOrEqualTo(cardBounds.right - 24));
      expect(
        find.byKey(const ValueKey('finance-budget-progress')),
        findsNothing,
      );
      expect(find.text('Definir orçamento'), findsNothing);
      expect(find.textContaining('% de'), findsNothing);
      expect(find.textContaining('/ pessoa'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('card não inventa contagem enquanto a lista está indisponível', (
    tester,
  ) async {
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService(
      [trip],
      financeSummary: {
        'budget_amount': null,
        'total_spent': '50.00',
        'remaining_budget': null,
        'consumed_percent': null,
        'expense_count': 1,
        'participants': const [],
        'proposals': const [],
      },
    )..expensesError = const TripsServiceException('Sem conexão.');
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: service,
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsOneWidget);
    expect(find.text('0 gastos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ação de convidar amigos só aparece para o organizador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = _trip(participants: _participants());
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          key: const ValueKey('participant'),
          tripId: trip.id,
          tripsService: _FakeTripsService([trip]),
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('invite-trip-friends')),
    );
    expect(find.text('Convidar amigos'), findsOneWidget);
    final cardBounds = tester.getRect(
      find.byKey(const ValueKey('trip-participants-card')),
    );
    final inviteBounds = tester.getRect(
      find.byKey(const ValueKey('invite-trip-friends')),
    );
    expect(inviteBounds.right, closeTo(cardBounds.right - 17, 2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: _FakeTripsService([trip]),
          authService: _FakeScreenAuthService(2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-trip-friends')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organizador ainda pode abrir convite sem amigos disponíveis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = _trip(participants: _participants());
    final tripsService = _FakeTripsService([trip, trip]);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: tripsService,
          friendsService: _FakeScreenFriendsService(),
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('invite-trip-friends')),
    );

    expect(find.byKey(const ValueKey('invite-trip-friends')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invite-trip-friends')));
    await tester.pumpAndSettle();

    expect(
      find.text('Você ainda não possui amigos para convidar.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contagens e Pago por pessoa incluem somente usuários aceitos', (
    tester,
  ) async {
    final participants = const [
      TripParticipant(id: 1, name: 'Marina Azevedo'),
      TripParticipant(id: 2, name: 'João Lima'),
    ];
    final trip = Trip(
      id: 17,
      name: 'Rio com os amigos',
      destination: 'Rio de Janeiro, Brasil',
      startDate: DateTime(2026, 5, 10),
      endDate: DateTime(2026, 5, 15),
      description: '',
      createdAt: DateTime.utc(2026, 1, 1),
      organizerId: 1,
      // Deliberately inconsistent fixture: the accepted list is the source
      // used for all active participant counts and visuals.
      acceptedParticipantsCount: 1,
      acceptedParticipants: participants,
    );
    final tripWithNewAccepted = Trip(
      id: trip.id,
      name: trip.name,
      destination: trip.destination,
      startDate: trip.startDate,
      endDate: trip.endDate,
      description: trip.description,
      createdAt: trip.createdAt,
      organizerId: trip.organizerId,
      acceptedParticipantsCount: 3,
      acceptedParticipants: [
        ...participants,
        const TripParticipant(id: 3, name: 'Ana Paula'),
      ],
    );
    final financeParticipants = [
      // The finance endpoint also keeps pending, rejected and left members
      // in its balance/history set. Only IDs 1 and 2 are accepted here.
      for (final id in [1, 2, 3, 4, 5])
        {
          'user_id': id,
          'paid': id == 1 ? '45.00' : '0.00',
          'due': id == 1 ? '22.50' : '0.00',
          'gross_balance': id == 1 ? '22.50' : '0.00',
          'sent': '0.00',
          'received': '0.00',
          'balance': id == 1 ? '22.50' : '0.00',
        },
    ];
    final service = _FakeTripsService(
      [trip, tripWithNewAccepted],
      financeSummary: {
        'budget_amount': null,
        'total_spent': '45.00',
        'remaining_budget': null,
        'consumed_percent': null,
        'expense_count': 1,
        'participants': financeParticipants,
        'proposals': const [],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: service,
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 participantes'), findsOneWidget);
    expect(find.text('2 pessoas nesta viagem'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trip-details-hero-participant-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trip-details-hero-participant-2')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-per-person-card')),
    );
    expect(find.byKey(const ValueKey('trip-balance-user-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-balance-user-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-balance-user-3')), findsNothing);
    expect(find.byKey(const ValueKey('trip-balance-user-4')), findsNothing);
    expect(find.byKey(const ValueKey('trip-balance-user-5')), findsNothing);
    final balanceCard = find.byKey(const ValueKey('trip-per-person-card'));
    expect(
      find.descendant(of: balanceCard, matching: find.text('Participante')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          key: const ValueKey('after-acceptance'),
          tripId: trip.id,
          tripsService: _FakeTripsService(
            [tripWithNewAccepted],
            financeSummary: {
              'budget_amount': null,
              'total_spent': '45.00',
              'remaining_budget': null,
              'consumed_percent': null,
              'expense_count': 1,
              'participants': [
                ...financeParticipants,
                {
                  'user_id': 6,
                  'paid': '0.00',
                  'due': '0.00',
                  'gross_balance': '0.00',
                  'sent': '0.00',
                  'received': '0.00',
                  'balance': '0.00',
                },
              ],
              'proposals': const [],
            },
          ),
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 participantes'), findsOneWidget);
    expect(find.text('3 pessoas nesta viagem'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-per-person-card')),
    );
    expect(find.byKey(const ValueKey('trip-balance-user-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mostra bloqueio financeiro retornado pelo backend sem tentar sair',
    (tester) async {
      final trip = _trip(participants: _participants());
      final service = _FakeTripsService([trip])
        ..leaveEligibility = {
          'can_leave': false,
          'reasons': ['outstanding_debt', 'pending_settlement'],
          'reason_messages': {
            'outstanding_debt':
                'Você ainda possui valores a pagar nesta viagem.',
            'pending_settlement': 'Existe um acerto aguardando confirmação.',
          },
        };
      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailsScreen(
            tripId: trip.id,
            tripsService: service,
            authService: _FakeScreenAuthService(2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openManagement(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('management-leave-trip')),
      );
      await tester.tap(find.byKey(const ValueKey('management-leave-trip')));
      await tester.pumpAndSettle();

      expect(service.eligibilityCalls, 1);
      expect(service.leaveCalls, 0);
      expect(find.text('Você ainda não pode sair'), findsOneWidget);
      expect(find.textContaining('valores a pagar'), findsOneWidget);
      expect(
        find.textContaining('acerto aguardando confirmação'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sai após confirmar, atualiza listas e retorna à Home', (
    tester,
  ) async {
    var refreshed = 0;
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService([trip]);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TripDetailsScreen(
                      tripId: trip.id,
                      tripsService: service,
                      authService: _FakeScreenAuthService(2),
                      onTripChanged: () async => refreshed++,
                    ),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await _openManagement(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('management-leave-trip')),
    );
    await tester.tap(find.byKey(const ValueKey('management-leave-trip')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Sair da viagem?'), findsOneWidget);
    await tester.tap(find.text('Sair da viagem').last);
    await tester.pumpAndSettle();

    expect(service.leaveCalls, 1);
    expect(refreshed, 1);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Rio com os amigos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'transferência atualiza o organizador sem retirar o antigo membro',
    (tester) async {
      final trip = _trip(participants: _participants());
      final successor = Trip(
        id: trip.id,
        name: trip.name,
        destination: trip.destination,
        startDate: trip.startDate,
        endDate: trip.endDate,
        description: trip.description,
        createdAt: trip.createdAt,
        organizerId: 2,
        acceptedParticipantsCount: trip.acceptedParticipantsCount,
        acceptedParticipants: trip.acceptedParticipants,
      );
      var refreshed = 0;
      final service = _FakeTripsService([trip])..transferResult = successor;
      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailsScreen(
            tripId: trip.id,
            tripsService: service,
            authService: _FakeScreenAuthService(1),
            onTripChanged: () async => refreshed++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await _openManagement(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('management-transfer-organizer')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(
        find.byKey(const ValueKey('management-transfer-organizer')),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byKey(const ValueKey('organizer-successor-2')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Confirmar transferência?'), findsOneWidget);
      await tester.tap(find.text('Transferir').last);
      await tester.pumpAndSettle();

      expect(service.transferCalls, 1);
      expect(service.transferTarget, 2);
      expect(refreshed, 1);
      expect(find.text('Gerenciar viagem'), findsNothing);
      await _openManagement(tester);
      expect(
        find.byKey(const ValueKey('management-transfer-organizer')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('management-invite-friends')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('management-delete-trip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('management-leave-trip')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('trip-management-back')));
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remoção de participante exige confirmação e preserva a tela', (
    tester,
  ) async {
    final trip = _trip(participants: _participants());
    final updated = _trip(
      participants: const [
        TripParticipant(id: 1, name: 'Marina Azevedo'),
        TripParticipant(id: 3, name: 'Ana Paula'),
        TripParticipant(id: 4, name: 'Lucas Reis'),
      ],
    );
    final service = _FakeTripsService([trip, updated]);
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: service,
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openManagement(tester);
    await tester.tap(find.byKey(const ValueKey('management-remove-2')));
    await tester.pumpAndSettle();

    expect(find.text('Remover participante?'), findsOneWidget);
    expect(find.textContaining('João Lima perderá acesso'), findsOneWidget);
    expect(service.removedParticipantId, isNull);
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(service.removedParticipantId, isNull);

    await tester.tap(find.byKey(const ValueKey('management-remove-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover João Lima'));
    await tester.pumpAndSettle();

    expect(service.removedParticipantId, 2);
    expect(find.text('Rio com os amigos'), findsOneWidget);
    expect(find.text('3 pessoas nesta viagem'), findsOneWidget);
    expect(find.text('Gerenciar viagem'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exclusão exige digitar o nome exato e volta à tela anterior', (
    tester,
  ) async {
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService([trip]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TripDetailsScreen(
                      tripId: trip.id,
                      tripsService: service,
                      authService: _FakeScreenAuthService(1),
                    ),
                  ),
                ),
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await _openManagement(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('management-delete-trip')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('management-delete-trip')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-delete-trip')),
          )
          .onPressed,
      isNull,
    );
    expect(service.deleteCalls, 0);

    await tester.enterText(
      find.byKey(const ValueKey('delete-trip-name-confirmation')),
      'Outra viagem',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-delete-trip')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('delete-trip-name-confirmation')),
      trip.name,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-trip')));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 1);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text(trip.name), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retorno do gerenciamento mantém a aba Gastos selecionada', (
    tester,
  ) async {
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService([trip]);
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: service,
          authService: _FakeScreenAuthService(2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-tab-expenses')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum gasto registrado'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-details-settings')),
    );
    await tester.tap(find.byKey(const ValueKey('trip-details-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Gerenciar viagem'), findsOneWidget);
    expect(find.byKey(const ValueKey('management-leave-trip')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('management-invite-friends')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('management-transfer-organizer')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('management-delete-trip')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('trip-management-back')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum gasto registrado'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-tab-expenses')), findsOneWidget);
    expect(service.requestedIds, [trip.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ações destrutivas usam vermelho apenas nos ícones e hero iguala botões',
    (tester) async {
      final trip = _trip(participants: _participants());
      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailsScreen(
            tripId: trip.id,
            tripsService: _FakeTripsService([trip]),
            authService: _FakeScreenAuthService(1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backButton = find.byKey(const ValueKey('trip-details-back'));
      final settingsButton = find.byKey(
        const ValueKey('trip-details-settings'),
      );
      expect(tester.getSize(backButton), const Size(48, 48));
      expect(tester.getSize(settingsButton), const Size(48, 48));

      final backIcon = tester.widget<Icon>(
        find.descendant(of: backButton, matching: find.byType(Icon)),
      );
      final settingsIcon = tester.widget<Icon>(
        find.descendant(of: settingsButton, matching: find.byType(Icon)),
      );
      expect(backIcon.size, settingsIcon.size);
      expect(backIcon.color, Colors.white);
      expect(settingsIcon.color, Colors.white);
      for (final button in [backButton, settingsButton]) {
        expect(
          find.descendant(of: button, matching: find.byType(BackdropFilter)),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Material>(
                find.descendant(of: button, matching: find.byType(Material)),
              )
              .color,
          Colors.black.withValues(alpha: 0.28),
        );
      }

      await _openManagement(tester);
      await tester.drag(find.byType(ListView).last, const Offset(0, -700));
      await tester.pumpAndSettle();
      final delete = find.byKey(const ValueKey('management-delete-trip'));
      final leave = find.byKey(const ValueKey('management-leave-trip'));
      const profileDanger = Color(0xFFDE3B3D);

      for (final button in [delete, leave]) {
        await tester.ensureVisible(button);
        final icon = tester.widget<Icon>(
          find.descendant(of: button, matching: find.byType(Icon)),
        );
        final label = tester.widget<Text>(
          find.descendant(of: button, matching: find.byType(Text)),
        );
        expect(icon.color, profileDanger);
        expect(label.style?.color, const Color(0xFF191928));
        final iconSurface = tester.widget<Container>(
          find.descendant(of: button, matching: find.byType(Container)).first,
        );
        expect(
          (iconSurface.decoration! as BoxDecoration).color,
          profileDanger.withValues(alpha: 0.10),
        );
      }
      final transfer = find.byKey(
        const ValueKey('management-transfer-organizer'),
      );
      await tester.ensureVisible(transfer);
      final transferIcon = tester.widget<Icon>(
        find.descendant(of: transfer, matching: find.byType(Icon)),
      );
      final transferSurface = tester.widget<Container>(
        find.descendant(of: transfer, matching: find.byType(Container)).first,
      );
      expect(transferIcon.color, const Color(0xFF634CD4));
      expect(
        (transferSurface.decoration! as BoxDecoration).color,
        const Color(0xFFEEEBFF),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'as duas abas alternam sem exibir Roteiro nem recarregar a viagem',
    (tester) async {
      final trip = _trip(participants: _participants());
      final service = _FakeTripsService([trip]);
      await tester.pumpWidget(
        MaterialApp(
          home: TripDetailsScreen(tripId: trip.id, tripsService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visão geral'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('Roteiro'), findsNothing);
      expect(find.byKey(const ValueKey('trip-tab-itinerary')), findsNothing);
      expect(find.byKey(const ValueKey('group-expense-card')), findsOneWidget);
      expect(find.text('Pago por pessoa'), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-management-card')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('trip-tab-expenses')));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum gasto registrado'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('trip-participants-card')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('trip-tab-overview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('group-expense-card')), findsOneWidget);
      expect(find.text('Nenhum gasto registrado'), findsNothing);
      expect(find.textContaining('Roteiro'), findsNothing);
      expect(service.requestedIds, [trip.id]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('abre Acertos a partir de Gastos e retorna sem perder a aba', (
    tester,
  ) async {
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService([trip]);
    await tester.pumpWidget(
      MaterialApp(
        home: TripDetailsScreen(tripId: trip.id, tripsService: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-tab-expenses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-settlements')));
    await tester.pumpAndSettle();
    expect(find.text('Acertos financeiros'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum gasto registrado'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-settlements')), findsOneWidget);
    expect(service.requestedIds, [trip.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'novo gasto envia as quatro modalidades sem converter dinheiro para double',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cases = [
        (
          mode: 'equal',
          label: 'Igualmente',
          hint: '',
          values: <String>[],
          expected: <Map<String, dynamic>>[
            {'user_id': 1},
            {'user_id': 2},
          ],
        ),
        (
          mode: 'exact',
          label: 'Valores exatos',
          hint: '0.00',
          values: ['6.25', '3.75'],
          expected: <Map<String, dynamic>>[
            {'user_id': 1, 'value': '6.25'},
            {'user_id': 2, 'value': '3.75'},
          ],
        ),
        (
          mode: 'percent',
          label: 'Porcentagens',
          hint: '%',
          values: ['62.5', '37.5'],
          expected: <Map<String, dynamic>>[
            {'user_id': 1, 'value': '62.5'},
            {'user_id': 2, 'value': '37.5'},
          ],
        ),
        (
          mode: 'units',
          label: 'Por cotas',
          hint: '1',
          values: ['5', '3'],
          expected: <Map<String, dynamic>>[
            {'user_id': 1, 'value': '5'},
            {'user_id': 2, 'value': '3'},
          ],
        ),
      ];
      for (final entry in cases) {
        final trip = _trip(participants: _participants());
        final service = _FakeTripsService([trip]);
        await tester.pumpWidget(
          MaterialApp(
            home: TripDetailsScreen(
              key: ValueKey(entry.mode),
              tripId: trip.id,
              tripsService: service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('trip-tab-expenses')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Adicionar gasto'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), '10.00');
        await tester.enterText(find.byType(TextFormField).at(1), 'Almoço');
        await tester.tap(find.text('Marina').first);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.label).last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(CheckboxListTile).at(0));
        await tester.tap(find.byType(CheckboxListTile).at(0));
        await tester.ensureVisible(find.byType(CheckboxListTile).at(1));
        await tester.tap(find.byType(CheckboxListTile).at(1));
        await tester.pumpAndSettle();
        if (entry.values.isNotEmpty) {
          final shareInputs = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == entry.hint,
          );
          await tester.enterText(shareInputs.at(0), entry.values[0]);
          await tester.enterText(shareInputs.at(1), entry.values[1]);
        }
        await tester.ensureVisible(find.text('Salvar gasto'));
        await tester.tap(find.text('Salvar gasto'));
        await tester.pumpAndSettle();

        expect(service.createdExpense, isNotNull, reason: entry.mode);
        expect(service.createdExpense!['amount'], '10.00');
        expect(service.createdExpense!['mode'], entry.mode);
        expect(service.createdExpense!['shares'], entry.expected);
        expect(service.financeSummaryCalls, 2);
        expect(service.expenseListCalls, 2);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('ações de edição e cancelamento só aparecem para o autor', (
    tester,
  ) async {
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService(
      [trip],
      expenses: [
        {
          'id': 31,
          'description': 'Almoço',
          'amount': '12.30',
          'expense_date': '2026-05-10',
          'paid_by': 1,
          'created_by': 2,
          'version': 7,
          'cancelled': false,
          'mode': 'equal',
          'shares': [],
        },
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: child!,
        ),
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: service,
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-tab-expenses')));
    await tester.pumpAndSettle();
    expect(find.text('Almoço'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Cancelar'), findsNothing);

    final ownerService = _FakeTripsService([trip], expenses: service._expenses)
      ..cancellationError = const TripsServiceException(
        'Há acertos pendentes na viagem.',
      );
    final ownerScreen = TripDetailsScreen(
      key: const ValueKey('owner-screen'),
      tripId: trip.id,
      tripsService: ownerService,
      authService: _FakeScreenAuthService(2),
    );
    await tester.pumpWidget(MaterialApp(home: ownerScreen));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-tab-expenses')));
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(ownerService.cancelledVersion, 7);
    expect(
      find.text('Este gasto está bloqueado por acertos financeiros.'),
      findsOneWidget,
    );
  });

  testWidgets('falha permite tentar novamente e botão voltar retorna', (
    tester,
  ) async {
    final trip = _trip(participants: _participants());
    final service = _FakeTripsService([Exception('offline'), trip]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => TripDetailsScreen(
                      tripId: trip.id,
                      tripsService: service,
                    ),
                  ),
                ),
                child: const Text('Abrir viagem'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir viagem'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível abrir'), findsOneWidget);
    final errorOverlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(errorOverlay.value.statusBarIconBrightness, Brightness.dark);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Rio com os amigos'), findsOneWidget);
    expect(service.requestedIds, [trip.id, trip.id]);

    await tester.tap(find.byKey(const ValueKey('trip-details-back')));
    await tester.pumpAndSettle();
    expect(find.text('Abrir viagem'), findsOneWidget);
  });

  testWidgets('textos extensos e escala ampliada não causam overflow', (
    tester,
  ) async {
    // Galaxy A71: 1080 x 2400 physical pixels at roughly 2.625 DPR.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final trip = _trip(
      name: 'Uma viagem em grupo com um nome bastante longo para caber no topo',
      destination: 'Rio de Janeiro, Brasil, perto da região central',
      participants: const [
        TripParticipant(id: 1, name: 'Marina com sobrenome bastante longo'),
        TripParticipant(id: 2, name: 'João com sobrenome bastante longo'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.35)),
          child: child!,
        ),
        home: TripDetailsScreen(
          tripId: trip.id,
          tripsService: _FakeTripsService([trip]),
          authService: _FakeScreenAuthService(1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(trip.name), findsOneWidget);
    expect(find.byType(UserAvatar), findsAtLeastNWidgets(2));
    expect(find.byKey(const ValueKey('trip-details-settings')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-details-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Gerenciar viagem'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openManagement(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('trip-details-settings')),
  );
  await tester.tap(find.byKey(const ValueKey('trip-details-settings')));
  await tester.pumpAndSettle();
}

Trip _trip({
  String name = 'Rio com os amigos',
  String destination = 'Rio de Janeiro, Brasil',
  String? coverImageUrl,
  required List<TripParticipant> participants,
}) => Trip(
  id: 17,
  name: name,
  destination: destination,
  startDate: DateTime(2026, 5, 10),
  endDate: DateTime(2026, 5, 15),
  description: '',
  createdAt: DateTime.utc(2026, 1, 1),
  organizerId: 1,
  acceptedParticipantsCount: participants.length,
  canDelete: true,
  coverImageUrl: coverImageUrl,
  acceptedParticipants: participants,
);

List<TripParticipant> _participants() => const [
  TripParticipant(id: 1, name: 'Marina Azevedo'),
  TripParticipant(id: 2, name: 'João Lima'),
  TripParticipant(id: 3, name: 'Ana Paula'),
  TripParticipant(id: 4, name: 'Lucas Reis'),
];

class _FakeTripsService extends TripsService {
  _FakeTripsService(
    Iterable<Object> results, {
    List<Map<String, dynamic>>? expenses,
    this.financeSummary,
  }) : _results = Queue<Object>.of(results),
       _expenses = expenses ?? const [];

  final Queue<Object> _results;
  final Map<String, dynamic>? financeSummary;
  final List<Map<String, dynamic>> _expenses;
  Object? expensesError;
  final List<int> requestedIds = [];
  int financeSummaryCalls = 0;
  int expenseListCalls = 0;
  int eligibilityCalls = 0;
  int leaveCalls = 0;
  int transferCalls = 0;
  int? transferTarget;
  int? removedParticipantId;
  int deleteCalls = 0;
  Map<String, dynamic> leaveEligibility = {
    'can_leave': true,
    'reasons': const [],
    'reason_messages': const {},
  };
  Trip? transferResult;
  Object? leaveError;
  Object? transferError;
  Map<String, dynamic>? createdExpense;
  Object? cancellationError;
  int? cancelledVersion;

  @override
  Future<Map<String, dynamic>> getLeaveEligibility(int tripId) async {
    eligibilityCalls++;
    return leaveEligibility;
  }

  @override
  Future<Map<String, dynamic>> leaveTrip(int tripId) async {
    leaveCalls++;
    if (leaveError case final error?) throw error;
    return {'trip_id': tripId, 'status': 'left'};
  }

  @override
  Future<Trip> transferOrganizer(int tripId, int newOrganizerId) async {
    transferCalls++;
    transferTarget = newOrganizerId;
    if (transferError case final error?) throw error;
    if (transferResult case final result?) return result;
    throw StateError('A transfer result must be configured in the test.');
  }

  @override
  Future<Map<String, dynamic>> removeParticipant(int tripId, int userId) async {
    removedParticipantId = userId;
    return {'trip_id': tripId, 'user_id': userId, 'status': 'left'};
  }

  @override
  Future<void> deleteTrip(int tripId) async {
    deleteCalls++;
  }

  @override
  Future<Trip> getTrip(int tripId) async {
    requestedIds.add(tripId);
    final result = _results.removeFirst();
    if (result is Exception) throw result;
    return result as Trip;
  }

  @override
  Future<Map<String, dynamic>> getFinanceSummary(int tripId) async {
    financeSummaryCalls++;
    return financeSummary ??
        {
          'budget_amount': null,
          'total_spent': '0.00',
          'remaining_budget': null,
          'consumed_percent': null,
          'expense_count': 0,
          'participants': const [],
          'proposals': const [],
        };
  }

  @override
  Future<List<Map<String, dynamic>>> getExpenses(int tripId) async {
    expenseListCalls++;
    if (expensesError case final error?) throw error;
    return _expenses;
  }

  @override
  Future<List<Map<String, dynamic>>> getSettlementProposals(int tripId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getSettlements(int tripId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getFinanceHistory(int tripId) async =>
      const [];

  @override
  Future<Map<String, dynamic>> createExpense(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    createdExpense = payload;
    return {'id': 1, ...payload};
  }

  @override
  Future<Map<String, dynamic>> cancelExpense(
    int tripId,
    int expenseId,
    int version,
  ) async {
    cancelledVersion = version;
    if (cancellationError case final error?) throw error;
    return {'id': expenseId, 'version': version + 1, 'cancelled': true};
  }
}

class _FakeScreenAuthService extends AuthService {
  _FakeScreenAuthService(this.userId);
  final int userId;

  @override
  Future<Map<String, dynamic>?> getSavedUser() async => {'id': userId};
}

class _FakeScreenFriendsService extends FriendsService {
  @override
  Future<List<Map<String, dynamic>>> getFriends() async => const [];
}
