import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/screens/aufgaben/aufgaben_screen.dart';

final heute = DateTime(2026, 9, 15, 9);

AufgabenEintrag e(
  String titel,
  DateTime? faellig, {
  AufgabenQuelle quelle = AufgabenQuelle.eigene,
}) => AufgabenEintrag(
  quelle: quelle,
  key: titel,
  titel: titel,
  faellig: faellig,
  eigeneId: 'x',
);

Widget rahmen(
  List<AufgabenEintrag> liste, {
  ValueChanged<AufgabenEintrag>? onErledigt,
  VoidCallback? onNeu,
}) => MaterialApp(
  home: AufgabenInhalt(
    eintraege: liste,
    heute: heute,
    onDorthin: (_) {},
    onSnooze: (_, _) {},
    onErledigt: onErledigt ?? (_) {},
    onEinplanen: (_) {},
    onBestaetigen: (_) {},
    onNeu: onNeu ?? () {},
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Die Gruppenueberschrift «Fr, 18.09.2026» kommt aus DateFormat('de_CH');
    // ohne Locale-Daten wirft das im Test (main.dart laedt sie beim Start).
    await initializeDateFormatting('de_CH');
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets(
    'Gruppen Ueberfaellig, Heute, Morgen, Datum, Ohne Datum in dieser Reihenfolge',
    (tester) async {
      await tester.pumpWidget(
        rahmen([
          e('Alt', DateTime(2026, 9, 12)),
          e('Jetzt', DateTime(2026, 9, 15)),
          e('Bald', DateTime(2026, 9, 16)),
          e('Spaeter', DateTime(2026, 9, 18)),
          e('Irgendwann', null),
        ]),
      );
      for (final g in ['Überfällig', 'Heute', 'Morgen', 'Ohne Datum']) {
        expect(find.text(g), findsOneWidget, reason: g);
      }
      expect(find.textContaining('18.09.2026'), findsOneWidget);
      final y = <String, double>{
        for (final t in ['Überfällig', 'Heute', 'Morgen', 'Ohne Datum'])
          t: tester.getTopLeft(find.text(t)).dy,
      };
      expect(
        y['Überfällig']! < y['Heute']! &&
            y['Heute']! < y['Morgen']! &&
            y['Morgen']! < y['Ohne Datum']!,
        isTrue,
      );
    },
  );

  testWidgets('Leerzustand', (tester) async {
    await tester.pumpWidget(rahmen(const []));
    expect(find.text('Keine anstehenden Aufgaben.'), findsOneWidget);
  });

  testWidgets('Erledigt meldet den Eintrag', (tester) async {
    AufgabenEintrag? erledigt;
    await tester.pumpWidget(
      rahmen([e('Anrufen', heute)], onErledigt: (a) => erledigt = a),
    );
    await tester.tap(find.byTooltip('Erledigt'));
    expect(erledigt?.titel, 'Anrufen');
  });

  testWidgets('Plus meldet Neu', (tester) async {
    var neu = false;
    await tester.pumpWidget(rahmen(const [], onNeu: () => neu = true));
    await tester.tap(find.byKey(const Key('aufgabe_neu')));
    expect(neu, isTrue);
  });

  testWidgets('Aufgaben-Screen zeigt auch Buero-Fristen (nur die Heute-Karte filtert)', (
    tester,
  ) async {
    await tester.pumpWidget(
      rahmen([
        const AufgabenEintrag(
          quelle: AufgabenQuelle.detektor,
          key: 'mwst:2026-Q3',
          titel: 'MWST Q3 2026 abrechnen',
          route: '/buchhaltung/mwst',
        ),
        AufgabenEintrag(
          quelle: AufgabenQuelle.detektor,
          key: 'entwurf:b1',
          titel: 'Reinigung Hirschen angefangen (09:12)',
          faellig: heute,
          route: '/reinigungen/neu?betriebId=b1',
          draussen: true,
        ),
      ]),
    );
    expect(find.text('MWST Q3 2026 abrechnen'), findsOneWidget);
    expect(find.text('Reinigung Hirschen angefangen (09:12)'), findsOneWidget);
  });
}
