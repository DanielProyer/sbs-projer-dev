import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';

final heute = DateTime(2026, 9, 15);

Einsatz stoerung() => Einsatz(
  typ: EinsatzTyp.stoerung,
  typLabel: 'Störung',
  routeId: 's1',
  betriebId: 'b1',
  betriebName: 'Calanda',
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: DateTime(2026, 9, 10),
  status: EinsatzStatus.offen,
  kennzeichen: EinsatzKennzeichen.keines,
);

AufgabenEintrag eintrag({
  AufgabenQuelle quelle = AufgabenQuelle.eigene,
  String titel = 'Filter bestellen',
  String? untertitel,
  DateTime? faellig,
  bool dringend = false,
  bool manuellErledigbar = false,
  Einsatz? einsatz,
}) => AufgabenEintrag(
  quelle: quelle,
  key: 'k',
  titel: titel,
  untertitel: untertitel,
  faellig: faellig,
  dringend: dringend,
  route: '/x',
  einsatz: einsatz,
  eigeneId: quelle == AufgabenQuelle.eigene ? 'a1' : null,
  manuellErledigbar: manuellErledigbar,
);

Widget rahmen(Widget kind) => MaterialApp(
  home: Scaffold(body: ListView(children: [kind])),
);

Widget zeile(
  AufgabenEintrag e, {
  VoidCallback? onDorthin,
  ValueChanged<int>? onSnooze,
  VoidCallback? onErledigt,
  VoidCallback? onEinplanen,
  VoidCallback? onBestaetigen,
}) => AufgabeZeile(
  eintrag: e,
  heute: heute,
  onDorthin: onDorthin ?? () {},
  onSnooze: onSnooze ?? (_) {},
  onErledigt: onErledigt ?? () {},
  onEinplanen: onEinplanen ?? () {},
  onBestaetigen: onBestaetigen ?? () {},
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets(
    'eigene Aufgabe: Titel, Faelligkeitstext, Snooze und Erledigt, kein Einplanen',
    (tester) async {
      await tester.pumpWidget(
        rahmen(zeile(eintrag(faellig: DateTime(2026, 9, 17)))),
      );
      expect(find.text('Filter bestellen'), findsOneWidget);
      expect(find.textContaining('Do 17.09.'), findsOneWidget);
      expect(find.byTooltip('Später erinnern'), findsOneWidget);
      expect(find.byTooltip('Erledigt'), findsOneWidget);
      expect(find.byTooltip('Einplanen'), findsNothing);
      expect(find.byTooltip('Termin bestätigen'), findsNothing);
    },
  );

  testWidgets('Detektor ohne Haken, mit Dorthin und Snooze', (tester) async {
    await tester.pumpWidget(
      rahmen(
        zeile(
          eintrag(
            quelle: AufgabenQuelle.detektor,
            titel: 'Mahnlauf',
            faellig: heute,
          ),
        ),
      ),
    );
    expect(find.byTooltip('Erledigt'), findsNothing);
    expect(find.byTooltip('Dorthin'), findsOneWidget);
    expect(find.byTooltip('Später erinnern'), findsOneWidget);
  });

  testWidgets('MWST-Detektor mit Haken', (tester) async {
    await tester.pumpWidget(
      rahmen(
        zeile(
          eintrag(quelle: AufgabenQuelle.detektor, manuellErledigbar: true),
        ),
      ),
    );
    expect(find.byTooltip('Erledigt'), findsOneWidget);
  });

  testWidgets('Stoerung: Einplanen, kein Snooze, ueberfaellig-Text', (
    tester,
  ) async {
    await tester.pumpWidget(
      rahmen(
        zeile(
          eintrag(
            quelle: AufgabenQuelle.einsatz,
            titel: 'Störung Calanda',
            untertitel: 'Zapfhahn tropft · nicht geplant',
            faellig: DateTime(2026, 9, 12),
            dringend: true,
            einsatz: stoerung(),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Einplanen'), findsOneWidget);
    expect(find.byTooltip('Später erinnern'), findsNothing);
    expect(find.textContaining('überfällig seit 3 Tagen'), findsOneWidget);
  });

  testWidgets('Saison-Vorschlag: Bestaetigen', (tester) async {
    await tester.pumpWidget(
      rahmen(
        zeile(eintrag(quelle: AufgabenQuelle.saisonVorschlag, faellig: heute)),
      ),
    );
    expect(find.byTooltip('Termin bestätigen'), findsOneWidget);
  });

  testWidgets('Knoepfe rufen die Callbacks', (tester) async {
    var erledigt = false, dorthin = false;
    await tester.pumpWidget(
      rahmen(
        zeile(
          eintrag(),
          onErledigt: () => erledigt = true,
          onDorthin: () => dorthin = true,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Erledigt'));
    expect(erledigt, isTrue);
    await tester.tap(find.text('Filter bestellen'));
    expect(dorthin, isTrue);
  });

  testWidgets('Snooze-Menue bietet 1/3/7 Tage', (tester) async {
    int? tage;
    await tester.pumpWidget(
      rahmen(zeile(eintrag(), onSnooze: (t) => tage = t)),
    );
    await tester.tap(find.byTooltip('Später erinnern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 Tage'));
    await tester.pumpAndSettle();
    expect(tage, 3);
  });

  testWidgets('360 px, drei Knoepfe, Titel bleibt lesbar', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      rahmen(
        zeile(
          eintrag(
            quelle: AufgabenQuelle.einsatz,
            titel: 'Störung Seerestaurant Schlüssel',
            faellig: heute,
            einsatz: stoerung(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final absatz = tester.renderObject<RenderParagraph>(
      find.text('Störung Seerestaurant Schlüssel'),
    );
    expect(absatz.didExceedMaxLines, isFalse);
  });

  testWidgets('kein ListTile, kein FilledButton', (tester) async {
    await tester.pumpWidget(rahmen(zeile(eintrag())));
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
