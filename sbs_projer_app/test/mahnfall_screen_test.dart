import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/mahnfall_providers.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/mahnfall_screen.dart';

/// Das Arbeitsblatt rendert bei Smartphone-Breite (360 px) ohne Overflow —
/// je Status die passenden Blöcke.
void main() {
  Mahnfall fall(String status, {bool? rechtsvorschlag, String? erledigung, String? notiz}) =>
      Mahnfall(
        id: 'f1',
        userId: 'u',
        betriebId: 'b1',
        rechnungIds: const ['r1', 'r2'],
        eroeffnetAm: DateTime.utc(2026, 10, 1),
        status: status,
        test: true,
        heinekenKontaktAm: DateTime.utc(2026, 10, 1),
        heinekenEmpfaenger: 'mahnwesen@heineken.example',
        heinekenErgebnis: status == 'heineken' ? null : 'betreibung',
        schuldnerName: 'Gastro Muster GmbH mit einem sehr langen Namen',
        schuldnerAdresse: 'Bahnhofstrasse 1, 7000 Chur',
        rechtsform: 'einzelfirma',
        zahlungsbefehlAm: DateTime.utc(2026, 11, 20),
        rechtsvorschlag: rechtsvorschlag,
        kostenVorschuss: 20,
        erledigung: erledigung,
        notiz: notiz,
        erstelltAm: DateTime.utc(2026, 10, 1),
        aktualisiertAm: DateTime.utc(2026, 10, 1),
      );

  Rechnung r(String id, String status) => Rechnung(
        id: id,
        userId: 'u',
        rechnungsnummer: 'RE-2026-0$id',
        rechnungstyp: 'kundenrechnung',
        rechnungsdatum: DateTime.utc(2026, 3, 4),
        faelligkeitsdatum: DateTime.utc(2026, 4, 3),
        betragBrutto: 250.25,
        zahlungsstatus: status,
        mahnungStufe: 3,
        erinnerungAm: DateTime.utc(2026, 5, 2),
      );

  Future<void> zeige(WidgetTester t, Mahnfall f, List<Rechnung> rs) async {
    t.view.physicalSize = const Size(360, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [
        mahnfallProvider('f1').overrideWith((ref) async => f),
        mahnfallRechnungenProvider('f1').overrideWith((ref) async => rs),
        protokollPfadeZuRechnungProvider.overrideWith((ref, id) async => ['u/x/1.pdf', 'u/x/2.pdf']),
        betriebAnzeigeMapProvider.overrideWithValue({'b1': 'Restaurant Muster, Chur'}),
      ],
      child: const MaterialApp(home: MahnfallScreen(id: 'f1')),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('Status heineken: vier Ergebnis-Knöpfe, Zurücknehmen', (t) async {
    await zeige(t, fall('heineken'), [r('1', 'mahnung_2'), r('2', 'mahnung_2')]);
    expect(t.takeException(), isNull);
    expect(find.text('Vermittelt — Kunde zahlt'), findsOneWidget);
    expect(find.text('Kunde in Konkurs — abschreiben'), findsOneWidget);
    expect(find.text('Mail an Heineken erneut senden'), findsOneWidget);
    expect(find.text('Fall zurücknehmen'), findsOneWidget);
    expect(find.text('CHF 500.50'), findsOneWidget);
  });

  testWidgets('Status betreibung mit Rechtsvorschlag: Datenblatt, Fenster, Protokolle', (t) async {
    await zeige(t, fall('betreibung', rechtsvorschlag: true),
        [r('1', 'mahnung_2'), r('2', 'mahnung_2')]);
    expect(t.takeException(), isNull);
    expect(find.text('Datenblatt zum Abtippen in EasyGov'), findsOneWidget);
    expect(find.textContaining('Wohnsitz des Inhabers'), findsOneWidget);
    expect(find.text('nebst 5 % Zins seit 02.05.2026'), findsNWidgets(2),
        reason: 'Zinszeile je Forderung (M-1)');
    expect(find.textContaining('zuerst Rechtsöffnung'), findsOneWidget);
    expect(find.textContaining('Fortsetzung möglich ab'), findsNothing,
        reason: 'mit Rechtsvorschlag kein Fortsetzungsfenster (M-6)');
    expect(find.text('Protokoll 2'), findsNWidgets(2));
    expect(find.text('Erledigt: abgeschrieben'), findsOneWidget);
  });

  testWidgets('ohne Rechtsvorschlag: Fortsetzungsfenster (M-6)', (t) async {
    await zeige(t, fall('betreibung', rechtsvorschlag: false), [r('1', 'mahnung_2')]);
    expect(t.takeException(), isNull);
    expect(find.text('Fortsetzung möglich ab 10.12.2026, spätestens bis 20.11.2027.'),
        findsOneWidget);
    expect(find.textContaining('zuerst Rechtsöffnung'), findsNothing);
  });

  testWidgets('erledigt, Übernahme offen: orange Karte, kein Abschluss, Notiz ohne Markierung', (t) async {
    await zeige(
      t,
      fall('erledigt', erledigung: 'uebernommen', notiz: 'x\n[UEBERNAHME OFFEN]'),
      [r('1', 'bezahlt'), r('2', 'bezahlt')],
    );
    expect(t.takeException(), isNull);
    expect(find.text('Übernahme ist verbucht'), findsOneWidget);
    expect(find.text('Fall abschliessen (bezahlt)'), findsNothing,
        reason: 'erledigter Fall bietet keinen Abschluss mehr an');
    final notiz = t.widget<TextField>(find.byType(TextField).last);
    expect(notiz.controller!.text, 'x', reason: 'Markierung nicht im Textfeld');
  });
}
