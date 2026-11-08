import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/screens/home_screen.dart';
import 'package:tripmate/screens/create_trip_screen.dart';
import 'package:tripmate/screens/trip_details_screen.dart';
import 'package:tripmate/services/auth_service.dart';
import 'package:tripmate/services/friends_service.dart';
import 'package:tripmate/services/trips_service.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'campos principais têm ícones alinhados e hierarquia tipográfica',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CreateTripScreen(
            tripsService: _FakeTripsService(),
            friendsService: _FakeFriendsService(),
            authService: _FakeAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedIcons = {
        'trip-name-field': Icons.sell_outlined,
        'trip-destination-field': Icons.location_on_outlined,
        'trip-description-field': Icons.notes_rounded,
      };
      for (final entry in expectedIcons.entries) {
        final field = find.descendant(
          of: find.byKey(ValueKey(entry.key)),
          matching: find.byType(TextField),
        );
        final textField = tester.widget<TextField>(field);
        final prefix = textField.decoration!.prefixIcon! as Padding;
        final icon = prefix.child! as Icon;
        expect(icon.icon, entry.value);
        expect(icon.size, 19);
        expect(icon.color, const Color(0xFF634CD4));
        expect(textField.style!.fontSize, 15);
        expect(textField.decoration!.hintStyle!.fontSize, 14);
      }

      final photoTitle = tester.widget<Text>(find.text('Foto da viagem'));
      final participantsTitle = tester.widget<Text>(find.text('Participantes'));
      expect(photoTitle.style!.fontSize, 16);
      expect(photoTitle.style!.fontWeight, FontWeight.w700);
      expect(participantsTitle.style!.fontSize, photoTitle.style!.fontSize);
      expect(participantsTitle.style!.fontWeight, photoTitle.style!.fontWeight);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('0/150'), findsOneWidget);
      final nameField = find.descendant(
        of: find.byKey(const ValueKey('trip-name-field')),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Férias com amigos');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  test('date validation rejects an end date before the start date', () {
    expect(
      validateTripDateRange(DateTime(2026, 8, 12), DateTime(2026, 8, 11)),
      'A data de término não pode ser anterior à data de início.',
    );
    expect(
      validateTripDateRange(DateTime(2026, 8, 12), DateTime(2026, 8, 12)),
      isNull,
    );
  });

  testWidgets('requires name, destination and dates before saving', (
    tester,
  ) async {
    final service = _FakeTripsService();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateTripScreen(
          tripsService: service,
          friendsService: _FakeFriendsService(),
          authService: _FakeAuthService(),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Criar viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar viagem'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome da viagem.'), findsOneWidget);
    expect(find.text('Informe o destino.'), findsOneWidget);
    expect(find.text('Selecione a data de início.'), findsOneWidget);
    expect(find.text('Selecione a data de término.'), findsOneWidget);
    expect(service.createCalls, 0);
  });

  testWidgets('creates a trip and returns Home through the form route', (
    tester,
  ) async {
    final service = _FakeTripsService();
    final result = Completer<bool?>();
    final friends = _FakeFriendsService();
    final auth = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result.complete(
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => CreateTripScreen(
                          tripsService: service,
                          friendsService: friends,
                          authService: auth,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir formulário'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir formulário'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '  Lisboa  ');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      ' Lisboa, Portugal ',
    );
    await tester.tap(find.byKey(const ValueKey('trip-start-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-end-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar viagem'));
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(service.lastName, '  Lisboa  ');
    expect(service.lastDestination, ' Lisboa, Portugal ');
    expect(await result.future, isTrue);
    expect(service.coverImage, isNull);
    expect(service.inviteeIds, isEmpty);
    expect(find.text('Abrir formulário'), findsOneWidget);
  });

  testWidgets('selects, deselects and submits confirmed friends with a cover', (
    tester,
  ) async {
    final service = _FakeTripsService();
    final friends = _FakeFriendsService(
      relationships: [_friend(2), _friend(3)],
    );
    final auth = _FakeAuthService();
    const onePixelPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    final cover = XFile.fromData(base64Decode(onePixelPng), path: 'trip.png');

    await tester.pumpWidget(
      MaterialApp(
        home: CreateTripScreen(
          tripsService: service,
          friendsService: friends,
          authService: auth,
          selectCoverImage: () async => cover,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('select-trip-cover')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-trip-cover')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-cover-preview')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('trip-friend-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-friend-2')));
    await tester.pumpAndSettle();
    expect(find.text('1 amigo será convidado'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-friend-2')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum amigo selecionado'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-friend-3')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('trip-name-field')),
      'Lisboa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Portugal',
    );
    await _selectDates(tester);
    await tester.ensureVisible(find.text('Criar viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar viagem'));
    await tester.pumpAndSettle();

    expect(service.coverImage?.name, 'trip.png');
    expect(service.inviteeIds, [3]);
  });

  testWidgets('shows a friendly error for unsupported image formats', (
    tester,
  ) async {
    final service = _FakeTripsService();
    await tester.pumpWidget(
      MaterialApp(
        home: CreateTripScreen(
          tripsService: service,
          friendsService: _FakeFriendsService(),
          authService: _FakeAuthService(),
          selectCoverImage: () async =>
              XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'trip.gif'),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('select-trip-cover')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-trip-cover')));
    await tester.pumpAndSettle();

    expect(find.text('Escolha uma imagem JPG, PNG ou WebP.'), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-cover-preview')), findsNothing);
    expect(service.createCalls, 0);
  });

  testWidgets('returns to Home, requests refresh and does not open details', (
    tester,
  ) async {
    final service = _FakeTripsService();
    var refreshRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          showBottomNavigation: false,
          tripsService: service,
          friendsService: _FakeFriendsService(),
          authService: _FakeAuthService(),
          onTripsRefresh: () async => refreshRequests++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nova viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova viagem'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('trip-name-field')),
      'Lisboa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('trip-destination-field')),
      'Portugal',
    );
    await _selectDates(tester);
    await tester.ensureVisible(find.text('Criar viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar viagem'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Viagem criada com sucesso.'), findsOneWidget);
    expect(refreshRequests, 1);
    expect(find.byType(TripDetailsScreen), findsNothing);
  });

  testWidgets('keeps field values after API failure', (tester) async {
    final service = _FakeTripsService(
      error: const TripsServiceException('Servidor indisponível.'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CreateTripScreen(
          tripsService: service,
          friendsService: _FakeFriendsService(),
          authService: _FakeAuthService(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Viagem de teste');
    await tester.enterText(find.byType(TextFormField).at(1), 'Porto');
    await tester.tap(find.byKey(const ValueKey('trip-start-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-end-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar viagem'));
    await tester.pumpAndSettle();

    expect(find.text('Servidor indisponível.'), findsOneWidget);
    expect(find.text('Viagem de teste'), findsOneWidget);
    expect(find.text('Porto'), findsOneWidget);
  });

  testWidgets('ignores a second submit while the first request is pending', (
    tester,
  ) async {
    final pending = Completer<Trip>();
    final service = _FakeTripsService(pending: pending);
    await tester.pumpWidget(
      MaterialApp(
        home: CreateTripScreen(
          tripsService: service,
          friendsService: _FakeFriendsService(),
          authService: _FakeAuthService(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Lisboa');
    await tester.enterText(find.byType(TextFormField).at(1), 'Portugal');
    await tester.tap(find.byKey(const ValueKey('trip-start-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-end-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Criar viagem'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar viagem'));
    await tester.pump();
    expect(service.createCalls, 1);
    expect(find.text('Salvando...'), findsOneWidget);
    expect(service.createCalls, 1);

    pending.complete(
      Trip(
        id: 42,
        name: 'Lisboa',
        destination: 'Portugal',
        startDate: DateTime(2026, 8, 12),
        endDate: DateTime(2026, 8, 12),
        description: '',
        createdAt: DateTime.utc(2026, 1, 1),
        organizerId: 7,
        acceptedParticipantsCount: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(service.createCalls, 1);
  });
}

class _FakeTripsService extends TripsService {
  _FakeTripsService({this.error, this.pending});

  final Exception? error;
  final Completer<Trip>? pending;
  int createCalls = 0;
  String? lastName;
  String? lastDestination;
  XFile? coverImage;
  List<int> inviteeIds = [];

  @override
  Future<Trip> createTrip({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String description = '',
    XFile? coverImage,
    List<int> inviteeIds = const [],
  }) async {
    createCalls++;
    lastName = name;
    lastDestination = destination;
    this.coverImage = coverImage;
    this.inviteeIds = inviteeIds;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return Trip(
      id: 42,
      name: name.trim(),
      destination: destination.trim(),
      startDate: startDate,
      endDate: endDate,
      description: description,
      createdAt: DateTime.utc(2026, 1, 1),
      organizerId: 7,
      acceptedParticipantsCount: 1,
    );
  }
}

class _FakeFriendsService extends FriendsService {
  _FakeFriendsService({this.relationships = const []});

  final List<Map<String, dynamic>> relationships;

  @override
  Future<List<Map<String, dynamic>>> getFriends() async => relationships;
}

class _FakeAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>?> getSavedUser() async => {'id': 1};
}

Map<String, dynamic> _friend(int id) => {
  'status': 'accepted',
  'sender': {'id': 1, 'name': 'Organizador'},
  'receiver': {'id': id, 'name': 'Amiga $id', 'avatar_url': null},
};

Future<void> _selectDates(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('trip-start-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-start-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirmar'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('trip-end-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('trip-end-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirmar'));
  await tester.pumpAndSettle();
}
