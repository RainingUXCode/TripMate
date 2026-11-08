import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/screens/notifications_screen.dart';
import 'package:tripmate/services/notifications_service.dart';
import 'package:tripmate/widgets/tripmate_notification_button.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders empty and error retry states', (tester) async {
    final service = _FakeNotificationsService()..items = const [];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          key: const ValueKey('error-screen'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Você está em dia'), findsOneWidget);

    service.error = const NotificationsServiceException('Sem conexão.');
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('loads real items, marks one read and opens its target', (
    tester,
  ) async {
    var opened = 0;
    var changed = 0;
    final service = _FakeNotificationsService()..unread = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          service: service,
          onChanged: () async => changed++,
          onOpenTarget: (_) async => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nova solicitação de amizade'), findsOneWidget);
    expect(find.byType(TripMateNotificationButton), findsNothing);
    await tester.tap(find.text('Nova solicitação de amizade'));
    await tester.pumpAndSettle();

    expect(service.readIds, [1]);
    expect(changed, 1);
    expect(opened, 1);
  });

  testWidgets('mark all and notification bell use real unread state', (
    tester,
  ) async {
    final service = _FakeNotificationsService()..unread = 2;
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Marcar todas como lidas'), findsOneWidget);
    await tester.tap(find.text('Marcar todas como lidas'));
    await tester.pumpAndSettle();
    expect(service.markAllCalls, 1);
    expect(find.text('Marcar todas como lidas'), findsNothing);

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripMateNotificationButton(
            onPressed: () => tapped = true,
            hasUnreadNotifications: true,
          ),
        ),
      ),
    );
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
    await tester.tap(find.byType(TripMateNotificationButton));
    expect(tapped, isTrue);
  });

  testWidgets('keeps long notification text readable with larger text scale', (
    tester,
  ) async {
    final service = _FakeNotificationsService()
      ..items = [
        {
          ..._notification(),
          'message': 'Uma mensagem extensa de notificação que precisa quebrar em várias linhas sem causar overflow na tela do celular.',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: NotificationsScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads the next page when the list is scrolled', (tester) async {
    final service = _FakeNotificationsService()
      ..items = List.generate(
        12,
        (index) => {
          ..._notification(),
          'id': index + 1,
          'title': 'Aviso $index',
        },
      )
      ..secondPage = [
        {..._notification(), 'id': 21, 'title': 'Aviso da segunda página'},
      ];
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -2500));
    await tester.pumpAndSettle();

    expect(service.requestedPages, contains(2));
    expect(find.text('Aviso da segunda página'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _notification() => {
  'id': 1,
  'event_type': 'friend_request',
  'title': 'Nova solicitação de amizade',
  'message': 'Marina enviou uma solicitação de amizade.',
  'resource_type': 'friendship',
  'resource_id': 10,
  'context_id': null,
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'read_at': null,
  'is_read': false,
};

class _FakeNotificationsService extends NotificationsService {
  _FakeNotificationsService() : super();

  List<Map<String, dynamic>> items = [_notification()];
  List<Map<String, dynamic>> secondPage = const [];
  final requestedPages = <int>[];
  Object? error;
  int unread = 1;
  final readIds = <int>[];
  int markAllCalls = 0;

  @override
  Future<NotificationsPage> getPage({int page = 1}) async {
    requestedPages.add(page);
    if (error case final issue?) throw issue;
    if (page == 2) {
      return NotificationsPage(
        results: secondPage,
        count: items.length + secondPage.length,
        nextPage: null,
      );
    }
    return NotificationsPage(
      results: items,
      count: items.length + secondPage.length,
      nextPage: secondPage.isEmpty ? null : 2,
    );
  }

  @override
  Future<int> getUnreadCount() async => unread;

  @override
  Future<Map<String, dynamic>> markAsRead(int notificationId) async {
    readIds.add(notificationId);
    unread = (unread - 1).clamp(0, 1 << 31);
    return {'id': notificationId, 'is_read': true};
  }

  @override
  Future<void> markAllAsRead() async {
    markAllCalls++;
    unread = 0;
  }

  @override
  void close() {}
}
