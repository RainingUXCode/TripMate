import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripmate/models/trip.dart';
import 'package:tripmate/widgets/trip_card.dart';
import 'package:tripmate/widgets/user_avatar.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('mantém nome e destino agrupados acima dos participantes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: TripCard(
                trip: _trip(name: 'Lisboa'),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final title = tester.getRect(find.text('Lisboa'));
    final destination = tester.getRect(find.text('Lisboa, Portugal'));
    final participants = tester.getRect(find.byType(UserAvatar).first);
    final card = tester.getSize(
      find.byKey(const ValueKey('trip-card-surface-17')),
    );
    final cover = tester.getSize(
      find.byKey(const ValueKey('trip-card-cover-17')),
    );
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('trip-card-surface-17')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(destination.top - title.bottom, lessThan(12));
    expect(participants.top - destination.bottom, greaterThan(5));
    expect(card.height, closeTo(130, 1));
    expect(cover.height, closeTo(108, 1));
    expect(decoration.color, Colors.white);
    expect(decoration.gradient, isNull);
    expect(decoration.border!.top.color, const Color(0xFFE4E3EE));
    expect(decoration.boxShadow!.single.color.toARGB32() & 0x00FFFFFF, 0);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(tester.widget<Text>(find.text('Lisboa')).style?.fontSize, 18);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'nomes e destinos longos cabem em largura estreita e escala maior',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: TripCard(
                  trip: _trip(
                    name:
                        'Uma viagem de fim de semana muito comprida em Lisboa',
                    destination: 'Lisboa, Portugal, perto do centro histórico',
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capa real usa BoxFit.cover e mantém o badge de datas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripCard(
            trip: _trip(coverImageUrl: 'https://media.example.test/capa.jpg'),
            onTap: () {},
          ),
        ),
      ),
    );

    final networkImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url ==
                'https://media.example.test/capa.jpg',
      ),
    );
    expect(networkImage.fit, BoxFit.cover);
    expect(find.text('10/12–15/12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Trip _trip({
  String name = 'Fim de semana em Lisboa',
  String destination = 'Lisboa, Portugal',
  String? coverImageUrl,
}) => Trip(
  id: 17,
  name: name,
  destination: destination,
  startDate: DateTime(2026, 12, 10),
  endDate: DateTime(2026, 12, 15),
  description: '',
  createdAt: DateTime.utc(2026, 11, 7),
  organizerId: 4,
  acceptedParticipantsCount: 2,
  coverImageUrl: coverImageUrl,
  acceptedParticipants: const [
    TripParticipant(id: 21, name: 'Ana'),
    TripParticipant(id: 22, name: 'Bia'),
  ],
);
