import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/heute_liste.dart';

TourEintrag stopp(String name, {String? ort, List<String> anlagen = const ['a1']}) =>
    TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: 'r_$name',
      betriebId: 'b_$name',
      anlageId: anlagen.first,
      anlageIds: anlagen,
      betriebName: name,
      betriebOrt: ort,
      beschreibung: '',
    );

// Bildet den echten Einbettungskontext nach: `home_screen.dart` legt diese
// Karte in ein ListView (unbegrenzte Höhe je Kachel), nicht in ein nacktes
// Scaffold mit Bildschirmhöhe. Nur so prüft der 13-Stopps-Test dieselbe
// Constraint-Situation wie die Startseite.
Widget rahmen(Widget kind) => MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [kind],
        ),
      ),
    );

void main() {
  testWidgets('zeigt Betrieb und Ort je Stopp', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda', ort: 'Chur')],
      erledigt: 0,
      gesamt: 1,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Calanda'), findsOneWidget);
    expect(find.textContaining('Chur'), findsOneWidget);
  });

  testWidgets('zeigt alle 13 Stopps — keine Kuerzung', (tester) async {
    final viele = [for (var i = 1; i <= 13; i++) stopp('Betrieb $i')];

    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: viele,
      erledigt: 0,
      gesamt: 13,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Betrieb 1'), findsOneWidget);
    expect(find.text('Betrieb 13'), findsOneWidget);
  });

  testWidgets('Kopfzeile zeigt den Fortschritt', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 3,
      gesamt: 4,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.textContaining('3 von 4'), findsOneWidget);
  });

  testWidgets('ohne Plan erscheint der Leerzustand', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: const [],
      erledigt: 0,
      gesamt: 0,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Kein Tagesplan für heute'), findsOneWidget);
    expect(find.text('Plan erstellen'), findsOneWidget);
  });

  testWidgets('alles erledigt ist nicht derselbe Zustand wie kein Plan', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: const [],
      erledigt: 9,
      gesamt: 9,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Kein Tagesplan für heute'), findsNothing);
    expect(find.textContaining('Alles erledigt'), findsOneWidget);
  });

  testWidgets('Start-Pfeil meldet den Stopp', (tester) async {
    TourEintrag? gestartet;

    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      onStart: (e) => gestartet = e,
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    await tester.tap(find.byKey(const Key('heute_start_r_Calanda')));
    await tester.pump();

    expect(gestartet?.betriebName, 'Calanda');
  });

  testWidgets('kein ListTile und kein FilledButton', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('Monatsumsatz erscheint in der Kopfzeile', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      monatsUmsatzCHF: 12345,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.textContaining('12345 CHF / Monat'), findsOneWidget);
  });

  testWidgets('ohne Monatsumsatz steht nichts in der Kopfzeile', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.textContaining('CHF / Monat'), findsNothing);
  });

  // Der Tagesumsatz stand in der alten Tagesuebersicht und ging beim Umbau
  // auf die Heute-Liste zuerst verloren (Daniel 14.09.2026: «was mir in der
  // App noch fehlt ist ein Ueberblick ueber den Tagesumsatz wie wir ihn
  // vorher hatten»).
  testWidgets('Tagesumsatz erscheint in der Kopfzeile', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 3,
      gesamt: 4,
      tagesUmsatzCHF: 775.15,
      monatsUmsatzCHF: 8316,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.textContaining('775 CHF heute'), findsOneWidget);
    expect(find.textContaining('8316 CHF / Monat'), findsOneWidget);
  });

  testWidgets('Kopfzeile passt auf 360 px (Pixel 9)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Seerestaurant Schlüssel da Andrea', ort: 'Tschiertschen')],
      erledigt: 13,
      gesamt: 13,
      tagesUmsatzCHF: 1234.55,
      monatsUmsatzCHF: 18316,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(tester.takeException(), isNull,
        reason: 'Kopfzeile laeuft mit langen Zahlen und «13 von 13» ueber');
  });

  testWidgets('ohne Tagesumsatz steht morgens nur der Monat da', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 9,
      monatsUmsatzCHF: 8316,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.textContaining('CHF heute'), findsNothing);
    expect(find.textContaining('8316 CHF / Monat'), findsOneWidget);
  });

  testWidgets('Liste hat keinen eigenen Scrollbereich', (tester) async {
    final viele = [for (var i = 1; i <= 13; i++) stopp('Betrieb $i')];
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: viele,
      erledigt: 0,
      gesamt: 13,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(
      find.descendant(
        of: find.byType(HeuteListeInhalt),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
      reason:
          'Entscheid Daniel 13.09.2026: morgens sollen alle offenen Stopps '
          'sichtbar sein. Ein eigener Scrollbereich in der Karte waere die '
          'verworfene Kuerzung mit Scrollbalken - und faengt auf dem Handy '
          'die Wischgeste der Startseite ab.',
    );
  });
}
