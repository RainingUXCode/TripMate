import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/screens/invite_friends_screen.dart';
import 'package:tripmate/screens/trip_invitation_screen.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/services/friends_service.dart';
import 'package:tripmate/services/trips_service.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('aceita convite, atualiza estado e só oferece detalhes depois', (
    tester,
  ) async {
    final service = _FakeTripsService([_invitation()]);
    var changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TripInvitationsScreen(
          tripsService: service,
          onChanged: () async => changed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Viagem privada'), findsOneWidget);
    expect(find.text('Descrição secreta'), findsNothing);
    expect(service.getTripCalls, 0);
    await tester.tap(find.text('Aceitar'));
    await tester.pumpAndSettle();
    expect(service.acceptCalls, 1);
    expect(service.getTripCalls, 0);
    expect(find.text('Convite aceito'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(changed, 1);
    expect(find.text('Nenhum convite pendente'), findsOneWidget);
    expect(service.getTripCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recusa exige confirmação antes da operação', (tester) async {
    final service = _FakeTripsService([_invitation()]);
    await tester.pumpWidget(
      MaterialApp(home: TripInvitationsScreen(tripsService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recusar'));
    await tester.pumpAndSettle();
    expect(service.rejectCalls, 0);
    expect(find.text('Recusar convite?'), findsOneWidget);
    await tester.tap(find.text('Recusar').last);
    await tester.pumpAndSettle();

    expect(service.rejectCalls, 1);
    expect(find.text('Nenhum convite pendente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('só consulta os detalhes privados ao abrir após aceitar', (
    tester,
  ) async {
    final service = _FakeTripsService([_invitation()]);
    await tester.pumpWidget(
      MaterialApp(
        home: TripInvitationsScreen(
          tripsService: service,
          authService: _FakeInvitationAuthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.getTripCalls, 0);

    await tester.tap(find.text('Aceitar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir viagem'));
    await tester.pumpAndSettle();

    expect(service.getTripCalls, 1);
    expect(find.text('VIAGEM EM GRUPO · 10 – 12 AGO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('protege contra duas submissões simultâneas', (tester) async {
    final response = Completer<Map<String, dynamic>>();
    final service = _FakeTripsService([_invitation()])
      ..acceptResponse = response;
    await tester.pumpWidget(
      MaterialApp(home: TripInvitationsScreen(tripsService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aceitar'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trip-invitation-accept-17')));
    await tester.pump();
    expect(service.acceptCalls, 1);

    response.complete({'status': 'accepted'});
    await tester.pumpAndSettle();
    expect(find.text('Convite aceito'), findsOneWidget);
  });

  testWidgets('falha ambígua exige consulta bem-sucedida antes de repetir', (
    tester,
  ) async {
    final service = _FakeTripsService(
      [_invitation()],
    )..nextResponseError = const TripsServiceException('Conexão interrompida.');
    await tester.pumpWidget(
      MaterialApp(home: TripInvitationsScreen(tripsService: service)),
    );
    await tester.pumpAndSettle();
    service.nextInvitationError = const TripsServiceException(
      'Servidor indisponível.',
    );
    await tester.tap(find.text('Aceitar'));
    await tester.pumpAndSettle();

    expect(service.acceptCalls, 1);
    expect(service.getInvitationCalls, 2);
    await tester.tap(find.byKey(const ValueKey('trip-invitation-accept-17')));
    await tester.pump();
    expect(service.acceptCalls, 1);

    await tester.tap(find.text('Tentar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceitar'));
    await tester.pumpAndSettle();
    expect(service.acceptCalls, 2);
    expect(find.text('Convite aceito'), findsOneWidget);
  });

  testWidgets(
    'remove convite já respondido pelo servidor após consultar lista',
    (tester) async {
      final service = _FakeTripsService([_invitation()])
        ..nextResponseError = const TripsServiceException(
          'Not found.',
          statusCode: 404,
        );
      await tester.pumpWidget(
        MaterialApp(home: TripInvitationsScreen(tripsService: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceitar'));
      await tester.pumpAndSettle();

      expect(service.getInvitationCalls, 2);
      expect(find.text('Nenhum convite pendente'), findsOneWidget);
      expect(
        find.text(
          'Este convite já foi respondido ou não está mais disponível.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'regressão A71: mapeia IDs de amizade para usuários e filtra memberships',
    (tester) async {
      final trip = _trip(
        rejectedInvitees: const [TripParticipant(id: 5, name: 'Recusou')],
      );
      final service = _FakeTripsService([])..remoteTrip = trip;
      final friends = _FakeFriendsService([
        _friendship(1, 1, 'Organizador'),
        _friendship(2, 2, 'Aceita'),
        _friendship(3, 3, 'Pendente'),
        _friendship(20, 4, 'Elegível'),
        _friendship(21, 5, 'Recusou'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: InviteFriendsScreen(
            trip: trip,
            tripsService: service,
            friendsService: friends,
            authService: _FakeInvitationAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Organizador'), findsNothing);
      expect(find.text('Aceita'), findsNothing);
      expect(find.text('Pendente'), findsNothing);
      expect(find.text('Recusou'), findsNothing);
      expect(find.text('Elegível'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-friend-20')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('invite-friend-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar convite (1)'));
      await tester.pumpAndSettle();

      expect(service.invitedIds, [4]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vários amigos elegíveis enviam seus IDs de usuário reais', (
    tester,
  ) async {
    final trip = _trip();
    final service = _FakeTripsService([])..remoteTrip = trip;
    final friends = _FakeFriendsService([
      _friendship(70, 7, 'Marina'),
      _friendship(80, 8, 'Lucas', friendIsSender: true),
      _friendship(90, 9, 'Não confirmada', status: 'pending'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: InviteFriendsScreen(
          trip: trip,
          tripsService: service,
          friendsService: friends,
          authService: _FakeInvitationAuthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marina'), findsOneWidget);
    expect(find.text('Lucas'), findsOneWidget);
    expect(find.text('Não confirmada'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invite-friend-7')));
    await tester.tap(find.byKey(const ValueKey('invite-friend-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar convites (2)'));
    await tester.pumpAndSettle();

    expect(service.invitedIds, [7, 8]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('amigo que saiu da viagem pode receber novo convite', (
    tester,
  ) async {
    final trip = _trip();
    final friends = _FakeFriendsService([_friendship(60, 6, 'Saiu da viagem')]);
    await tester.pumpWidget(
      MaterialApp(
        home: InviteFriendsScreen(
          trip: trip,
          tripsService: _FakeTripsService([])..remoteTrip = trip,
          friendsService: friends,
          authService: _FakeInvitationAuthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saiu da viagem'), findsOneWidget);
    expect(find.byKey(const ValueKey('invite-friend-6')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distingue ausência de amigos de todos já vinculados', (
    tester,
  ) async {
    final trip = _trip(
      rejectedInvitees: const [TripParticipant(id: 5, name: 'Recusou')],
    );
    final service = _FakeTripsService([])..remoteTrip = trip;
    await tester.pumpWidget(
      MaterialApp(
        home: InviteFriendsScreen(
          trip: trip,
          tripsService: service,
          friendsService: _FakeFriendsService(const []),
          authService: _FakeInvitationAuthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Você ainda não possui amigos para convidar.'),
      findsOneWidget,
    );

    final blockedFriends = _FakeFriendsService([
      _friendship(2, 2, 'Aceita'),
      _friendship(3, 3, 'Pendente'),
      _friendship(5, 5, 'Recusou'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: InviteFriendsScreen(
          key: const ValueKey('blocked-invite-friends'),
          trip: trip,
          tripsService: service,
          friendsService: blockedFriends,
          authService: _FakeInvitationAuthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Seus amigos restantes recusaram convites anteriores e não podem ser convidados novamente.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falha ao carregar amizades exibe erro e permite tentar novamente',
    (tester) async {
      final service = _FakeTripsService([]);
      final friends = _FakeFriendsService(const [])
        ..error = Exception('Sem conexão.');
      await tester.pumpWidget(
        MaterialApp(
          home: InviteFriendsScreen(
            trip: _trip(),
            tripsService: service,
            friendsService: friends,
            authService: _FakeInvitationAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão.'), findsOneWidget);
      expect(
        find.text('Você ainda não possui amigos para convidar.'),
        findsNothing,
      );

      friends.error = null;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(
        find.text('Você ainda não possui amigos para convidar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('não reaproveita a conta anterior se o usuário mudar', (
    tester,
  ) async {
    final friends = _FakeFriendsService([_friendship(40, 40, 'Conta antiga')]);
    await tester.pumpWidget(
      MaterialApp(
        home: InviteFriendsScreen(
          trip: _trip(),
          tripsService: _FakeTripsService([]),
          friendsService: friends,
          authService: _FakeInvitationAuthService(userId: 99),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Somente o organizador atual pode convidar amigos para esta viagem.',
      ),
      findsOneWidget,
    );
    expect(find.text('Conta antiga'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reconsulta a viagem após falha ambígua ao enviar convites', (
    tester,
  ) async {
    final service = _FakeTripsService([])
      ..inviteError = const TripsServiceException('Conexão interrompida.');
    final friends = _FakeFriendsService([_friendship(40, 4, 'Elegível')]);
    await tester.pumpWidget(
      MaterialApp(
        home: InviteFriendsScreen(
          trip: _trip(),
          tripsService: service,
          friendsService: friends,
          authService: _FakeInvitationAuthService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-friend-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar convite (1)'));
    await tester.pumpAndSettle();

    expect(service.inviteCalls, 1);
    expect(service.getTripCalls, 2);
    expect(find.text('Elegível'), findsNothing);
    expect(
      find.text(
        'Todos os seus amigos já participam ou têm um convite pendente.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'convite com textos longos cabe em tela estreita e escala maior',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final invitation = TripInvitation(
        tripId: 17,
        name: 'Viagem de férias com toda a família e amigos próximos',
        destination: 'Uma região costeira muito extensa no sul do Brasil',
        startDate: DateTime(2026, 8, 10),
        endDate: DateTime(2026, 8, 12),
        organizer: const TripParticipant(
          id: 2,
          name: 'Marina organizadora do grande passeio',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: TripInvitationsScreen(
            tripsService: _FakeTripsService([invitation]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aceitar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

TripInvitation _invitation() => TripInvitation(
  tripId: 17,
  name: 'Viagem privada',
  destination: 'Paraty, Brasil',
  startDate: DateTime(2026, 8, 10),
  endDate: DateTime(2026, 8, 12),
  organizer: const TripParticipant(id: 2, name: 'Marina'),
);

Trip _trip({List<TripParticipant> rejectedInvitees = const []}) => Trip(
  id: 17,
  name: 'Viagem privada',
  destination: 'Paraty, Brasil',
  startDate: DateTime(2026, 8, 10),
  endDate: DateTime(2026, 8, 12),
  description: '',
  createdAt: DateTime(2026, 6, 1),
  organizerId: 1,
  acceptedParticipantsCount: 2,
  acceptedParticipants: const [
    TripParticipant(id: 1, name: 'Organizador'),
    TripParticipant(id: 2, name: 'Aceita'),
  ],
  pendingInvites: const [TripParticipant(id: 3, name: 'Pendente')],
  rejectedInvitees: rejectedInvitees,
);

Map<String, dynamic> _friendship(
  int friendshipId,
  int friendId,
  String name, {
  bool friendIsSender = false,
  String status = 'accepted',
}) {
  final owner = {'id': 1, 'name': 'Organizador'};
  final friend = {'id': friendId, 'name': name};
  return {
    'id': friendshipId,
    'status': status,
    'sender': friendIsSender ? friend : owner,
    'receiver': friendIsSender ? owner : friend,
  };
}

class _FakeTripsService extends TripsService {
  _FakeTripsService(this.invitations);

  List<TripInvitation> invitations;
  int getTripCalls = 0;
  int getInvitationCalls = 0;
  int acceptCalls = 0;
  int rejectCalls = 0;
  Completer<Map<String, dynamic>>? acceptResponse;
  Object? nextResponseError;
  Object? nextInvitationError;
  List<int>? invitedIds;
  int inviteCalls = 0;
  Object? inviteError;
  Trip remoteTrip = _trip();

  @override
  Future<List<TripInvitation>> getInvitations() async {
    getInvitationCalls++;
    final error = nextInvitationError;
    if (error != null) {
      nextInvitationError = null;
      throw error;
    }
    return invitations;
  }

  @override
  Future<Map<String, dynamic>> respondToInvitation(
    int tripId, {
    required bool accept,
  }) async {
    if (accept) {
      acceptCalls++;
      final error = nextResponseError;
      if (error != null) {
        nextResponseError = null;
        if (error is TripsServiceException && error.statusCode == 404) {
          invitations = const [];
        }
        throw error;
      }
      return acceptResponse?.future ??
          {'trip_id': tripId, 'status': 'accepted'};
    }
    rejectCalls++;
    invitations = const [];
    return {'trip_id': tripId, 'status': 'rejected'};
  }

  @override
  Future<Trip> inviteUsers(int tripId, List<int> userIds) async {
    inviteCalls++;
    invitedIds = userIds;
    final error = inviteError;
    if (error != null) {
      inviteError = null;
      remoteTrip = Trip(
        id: _trip().id,
        name: _trip().name,
        destination: _trip().destination,
        startDate: _trip().startDate,
        endDate: _trip().endDate,
        description: '',
        createdAt: _trip().createdAt,
        organizerId: 1,
        acceptedParticipantsCount: 2,
        acceptedParticipants: _trip().acceptedParticipants,
        pendingInvites: const [TripParticipant(id: 4, name: 'Elegível')],
      );
      throw error;
    }
    return remoteTrip;
  }

  @override
  Future<Trip> getTrip(int tripId) async {
    getTripCalls++;
    return remoteTrip;
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
}

class _FakeFriendsService extends FriendsService {
  _FakeFriendsService(this.friends);
  final List<Map<String, dynamic>> friends;
  Object? error;

  @override
  Future<List<Map<String, dynamic>>> getFriends() async {
    final currentError = error;
    if (currentError != null) throw currentError;
    return friends;
  }
}

class _FakeInvitationAuthService extends AuthService {
  _FakeInvitationAuthService({this.userId = 1});

  final int userId;

  @override
  Future<Map<String, dynamic>?> getSavedUser() async => {
    'id': userId,
    'name': 'Lucas',
  };
}
