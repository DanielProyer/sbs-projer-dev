import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';
import 'package:sbs_projer_app/presentation/screens/auswertungen/tages_fahrten_screen.dart';
import 'package:sbs_projer_app/presentation/widgets/rueckweg_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Detail-Screen «Fahrten eines Tages» (Task 4): Kopfkarte mit Zähler-
/// Kontrolle, Befunde, eine Karte je Fahrt, Einsätze ohne Zeit — auf 360 px
/// ohne Überlauf und ohne Material-Knöpfe.

const _domat = Halt(
  typ: HaltTyp.startort,
  id: 'domat_ems',
  name: 'Domat/Ems',
  lat: 46.8328452,
  lng: 9.4529918,
  abfahrtMin: 7 * 60 + 30,
  quelle: 'arbeitsbeginn',
);
const _peppino = Halt(
  typ: HaltTyp.betrieb,
  id: 'a',
  name: 'Peppino',
  lat: 46.85,
  lng: 9.53,
  ankunftMin: 8 * 60,
  abfahrtMin: 8 * 60 + 45,
  quelle: 'reinigung',
);
const _hollaender = Halt(
  typ: HaltTyp.betrieb,
  id: 'b',
  name: 'Restaurant Holländer mit sehr langem Namen am Dorfplatz',
  lat: 46.80,
  lng: 9.83,
  ankunftMin: 9 * 60 + 32,
  abfahrtMin: 10 * 60,
  quelle: 'wegpunkt',
);
const _heim = Halt(
  typ: HaltTyp.startort,
  id: 'domat_ems',
  name: 'Domat/Ems',
  lat: 46.8328452,
  lng: 9.4529918,
  ankunftMin: 17 * 60,
  quelle: 'feierabend',
);

/// Peppino ↔ Domat/Ems aus den Anfahrten, Peppino → Holländer geroutet,
/// Heimweg nur Luftlinie.
({double km, String quelle})? _km(Halt von, Halt nach) {
  if (von.id == 'domat_ems' && nach.id == 'a') {
    return (km: 12.0, quelle: kKmQuelleAnfahrt);
  }
  if (von.id == 'a' && nach.id == 'b') {
    return (km: 31.4, quelle: kKmQuelleRoute);
  }
  return null;
}

final _tag = tagesFahrten(
  halte: const [_domat, _peppino, _hollaender, _heim],
  ohneZeit: const [
    EinsatzHalt(
      einsatzId: 's1',
      typ: 'stoerung',
      betriebId: 'c',
      betriebName: 'Linden',
    ),
    EinsatzHalt(
      einsatzId: 'vergeblich@2026-09-25T19:00:00.000',
      typ: kTypLeerfahrt,
      betriebId: 'd',
      betriebName: 'Sonne',
    ),
  ],
  km: _km,
  kmStart: 50000,
  kmEnde: 50148,
  feierabendErfasst: true,
);

Future<void> _pumpe(
  WidgetTester tester,
  Future<TagesFahrten?> Function() fahrten,
) async {
  // Handybreite: 360 px (Pixel 9 hochkant, Smartphone-first).
  tester.view.physicalSize = const Size(360, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [tagesFahrtenProvider.overrideWith((ref, d) => fahrten())],
      child: MaterialApp(
        home: TagesFahrtenScreen(datum: DateTime(2026, 9, 25, 14, 30)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Kopfkarte, Befunde, Fahrten und Einsätze ohne Zeit', (
    tester,
  ) async {
    await _pumpe(tester, () async => _tag);

    expect(tester.takeException(), isNull); // kein Überlauf auf 360 px
    expect(find.text('Fahrten · Fr 25.09.'), findsOneWidget);
    expect(find.byType(RueckwegKnopf), findsOneWidget);

    // Kopfkarte: Zähler 148, Fahrten 12 + 31.4 + Luftlinie Holländer→Domat.
    expect(find.text('Fahrten-km'), findsOneWidget);
    expect(find.text(kmText(_tag.kmFahrten)), findsOneWidget);
    expect(find.text('148 km'), findsOneWidget);
    expect(find.text('3 (davon 1 geschätzt)'), findsOneWidget);
    final differenz = tester.widget<Text>(find.textContaining('— auffällig'));
    expect(differenz.style?.color, AppColors.error);
    // Richtung der Differenz ist erklärt.
    expect(find.text('Differenz'), findsOneWidget);
    expect(find.text('(Zähler − Fahrten)'), findsOneWidget);
    expect(find.text('+ = mehr gefahren als erklärt'), findsOneWidget);

    // Befunde aus der Regel, Wort für Wort.
    for (final b in _tag.befunde) {
      expect(find.text(b), findsOneWidget);
    }

    // Je Fahrt Zeiten, Weg, km mit Herkunft.
    expect(find.text('07:30 → 08:00 · 30 min'), findsOneWidget);
    expect(find.text('Domat/Ems → Peppino'), findsOneWidget);
    expect(find.text('12.0 km'), findsOneWidget);
    expect(find.text('Anfahrt'), findsOneWidget);
    expect(find.text('31.4 km'), findsOneWidget);
    expect(find.text('geroutet'), findsOneWidget);
    expect(find.text('≈ Luftlinie'), findsOneWidget);
    expect(find.text('10:00 → 17:00 · 420 min'), findsOneWidget);

    // Einsätze ohne Zeit.
    expect(find.text('Einsätze ohne Zeit'), findsOneWidget);
    expect(find.text('Linden'), findsOneWidget);
    expect(find.text('Störung'), findsOneWidget);
    expect(find.text('Sonne'), findsOneWidget);
    expect(find.text('Leerfahrt'), findsOneWidget);
  });

  testWidgets('Differenz im Rahmen: nicht rot', (tester) async {
    final ruhig = tagesFahrten(
      halte: const [_domat, _peppino, _heim],
      ohneZeit: const [],
      km: (von, nach) => (km: 12.0, quelle: kKmQuelleAnfahrt),
      kmStart: 50000,
      kmEnde: 50026,
      feierabendErfasst: true,
    );
    await _pumpe(tester, () async => ruhig);

    final differenz = tester.widget<Text>(find.textContaining('— im Rahmen'));
    expect(differenz.data, '+2.0 km — im Rahmen');
    expect(differenz.style?.color, isNot(AppColors.error));
    // Keine Befunde → keine Befund-Karte.
    expect(find.text('Befunde'), findsNothing);
  });

  testWidgets('kein Tag erfasst: Hinweis statt leerer Seite', (tester) async {
    await _pumpe(tester, () async => null);
    expect(find.textContaining('weder ein Arbeitstag'), findsOneWidget);
  });

  testWidgets('Fehler: kurze Meldung und «Erneut laden» als TapKnopf', (
    tester,
  ) async {
    await _pumpe(tester, () async => throw Exception('Failed to fetch'));
    expect(find.text('Fahrten konnten nicht geladen werden.'), findsOneWidget);
    expect(find.text('keine Verbindung'), findsOneWidget);
    expect(find.widgetWithText(TapKnopf, 'Erneut laden'), findsOneWidget);
  });

  group('Texte', () {
    test('differenzText mit echtem Minus', () {
      expect(differenzText(16.44), '+16.4 km');
      expect(differenzText(-3), '−3.0 km');
    });

    test('differenzText: erst runden, dann Vorzeichen (kein «−0.0»)', () {
      expect(differenzText(0), '±0.0 km');
      expect(differenzText(-0.04), '±0.0 km');
      expect(differenzText(0.04), '±0.0 km');
      expect(differenzText(-0.06), '−0.1 km');
    });

    test('kmQuelleText', () {
      expect(kmQuelleText(kKmQuelleAnfahrt), 'Anfahrt');
      expect(kmQuelleText(kKmQuelleRoute), 'geroutet');
      expect(kmQuelleText(kKmQuelleLuftlinie), '≈ Luftlinie');
      expect(kmQuelleText(null), 'ohne Distanz');
    });

    test('tagesTitel', () {
      expect(tagesTitel(DateTime(2026, 9, 28)), 'Mo 28.09.');
    });
  });
}
