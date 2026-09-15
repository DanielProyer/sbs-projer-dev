import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';

Einsatz einsatz({
  EinsatzTyp typ = EinsatzTyp.reinigung,
  String name = 'Calanda',
  EinsatzStatus status = EinsatzStatus.erledigt,
  EinsatzKennzeichen kennzeichen = EinsatzKennzeichen.keines,
  double? betrag = 177.30,
  String? zeit,
  String? beschreibung,
}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: 'x',
  betriebId: 'b1',
  betriebName: name,
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: DateTime(2026, 9, 15),
  status: status,
  kennzeichen: kennzeichen,
  betragCHF: betrag,
  zeit: zeit,
  beschreibung: beschreibung,
);

Widget rahmen(Widget kind) => MaterialApp(
  home: Scaffold(body: ListView(children: [kind])),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('zeigt Betrieb, Typ, Ort, Datum, Status und Betrag', (
    tester,
  ) async {
    await tester.pumpWidget(
      rahmen(EinsatzZeile(einsatz: einsatz(), onTap: () {})),
    );
    expect(find.text('Calanda'), findsOneWidget);
    expect(find.textContaining('Reinigung · Chur · Di 15.09.'), findsOneWidget);
    expect(find.text('erledigt'), findsOneWidget);
    expect(find.text("177.30"), findsOneWidget);
  });

  testWidgets('geplant zeigt Uhrzeit und keinen Betrag', (tester) async {
    await tester.pumpWidget(
      rahmen(
        EinsatzZeile(
          einsatz: einsatz(
            typ: EinsatzTyp.montage,
            status: EinsatzStatus.geplant,
            betrag: null,
            zeit: '09:00',
          ),
          onTap: () {},
        ),
      ),
    );
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.text('geplant'), findsOneWidget);
    expect(find.textContaining('CHF'), findsNothing);
  });

  testWidgets('Kennzeichen steht neben dem Status', (tester) async {
    await tester.pumpWidget(
      rahmen(
        EinsatzZeile(
          einsatz: einsatz(
            typ: EinsatzTyp.stoerung,
            kennzeichen: EinsatzKennzeichen.nichtBehebbar,
            betrag: 94.05,
          ),
          onTap: () {},
        ),
      ),
    );
    expect(find.text('nicht behebbar'), findsOneWidget);
  });

  testWidgets('Beschreibung der Stoerung erscheint in der zweiten Zeile', (
    tester,
  ) async {
    await tester.pumpWidget(
      rahmen(
        EinsatzZeile(
          einsatz: einsatz(
            typ: EinsatzTyp.stoerung,
            beschreibung: 'Zapfhahn tropft',
          ),
          onTap: () {},
        ),
      ),
    );
    expect(find.textContaining('Zapfhahn tropft'), findsOneWidget);
  });

  testWidgets('Tipp loest onTap aus', (tester) async {
    var getippt = false;
    await tester.pumpWidget(
      rahmen(EinsatzZeile(einsatz: einsatz(), onTap: () => getippt = true)),
    );
    await tester.tap(find.text('Calanda'));
    expect(getippt, isTrue);
  });

  testWidgets('passt auf 360 px, Betriebsname wird nicht gekuerzt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      rahmen(
        EinsatzZeile(
          einsatz: einsatz(
            name: 'Seerestaurant Schlüssel',
            status: EinsatzStatus.verrechnet,
            betrag: 1234.55,
          ),
          onTap: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final absatz = tester.renderObject<RenderParagraph>(
      find.text('Seerestaurant Schlüssel'),
    );
    expect(absatz.didExceedMaxLines, isFalse);
  });

  testWidgets('kein ListTile, kein FilledButton', (tester) async {
    await tester.pumpWidget(
      rahmen(EinsatzZeile(einsatz: einsatz(), onTap: () {})),
    );
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
