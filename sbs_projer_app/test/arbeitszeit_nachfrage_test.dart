import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/arbeitszeit_nachfrage.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

final tag = DateTime(2026, 9, 25);
final spaeter = DateTime(2026, 9, 27, 20, 15);

TagesFahrten fahrtenMit(List<Halt> halte) => TagesFahrten(
  fahrten: const [],
  ohneZeit: const [],
  kmFahrten: 0,
  fahrtenOhneKm: 0,
  kmZaehler: null,
  befunde: const [],
  halte: halte,
);

/// Arbeitsbeginn 07:30, Reinigung am Betrieb der Störung 09:22–10:47,
/// Feierabend 17:00.
final kette = [
  const Halt(
    typ: HaltTyp.startort,
    id: 'domat_ems',
    name: 'Domat/Ems',
    abfahrtMin: 450,
    quelle: 'arbeitsbeginn',
  ),
  const Halt(
    typ: HaltTyp.betrieb,
    id: 'b_stoerung',
    name: 'Rössli',
    ankunftMin: 562,
    abfahrtMin: 647,
    quelle: 'reinigung',
  ),
  const Halt(
    typ: HaltTyp.startort,
    id: 'domat_ems',
    name: 'Domat/Ems',
    ankunftMin: 1020,
    quelle: 'feierabend',
  ),
];

/// Ein Knopf «Speichern», der [beiTap] mit Kontext und Ref ruft.
Widget harness(
  Future<void> Function(BuildContext context, WidgetRef ref) beiTap, {
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    home: Scaffold(
      body: Consumer(
        builder: (context, ref, _) => Center(
          child: TapKnopf(text: 'Speichern', onTap: () => beiTap(context, ref)),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('arbeitszeitNachfrageNoetig', () {
    bool noetig({
      bool wirdErledigt = true,
      bool vorOrt = true,
      String von = '',
      String bis = '',
      bool verzichtet = false,
    }) => arbeitszeitNachfrageNoetig(
      wirdErledigt: wirdErledigt,
      vorOrt: vorOrt,
      arbeitVon: von,
      arbeitBis: bis,
      verzichtet: verzichtet,
    );

    test('erledigt, vor Ort, beide Zeiten leer → fragen', () {
      expect(noetig(), isTrue);
      expect(noetig(von: '  ', bis: ''), isTrue); // Leerzeichen zählen nicht
    });

    test('bleibt geplant → nicht fragen', () {
      expect(noetig(wirdErledigt: false), isFalse);
    });

    test(
      'kein Besuch vor Ort (Kilometerabrechnung, Spesen) → nicht fragen',
      () {
        expect(noetig(vorOrt: false), isFalse);
      },
    );

    test('nur eine Zeit fehlt → nicht fragen (der Block zeigt es)', () {
      expect(noetig(von: '08:00'), isFalse);
      expect(noetig(bis: '09:00'), isFalse);
      expect(noetig(von: '08:00', bis: '09:00'), isFalse);
    });

    test('früher «Ohne Zeit» gewählt → nicht fragen', () {
      expect(noetig(verzichtet: true), isFalse);
    });
  });

  group('Verzicht merken (shared_preferences)', () {
    test('je Plan-Id, Störung und Montage getrennt', () async {
      expect(await arbeitszeitVerzichtet('s_42'), isFalse);
      await arbeitszeitVerzichtMerken('s_42');
      expect(await arbeitszeitVerzichtet('s_42'), isTrue);
      expect(await arbeitszeitVerzichtet('m_42'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('arbeitszeit_verzicht_s_42'), isTrue);
    });
  });

  group('Dialog', () {
    Future<void> oeffnen(
      WidgetTester tester, {
      ({String von, String bis})? vorschlag,
      required void Function(ArbeitszeitNachfrageErgebnis?) ergebnis,
    }) async {
      await tester.pumpWidget(
        harness((context, _) async {
          ergebnis(
            await zeigeArbeitszeitNachfrage(context, vorschlag: vorschlag),
          );
        }),
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
    }

    testWidgets('Vorschlag vorbelegt, «Übernehmen» liefert die Zeiten', (
      tester,
    ) async {
      ArbeitszeitNachfrageErgebnis? antwort;
      await oeffnen(
        tester,
        vorschlag: (von: '09:00', bis: '10:00'),
        ergebnis: (e) => antwort = e,
      );
      expect(find.text('Arbeitszeit?'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(
        find.textContaining('Vorschlag aus dem Tagesplan'),
        findsOneWidget,
      );

      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(antwort?.wahl, ArbeitszeitWahl.uebernommen);
      expect(antwort?.von, '09:00');
      expect(antwort?.bis, '10:00');
    });

    testWidgets('«Ohne Zeit» liefert den Verzicht', (tester) async {
      ArbeitszeitNachfrageErgebnis? antwort;
      await oeffnen(
        tester,
        vorschlag: (von: '09:00', bis: '10:00'),
        ergebnis: (e) => antwort = e,
      );
      await tester.tap(find.text('Ohne Zeit'));
      await tester.pumpAndSettle();
      expect(antwort?.wahl, ArbeitszeitWahl.ohneZeit);
      expect(antwort?.von, isNull);
    });

    testWidgets('ohne Vorschlag: leere Felder, «Übernehmen» gesperrt', (
      tester,
    ) async {
      var aufgerufen = false;
      await oeffnen(tester, ergebnis: (_) => aufgerufen = true);
      expect(find.textContaining('Kein Vorschlag möglich'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      final knopf = tester.widget<TapKnopf>(
        find.widgetWithText(TapKnopf, 'Übernehmen'),
      );
      expect(knopf.onTap, isNull);
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(find.text('Arbeitszeit?'), findsOneWidget); // bleibt offen
      expect(aufgerufen, isFalse);
    });

    testWidgets('bis vor von = über Mitternacht, erlaubt mit Hinweis', (
      tester,
    ) async {
      ArbeitszeitNachfrageErgebnis? antwort;
      await oeffnen(
        tester,
        vorschlag: (von: '23:30', bis: '00:30'),
        ergebnis: (e) => antwort = e,
      );
      expect(find.textContaining('Über Mitternacht'), findsOneWidget);
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(antwort?.wahl, ArbeitszeitWahl.uebernommen);
    });

    testWidgets('weggetippt → null (zurück ins Formular)', (tester) async {
      var aufgerufen = false;
      ArbeitszeitNachfrageErgebnis? antwort =
          const ArbeitszeitNachfrageErgebnis(ArbeitszeitWahl.nichtGefragt);
      await oeffnen(
        tester,
        vorschlag: (von: '09:00', bis: '10:00'),
        ergebnis: (e) {
          aufgerufen = true;
          antwort = e;
        },
      );
      await tester.tapAt(const Offset(5, 5)); // neben den Dialog
      await tester.pumpAndSettle();
      expect(aufgerufen, isTrue);
      expect(antwort, isNull);
    });

    testWidgets('Zeitfeld öffnet die 24-h-Zeitauswahl', (tester) async {
      await oeffnen(
        tester,
        vorschlag: (von: '09:00', bis: '10:00'),
        ergebnis: (_) {},
      );
      await tester.tap(find.byKey(const Key('arbeitszeit_nachfrage_von')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      final mq = tester.widget<MediaQuery>(
        find
            .ancestor(
              of: find.byType(TimePickerDialog),
              matching: find.byType(MediaQuery),
            )
            .first,
      );
      expect(mq.data.alwaysUse24HourFormat, isTrue);
    });
  });

  group('arbeitszeitBeimAbschliessen', () {
    // Gesetzt, sobald der Ablauf zu Ende ist (nach dem Schliessen des
    // Dialogs) — deshalb ausserhalb von `ablauf` gelesen.
    ArbeitszeitNachfrageErgebnis? ergebnis;
    setUp(() => ergebnis = null);

    Future<ArbeitszeitNachfrageErgebnis?> ablauf(
      WidgetTester tester, {
      bool noetig = true,
      String? planId = 's_1',
      List<Halt>? halte,
      String? tippen,
    }) async {
      await tester.pumpWidget(
        harness(
          (context, ref) async {
            ergebnis = await arbeitszeitBeimAbschliessen(
              context,
              ref,
              noetig: noetig,
              planId: planId,
              datum: tag,
              betriebId: 'b_stoerung',
              geplanteDauerMin: 60,
              jetzt: spaeter,
            );
          },
          overrides: [
            tagesFahrtenProvider.overrideWith(
              (ref, d) async => halte == null ? null : fahrtenMit(halte),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      if (tippen != null) {
        await tester.tap(find.text(tippen));
        await tester.pumpAndSettle();
      }
      return ergebnis;
    }

    testWidgets('Vorschlag aus der Kette des Tages im Dialog', (tester) async {
      final e = await ablauf(tester, halte: kette, tippen: 'Übernehmen');
      expect(e?.wahl, ArbeitszeitWahl.uebernommen);
      expect((e?.von, e?.bis), ('09:22', '10:47'));
    });

    testWidgets('kein Tagesplan (vergangener Tag) → leere Felder', (
      tester,
    ) async {
      await ablauf(tester);
      expect(find.text('Arbeitszeit?'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('nicht nötig → kein Dialog', (tester) async {
      final e = await ablauf(tester, noetig: false, halte: kette);
      expect(find.text('Arbeitszeit?'), findsNothing);
      expect(e?.wahl, ArbeitszeitWahl.nichtGefragt);
    });

    testWidgets('schon verzichtet → kein Dialog', (tester) async {
      SharedPreferences.setMockInitialValues({
        'arbeitszeit_verzicht_s_1': true,
      });
      final e = await ablauf(tester, halte: kette);
      expect(find.text('Arbeitszeit?'), findsNothing);
      expect(e?.wahl, ArbeitszeitWahl.nichtGefragt);
    });

    testWidgets('neuer Einsatz (ohne Id) wird immer gefragt', (tester) async {
      SharedPreferences.setMockInitialValues({
        'arbeitszeit_verzicht_s_1': true,
      });
      final e = await ablauf(
        tester,
        planId: null,
        halte: kette,
        tippen: 'Ohne Zeit',
      );
      expect(e?.wahl, ArbeitszeitWahl.ohneZeit);
    });

    testWidgets('weggetippt → abgebrochen', (tester) async {
      await ablauf(tester, halte: kette);
      expect(ergebnis, isNull); // Dialog noch offen
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(ergebnis?.wahl, ArbeitszeitWahl.abgebrochen);
    });

    testWidgets('Ladefehler → Dialog trotzdem, ohne Kette', (tester) async {
      await tester.pumpWidget(
        harness(
          (context, ref) async {
            ergebnis = await arbeitszeitBeimAbschliessen(
              context,
              ref,
              noetig: true,
              planId: 's_1',
              datum: tag,
              betriebId: 'b_stoerung',
              geplanteDauerMin: 60,
              jetzt: spaeter,
            );
          },
          overrides: [
            tagesFahrtenProvider.overrideWith(
              (ref, d) async => throw StateError('offline'),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Arbeitszeit?'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(ergebnis?.wahl, ArbeitszeitWahl.abgebrochen);
    });
  });

  // Review M4: Der «Erledigt»-Knopf der Detailseite setzte nur das Ende.
  group('erledigtZeitenBestimmen («Erledigt» auf der Detailseite)', () {
    // Wie oben: erst nach dem Schliessen des Dialogs gesetzt.
    ({String? von, String bis})? zeiten;
    var fertig = false;
    setUp(() {
      zeiten = null;
      fertig = false;
    });

    Future<void> erledigt(
      WidgetTester tester, {
      String? von,
      String? bis,
      bool vorOrt = true,
      List<Halt>? halte,
    }) async {
      await tester.pumpWidget(
        harness(
          (context, ref) async {
            zeiten = await erledigtZeitenBestimmen(
              context,
              ref,
              planId: 's_7',
              arbeitVon: von,
              arbeitBis: bis,
              vorOrt: vorOrt,
              betriebId: 'b_stoerung',
              geplanteDauerMin: 60,
              jetzt: spaeter,
            );
            fertig = true;
          },
          overrides: [
            tagesFahrtenProvider.overrideWith(
              (ref, d) async => halte == null ? null : fahrtenMit(halte),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
    }

    testWidgets('beide Zeiten fehlen → Nachfrage statt Bestätigung, '
        '«Übernehmen» speichert Beginn UND Ende', (tester) async {
      await erledigt(tester, halte: kette);
      expect(find.text('Arbeitszeit?'), findsOneWidget);
      expect(find.textContaining('Einsatz als erledigt'), findsNothing);
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(zeiten, (von: '09:22', bis: '10:47'));
      expect(find.textContaining('Einsatz als erledigt'), findsNothing);
    });

    testWidgets('«Ohne Zeit» → Ende jetzt wie bisher, Verzicht gemerkt', (
      tester,
    ) async {
      await erledigt(tester, halte: kette);
      await tester.tap(find.text('Ohne Zeit'));
      await tester.pumpAndSettle();
      expect(zeiten, (von: null, bis: '20:15'));
      expect(await arbeitszeitVerzichtet('s_7'), isTrue);
    });

    testWidgets('Nachfrage weggetippt → nichts speichern', (tester) async {
      await erledigt(tester, halte: kette);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(fertig, isTrue);
      expect(zeiten, isNull);
    });

    testWidgets('Beginn schon erfasst → Bestätigung (TapKnopf), Ende jetzt', (
      tester,
    ) async {
      await erledigt(tester, von: '08:05', halte: kette);
      expect(find.text('Arbeitszeit?'), findsNothing);
      expect(find.textContaining('Einsatz als erledigt'), findsOneWidget);
      // CanvasKit: keine Material-Knöpfe im Dialog (Ratsche).
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.widgetWithText(TapKnopf, 'Erledigt'), findsOneWidget);
      await tester.tap(find.widgetWithText(TapKnopf, 'Erledigt'));
      await tester.pumpAndSettle();
      expect(zeiten, (von: '08:05', bis: '20:15'));
    });

    testWidgets('Bestätigung abgebrochen → nichts speichern', (tester) async {
      await erledigt(tester, von: '08:05');
      await tester.tap(find.widgetWithText(TapKnopf, 'Abbrechen'));
      await tester.pumpAndSettle();
      expect(fertig, isTrue);
      expect(zeiten, isNull);
    });

    testWidgets('kein Besuch vor Ort (Kilometerabrechnung) → nur Bestätigung', (
      tester,
    ) async {
      await erledigt(tester, vorOrt: false);
      expect(find.text('Arbeitszeit?'), findsNothing);
      await tester.tap(find.widgetWithText(TapKnopf, 'Erledigt'));
      await tester.pumpAndSettle();
      expect(zeiten, (von: null, bis: '20:15'));
    });

    testWidgets('früher «Ohne Zeit» → nur Bestätigung', (tester) async {
      SharedPreferences.setMockInitialValues({
        'arbeitszeit_verzicht_s_7': true,
      });
      await erledigt(tester, halte: kette);
      expect(find.text('Arbeitszeit?'), findsNothing);
      expect(find.textContaining('Einsatz als erledigt'), findsOneWidget);
    });
  });
}
