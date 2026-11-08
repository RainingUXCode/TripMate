import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/screens/settlements_screen.dart';
import 'package:tripmate/services/trips_service.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('mostra sugestões e histórico vazios sem criar acerto', (
    tester,
  ) async {
    final service = _FakeTripsService();
    await tester.pumpWidget(_app(service, userId: 2));
    await tester.pumpAndSettle();

    expect(find.text('Não há obrigações pendentes.'), findsOneWidget);
    expect(find.text('Nenhum acerto registrado.'), findsOneWidget);
    expect(find.text('Ainda sem movimentações.'), findsOneWidget);
    expect(service.createCalls, 0);
  });

  testWidgets('sheet de detalhes exibe operação confirmada e fecha pelo X', (
    tester,
  ) async {
    final service = _FakeTripsService()
      ..settlements = [_settlement(status: 'confirmed', createdBy: 2)];
    await tester.pumpWidget(_app(service, userId: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Detalhes'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes do acerto'), findsOneWidget);
    final sheet = find.byKey(const ValueKey('settlement-details-sheet'));
    expect(
      find.descendant(of: sheet, matching: find.text('R\$ 25,00')),
      findsOneWidget,
    );
    expect(find.text('Pagamento confirmado'), findsOneWidget);
    expect(find.text('João Lima'), findsWidgets); // Pagador e declarante.
    expect(
      find.text('Marina Alves'),
      findsWidgets,
    ); // Recebedora e confirmadora.
    expect(find.text('Quem paga → Quem recebe'), findsOneWidget);
    expect(find.text('Data da declaração'), findsOneWidget);
    expect(find.text('Confirmado por'), findsOneWidget);
    expect(find.text('Data da confirmação'), findsOneWidget);
    expect(find.textContaining('Chave da solicitação'), findsNothing);
    expect(
      find.textContaining('8f6ee938-b5be-4e18-99b0-77ac22acdc24'),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Fechar detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do acerto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status pendente e cancelado têm rótulos explícitos', (
    tester,
  ) async {
    for (final scenario in [
      (status: 'pending', label: 'Aguardando confirmação'),
      (status: 'cancelled', label: 'Acerto cancelado'),
    ]) {
      final service = _FakeTripsService()
        ..settlements = [_settlement(status: scenario.status, createdBy: 2)];
      await tester.pumpWidget(
        _app(service, userId: 1, key: ValueKey(scenario.status)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settlement-details-sheet')),
          matching: find.text(scenario.label),
        ),
        findsOneWidget,
      );
      expect(find.text('Confirmado por'), findsNothing);
      expect(find.text('Data da confirmação'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Fechar detalhes'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'sheet ocupa a largura e rola com texto ampliado e nomes longos',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1500);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _FakeTripsService()
        ..settlements = [_settlement(status: 'confirmed', createdBy: 2)];
      await tester.pumpWidget(
        _app(
          service,
          userId: 1,
          textScaler: const TextScaler.linear(1.4),
          participants: const [
            TripParticipant(
              id: 1,
              name: 'Marina Azevedo de Albuquerque e Souza',
            ),
            TripParticipant(id: 2, name: 'João Pedro de Oliveira Lima Filho'),
            TripParticipant(id: 3, name: 'Lucas Reis'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detalhes'));
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(find.byKey(const ValueKey('settlement-details-sheet')))
            .width,
        360,
      );
      expect(find.text('Marina Azevedo de Albuquerque e Souza'), findsWidgets);
      expect(find.text('João Pedro de Oliveira Lima Filho'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('declara valor permitido e envia chave UUID como string', (
    tester,
  ) async {
    final service = _FakeTripsService()..proposals = [_proposal()];
    await tester.pumpWidget(_app(service, userId: 2));
    await tester.pumpAndSettle();

    expect(find.text('Você paga Marina'), findsOneWidget);
    await tester.tap(find.text('Registrar acerto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '20,50');
    await tester.tap(find.text('Registrar pagamento pendente'));
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(service.createdPayload?['debtor_id'], 2);
    expect(service.createdPayload?['creditor_id'], 1);
    expect(service.createdPayload?['amount'], '20.50');
    expect(
      service.createdPayload?['request_key'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(find.text('Aguardando confirmação'), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing); // O declarante não confirma.
    expect(service.refreshLoads, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'oculta ação para não envolvido e rejeita valor acima da sugestão',
    (tester) async {
      final service = _FakeTripsService()..proposals = [_proposal()];
      await tester.pumpWidget(_app(service, userId: 3));
      await tester.pumpAndSettle();
      expect(find.text('Registrar acerto'), findsNothing);

      await tester.pumpWidget(
        _app(service, userId: 2, key: const ValueKey('payer')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar acerto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '60.01');
      await tester.tap(find.text('Registrar pagamento pendente'));
      await tester.pumpAndSettle();
      expect(find.textContaining('excede a sugestão'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '0.00');
      await tester.tap(find.text('Registrar pagamento pendente'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '-1.00');
      await tester.tap(find.text('Registrar pagamento pendente'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      expect(service.createCalls, 0);
    },
  );

  testWidgets(
    'contraparte confirma e participante envolvido cancela pendência',
    (tester) async {
      final service = _FakeTripsService()
        ..settlements = [_settlement(status: 'pending', createdBy: 2)];
      var financialRefreshes = 0;
      await tester.pumpWidget(_app(service, userId: 3));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar'), findsNothing);
      expect(find.text('Cancelar'), findsNothing);

      await tester.pumpWidget(
        _app(
          service,
          userId: 1,
          key: const ValueKey('counterparty'),
          onChanged: () async => financialRefreshes++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirmar'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(service.confirmCalls, 1);
      expect(find.text('Confirmado'), findsOneWidget);
      expect(find.text('Confirmar'), findsNothing);
      expect(find.text('Cancelar'), findsNothing);
      expect(financialRefreshes, 1);

      service.settlements = [_settlement(status: 'pending', createdBy: 2)];
      await tester.pumpWidget(
        _app(
          service,
          userId: 1,
          key: const ValueKey('cancel-flow'),
          onChanged: () async => financialRefreshes++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar acerto'));
      await tester.pumpAndSettle();
      expect(service.cancelCalls, 1);
      expect(find.text('Cancelado'), findsOneWidget);
      expect(financialRefreshes, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reconcilia falha ambígua de criação sem repetir POST', (
    tester,
  ) async {
    final service = _FakeTripsService()
      ..proposals = [_proposal()]
      ..failCreate = true;
    await tester.pumpWidget(_app(service, userId: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar acerto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar pagamento pendente'));
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(find.text('Consultar estado remoto'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.close_rounded),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Consultar estado remoto'));
    await tester.pumpAndSettle();
    expect(service.createCalls, 1);
    expect(find.textContaining('Nenhum acerto com esta chave'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet é rolável em tela estreita e escala ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1500);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _FakeTripsService()..proposals = [_proposal()];
    await tester.pumpWidget(
      _app(service, userId: 2, textScaler: const TextScaler.linear(1.3)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar acerto'));
    await tester.pumpAndSettle();
    expect(find.text('Quem paga'), findsOneWidget);
    expect(find.text('Quem recebe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('não oferece repetir confirmação até consultar o estado remoto', (
    tester,
  ) async {
    final service = _FakeTripsService()
      ..settlements = [_settlement(status: 'pending', createdBy: 2)]
      ..failConfirm = true;
    await tester.pumpWidget(_app(service, userId: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(service.confirmCalls, 1);
    expect(
      find.text(
        'O estado do último acerto ainda não pôde ser confirmado. Atualize antes de tentar novamente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Confirmar'), findsNothing);
    await tester.tap(find.byTooltip('Atualizar acertos'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar'), findsOneWidget);
    expect(service.confirmCalls, 1);
  });
}

Widget _app(
  _FakeTripsService service, {
  required int userId,
  Key? key,
  Future<void> Function()? onChanged,
  TextScaler? textScaler,
  List<TripParticipant>? participants,
}) => MaterialApp(
  builder: (context, child) => textScaler == null
      ? child!
      : MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: SettlementsScreen(
    key: key,
    tripId: 17,
    participants:
        participants ??
        const [
          TripParticipant(id: 1, name: 'Marina Alves'),
          TripParticipant(id: 2, name: 'João Lima'),
          TripParticipant(id: 3, name: 'Lucas Reis'),
        ],
    currentUserId: userId,
    service: service,
    onFinancialChanged: onChanged,
  ),
);

Map<String, dynamic> _proposal() => {
  'debtor_id': 2,
  'creditor_id': 1,
  'amount': '60.00',
};

Map<String, dynamic> _settlement({
  String status = 'pending',
  int createdBy = 2,
}) => {
  'id': 9,
  'trip_id': 17,
  'debtor_id': 2,
  'creditor_id': 1,
  'created_by_id': createdBy,
  'confirmed_by_id': status == 'confirmed' ? 1 : null,
  'cancelled_by_id': status == 'cancelled' ? 1 : null,
  'status': status,
  'amount': '25.00',
  'request_key': '8f6ee938-b5be-4e18-99b0-77ac22acdc24',
  'created_at': '2026-11-07T12:00:00+00:00',
  'confirmed_at': status == 'confirmed' ? '2026-11-07T12:05:00+00:00' : null,
  'cancelled_at': status == 'cancelled' ? '2026-11-07T12:05:00+00:00' : null,
};

class _FakeTripsService extends TripsService {
  List<Map<String, dynamic>> proposals = [];
  List<Map<String, dynamic>> settlements = [];
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? createdPayload;
  int createCalls = 0;
  int confirmCalls = 0;
  int cancelCalls = 0;
  int refreshLoads = 0;
  bool failCreate = false;
  bool failConfirm = false;
  bool failNextSettlementRead = false;

  @override
  Future<List<Map<String, dynamic>>> getSettlementProposals(int tripId) async {
    refreshLoads++;
    return proposals;
  }

  @override
  Future<List<Map<String, dynamic>>> getSettlements(int tripId) async {
    if (failNextSettlementRead) {
      failNextSettlementRead = false;
      throw const TripsServiceException('Sem conexão.');
    }
    refreshLoads++;
    return settlements;
  }

  @override
  Future<List<Map<String, dynamic>>> getFinanceHistory(int tripId) async =>
      history;

  @override
  Future<Map<String, dynamic>> createSettlement(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    createCalls++;
    createdPayload = payload;
    if (failCreate) {
      failNextSettlementRead = true;
      throw const TripsServiceException('Conexão interrompida.');
    }
    final created = _settlement(createdBy: 2)
      ..['request_key'] = payload['request_key'];
    settlements = [...settlements, created];
    history = [...history, _event('pending', created)];
    return created;
  }

  @override
  Future<Map<String, dynamic>> confirmSettlement(
    int tripId,
    int settlementId,
  ) async {
    confirmCalls++;
    if (failConfirm) {
      failNextSettlementRead = true;
      throw const TripsServiceException('Conexão interrompida.');
    }
    settlements = settlements
        .map(
          (item) => item['id'] == settlementId
              ? _settlement(status: 'confirmed', createdBy: 2)
              : item,
        )
        .toList();
    history = [...history, _event('confirmed', settlements.first)];
    return settlements.first;
  }

  @override
  Future<Map<String, dynamic>> cancelSettlement(
    int tripId,
    int settlementId,
  ) async {
    cancelCalls++;
    settlements = settlements
        .map(
          (item) => item['id'] == settlementId
              ? _settlement(status: 'cancelled', createdBy: 2)
              : item,
        )
        .toList();
    history = [...history, _event('cancelled', settlements.first)];
    return settlements.first;
  }

  @override
  Future<Map<String, dynamic>> getSettlement(
    int tripId,
    int settlementId,
  ) async => settlements.firstWhere((item) => item['id'] == settlementId);
}

Map<String, dynamic> _event(String status, Map<String, dynamic> settlement) => {
  'id': 1,
  'action': 'settlement.$status',
  'actor_id': 1,
  'created_at': '2026-11-07T12:00:00+00:00',
  'snapshot': {'after': settlement},
};
