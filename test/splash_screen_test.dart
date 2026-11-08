import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:tripmate/main.dart';
import 'package:tripmate/services/auth_service.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'loads the supplied Lottie once, tints it purple and opens Welcome',
    (tester) async {
      final auth = _FakeAuthService(authenticated: false);
      await tester.pumpWidget(_app(auth));
      await tester.pump();
      await _allowAssetDecoding(tester);

      expect(find.byType(Lottie), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tripmate-splash-purple-tint')),
        findsOneWidget,
      );
      expect(find.text('TripMate'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        Colors.white,
      );

      await tester.pumpAndSettle();
      expect(find.text('WelcomeDestination'), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('routes an authenticated user to Home after the animation', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeAuthService(authenticated: true)));
    await _allowAssetDecoding(tester);
    await tester.pumpAndSettle();
    expect(find.text('HomeDestination'), findsOneWidget);
    expect(find.text('WelcomeDestination'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion skips playback and still waits for session readiness',
    (tester) async {
      final ready = Completer<bool>();
      await tester.pumpWidget(
        _app(
          _FakeAuthService(authenticated: false, waitForSession: ready),
          reducedMotion: true,
        ),
      );
      await _allowAssetDecoding(tester);
      await tester.pumpAndSettle();

      final lottie = tester.widget<Lottie>(find.byType(Lottie));
      expect(lottie.controller?.value, 1);
      expect(find.text('WelcomeDestination'), findsNothing);
      ready.complete(false);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('WelcomeDestination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'removes the white background layer and retains the embedded plane PNG',
    () async {
      final json = jsonDecode(
        await rootBundle.loadString(
          'assets/animations/send_animated_icon.json',
        ),
      ) as Map<String, dynamic>;
      final layers = (json['layers'] as List).cast<Map<String, dynamic>>();
      final plane = (json['assets'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((asset) => asset['id'] == 'image_0');

      expect(layers.any((layer) => layer['nm'] == 'BG'), isFalse);
      expect(plane['p'], startsWith('data:image/png;base64,'));
      expect(json['op'], 80);
      expect(json['fr'], 60);
    },
  );
}

Future<void> _allowAssetDecoding(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

Widget _app(_FakeAuthService auth, {bool reducedMotion = false}) => MaterialApp(
  builder: (context, child) => reducedMotion
      ? MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        )
      : child!,
  home: SessionScreen(authService: auth),
  routes: {
    '/welcome': (_) => const Scaffold(body: Text('WelcomeDestination')),
    '/home': (_) => const Scaffold(body: Text('HomeDestination')),
  },
);

class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.authenticated, this.waitForSession});

  final bool authenticated;
  final Completer<bool>? waitForSession;

  @override
  Future<bool> hasSavedSession() =>
      waitForSession?.future ?? Future.value(authenticated);

  @override
  Future<bool> refreshSession() async => authenticated;

  @override
  Future<Map<String, dynamic>?> getSavedUser() async =>
      authenticated ? {'id': 12, 'name': 'Usuário'} : null;
}
