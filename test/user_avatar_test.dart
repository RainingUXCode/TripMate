import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/widgets/user_avatar.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('foto é recortada pelo círculo e preenche com BoxFit.cover', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: UserAvatar(
              name: 'Ana Lima',
              imageUrl: 'https://example.test/avatar.png',
              size: 24,
            ),
          ),
        ),
      ),
    );

    final image = find.byType(Image);
    expect(image, findsOneWidget);
    expect(tester.widget<Image>(image).fit, BoxFit.cover);
    expect(
      find.ancestor(of: image, matching: find.byType(ClipOval)),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(UserAvatar)), const Size(24, 24));

    final ring = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(UserAvatar),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = ring.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.border, isA<Border>());
    expect((decoration.border! as Border).top.color, Colors.white);
    expect((decoration.border! as Border).top.width, 2);
  });

  testWidgets('iniciais permanecem centralizadas em tamanhos diferentes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              UserAvatar(name: 'Ana Lima', size: 20),
              SizedBox(width: 20),
              UserAvatar(name: 'João Silva', size: 76),
            ],
          ),
        ),
      ),
    );

    expect(find.text('AL'), findsOneWidget);
    expect(find.text('JS'), findsOneWidget);
    expect(tester.getSize(find.byType(UserAvatar).first), const Size(20, 20));
    expect(tester.getSize(find.byType(UserAvatar).last), const Size(76, 76));
    expect(find.byType(ClipOval), findsNWidgets(2));
    expect(find.byType(DecoratedBox), findsNWidgets(2));
    for (final initials in [find.text('AL'), find.text('JS')]) {
      expect(
        find.ancestor(of: initials, matching: find.byType(ClipOval)),
        findsOneWidget,
      );
    }
  });

  testWidgets('falha ao carregar foto apresenta o fallback circular', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: UserAvatar(
              name: 'Marina Azevedo',
              imageUrl: 'https://example.test/missing-avatar.png',
              size: 34,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MA'), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
    expect(tester.getSize(find.byType(UserAvatar)), const Size(34, 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatares sobrepostos conservam recorte e contorno', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 52,
              height: 24,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: UserAvatar(name: 'Ana Lima', size: 24),
                  ),
                  Positioned(
                    left: 16,
                    child: UserAvatar(name: 'João Silva', size: 24),
                  ),
                  Positioned(
                    left: 32,
                    child: UserAvatar(name: 'Marina Alves', size: 24),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(UserAvatar), findsNWidgets(3));
    expect(find.byType(ClipOval), findsNWidgets(3));
    expect(find.byType(DecoratedBox), findsNWidgets(3));
    for (final avatar in find.byType(UserAvatar).evaluate()) {
      expect(tester.getSize(find.byWidget(avatar.widget)), const Size(24, 24));
    }
    expect(tester.takeException(), isNull);
  });
}
