import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:tripmate/main.dart' as app;

const _apiHost = String.fromEnvironment(
  'TRIPMATE_API_HOST',
  defaultValue: 'http://127.0.0.1:8000',
);

Uri _apiUri(String path) => Uri.parse('$_apiHost$path');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA real: login, criar viagem, lançar gasto, gerenciar e sair', (
    tester,
  ) async {
    final account = await _createEphemeralAccount();
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Já tenho uma conta'), findsOneWidget);
    await tester.tap(find.text('Já tenho uma conta'));
    await tester.pumpAndSettle();

    final loginFields = find.byType(TextField);
    await tester.enterText(loginFields.first, account.email);
    await tester.enterText(loginFields.last, account.password);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Viagens em grupo'), findsOneWidget);
    expect(find.text('Olá, ${account.name.split(' ').first}!'), findsOneWidget);

    const tripName = 'QA Trip Integration';
    await tester.ensureVisible(find.text('Nova viagem'));
    await tester.tap(find.text('Nova viagem'));
    await tester.pumpAndSettle();

    final nameField = find.descendant(
      of: find.byKey(const ValueKey('trip-name-field')),
      matching: find.byType(TextField),
    );
    final destinationField = find.descendant(
      of: find.byKey(const ValueKey('trip-destination-field')),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, tripName);
    await tester.enterText(destinationField, 'QA Destination');

    for (final dateKey in const ['trip-start-date', 'trip-end-date']) {
      final dateField = find.byKey(ValueKey(dateKey));
      await tester.ensureVisible(dateField);
      await tester.tap(dateField);
      await tester.pumpAndSettle();
      final confirmDate = find.text('Confirmar');
      expect(confirmDate, findsOneWidget);
      await tester.tap(confirmDate);
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(
      find.byKey(const ValueKey('create-trip-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('create-trip-submit')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(tripName), findsOneWidget);

    await tester.tap(find.text(tripName));
    await tester.pumpAndSettle();
    expect(find.text('Visão geral'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Roteiro'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trip-tab-expenses')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adicionar gasto'));
    await tester.tap(find.text('Adicionar gasto'));
    await tester.pumpAndSettle();

    final expenseFields = find.byType(TextFormField);
    await tester.enterText(expenseFields.first, '50,00');
    await tester.enterText(expenseFields.last, 'Jantar QA');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final ownShare = find.ancestor(
      of: find.text(account.name),
      matching: find.byType(CheckboxListTile),
    );
    await tester.ensureVisible(ownShare);
    await tester.tap(ownShare);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar gasto'));
    await tester.tap(find.text('Salvar gasto'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Jantar QA'), findsOneWidget);

    final tripsResponse = await http.get(
      _apiUri('/api/trips/'),
      headers: {'Authorization': 'Bearer ${account.accessToken}'},
    );
    expect(tripsResponse.statusCode, 200);
    final trips = jsonDecode(tripsResponse.body) as List<dynamic>;
    final tripId =
        (trips.singleWhere((trip) => trip['name'] == tripName)
                as Map<String, dynamic>)['id']
            as int;
    final persistedExpenses = await http.get(
      _apiUri('/api/trips/$tripId/finance/expenses/'),
      headers: {'Authorization': 'Bearer ${account.accessToken}'},
    );
    expect(persistedExpenses.statusCode, 200);
    final expenseRows = jsonDecode(persistedExpenses.body) as List<dynamic>;
    expect(
      expenseRows.any(
        (row) => row['description'] == 'Jantar QA' && row['amount'] == '50.00',
      ),
      isTrue,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-details-settings')),
    );
    await tester.tap(find.byKey(const ValueKey('trip-details-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Gerenciar viagem'), findsOneWidget);
    expect(find.text('Transferir organização'), findsOneWidget);
    expect(find.text('Excluir viagem'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-management-back')));
    await tester.pumpAndSettle();
    expect(find.text('Jantar QA'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trip-details-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sair da conta').first);
    await tester.tap(find.text('Sair da conta').first);
    await tester.pumpAndSettle();
    expect(find.text('Sair da conta?'), findsOneWidget);
    await tester.tap(find.text('Sair da conta').last);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Começar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QA real: convite de viagem aceito na segunda conta', (
    tester,
  ) async {
    final organizer = await _createEphemeralAccount('Organizer');
    final invitee = await _createEphemeralAccount('Invitee');
    final organizerTokens = await _loginAccount(
      organizer.email,
      organizer.password,
    );
    final inviteeTokens = await _loginAccount(invitee.email, invitee.password);
    final friendship = await http.post(
      _apiUri('/api/friends/requests/send/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${organizerTokens['access']}',
      },
      body: jsonEncode({'receiver_id': invitee.id}),
    );
    expect(friendship.statusCode, 201);
    final friendshipId =
        (jsonDecode(friendship.body)['friendship'] as Map)['id'];
    final acceptedFriendship = await http.post(
      _apiUri('/api/friends/requests/$friendshipId/accept/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${inviteeTokens['access']}',
      },
      body: '{}',
    );
    expect(acceptedFriendship.statusCode, 200);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _loginThroughUi(tester, organizer.email, organizer.password);

    final tripName = 'QA Invitation ${DateTime.now().microsecondsSinceEpoch}';
    await _createTripThroughUi(tester, tripName, invitee.id);
    await tester.tap(find.text(tripName));
    await tester.pumpAndSettle();
    expect(find.text('1 participante'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('trip-details-settings')),
    );
    await tester.tap(find.byKey(const ValueKey('trip-details-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Convites pendentes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trip-management-back')));
    await tester.pumpAndSettle();

    final pending = await http.get(
      _apiUri('/api/trips/invitations/'),
      headers: {'Authorization': 'Bearer ${inviteeTokens['access']}'},
    );
    expect(pending.statusCode, 200);
    final invitations = jsonDecode(pending.body) as List;
    expect(invitations, hasLength(1));
    final tripId = invitations.single['trip_id'] as int;

    await tester.tap(find.byKey(const ValueKey('trip-details-back')));
    await tester.pumpAndSettle();
    await _logoutThroughUi(tester);
    await _loginThroughUi(tester, invitee.email, invitee.password);
    await tester.tap(find.byKey(const ValueKey('trip-invitations-entry')));
    await tester.pumpAndSettle();
    expect(find.text(tripName), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('trip-invitation-accept-$tripId')));
    await tester.pumpAndSettle();
    expect(find.text('Convite aceito'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum convite pendente'), findsOneWidget);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tripName));
    await tester.pumpAndSettle();
    expect(find.text('2 participantes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('trip-details-back')));
    await tester.pumpAndSettle();
  });
}

Future<
  ({int id, String email, String name, String password, String accessToken})
>
_createEphemeralAccount([String role = 'Android']) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'qa-android-$stamp@example.test';
  final name = 'QA $role $stamp';
  final password = 'Qa-$stamp-42!';
  final response = await http.post(
    _apiUri('/api/auth/register/'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'name': name, 'email': email, 'password': password}),
  );
  if (response.statusCode != 201) {
    throw StateError(
      'Cadastro de usuário efêmero falhou: HTTP ${response.statusCode}.',
    );
  }
  final account = jsonDecode(response.body) as Map<String, dynamic>;
  final tokens = await _loginAccount(email, password);
  return (
    id: account['id'] as int,
    email: email,
    name: name,
    password: password,
    accessToken: tokens['access'] as String,
  );
}

Future<Map<String, dynamic>> _loginAccount(
  String email,
  String password,
) async {
  final response = await http.post(
    _apiUri('/api/auth/login/'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (response.statusCode != 200) {
    throw StateError(
      'Login de fixture QA falhou: HTTP ${response.statusCode}.',
    );
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<void> _loginThroughUi(
  WidgetTester tester,
  String email,
  String password,
) async {
  final welcomeLogin = find.text('Já tenho uma conta');
  if (welcomeLogin.evaluate().isNotEmpty) {
    await tester.tap(welcomeLogin);
    await tester.pumpAndSettle();
  }
  final fields = find.byType(TextField);
  await tester.enterText(fields.first, email);
  await tester.enterText(fields.last, password);
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text('Viagens em grupo'), findsOneWidget);
}

Future<void> _createTripThroughUi(
  WidgetTester tester,
  String name,
  int? inviteeId,
) async {
  await tester.ensureVisible(find.text('Nova viagem'));
  await tester.tap(find.text('Nova viagem'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('trip-name-field')),
      matching: find.byType(TextField),
    ),
    name,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('trip-destination-field')),
      matching: find.byType(TextField),
    ),
    'QA Destination',
  );
  if (inviteeId != null) {
    final friend = find.byKey(ValueKey('trip-friend-$inviteeId'));
    await tester.ensureVisible(friend);
    await tester.tap(friend);
  }
  for (final dateKey in const ['trip-start-date', 'trip-end-date']) {
    final dateField = find.byKey(ValueKey(dateKey));
    await tester.ensureVisible(dateField);
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(const ValueKey('create-trip-submit')));
  await tester.tap(find.byKey(const ValueKey('create-trip-submit')));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text(name), findsOneWidget);
}

Future<void> _logoutThroughUi(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Perfil'));
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Sair da conta').first);
  await tester.tap(find.text('Sair da conta').first);
  await tester.pumpAndSettle();
  expect(find.text('Sair da conta?'), findsOneWidget);
  await tester.tap(find.text('Sair da conta').last);
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text('Já tenho uma conta'), findsOneWidget);
}
