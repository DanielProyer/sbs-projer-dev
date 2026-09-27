import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/core/util/tourenplan_refresh.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

/// Ferien-Ladefehler (Entscheid 27.09.2026): Die Betriebe bleiben sichtbar —
/// sie sind der Kern der App (Störung, Rechnung, Suche) —, tragen dann aber
/// KEINE Ferien (`ferienPerioden = null`). Das bleibt nicht still: Die
/// dringende Aufgabe «Ferien nicht geladen» steht auf Heute-Karte und Glocke,
/// lässt sich nicht wegschieben (K3), und der Tourenplan zeigt ein Band (M3).
void main() {
  // Globale Marke aus betrieb_ferien.dart — jeder Test beginnt ohne Fehler.
  setUp(() => ferienLadefehlerAktiv = false);

  List<BetriebLocal> rohBetriebe() => [
    BetriebLocal()
      ..serverId = 'b1'
      ..name = 'Calanda',
    BetriebLocal()
      ..serverId = 'b2'
      ..name = 'Flora',
  ];

  final FerienPeriodenMap ferien = {
    'b1': [(von: DateTime(2026, 7, 20), bis: DateTime(2026, 8, 10))],
  };

  /// [ferienLaden] liefert die Map oder wirft — pro Ladeversuch neu gefragt.
  ProviderContainer container(Future<FerienPeriodenMap> Function() ferienLaden) {
    final c = ProviderContainer(
      overrides: [
        betriebeQuelleProvider.overrideWithValue(
          () => Stream.value(rohBetriebe()),
        ),
        ferienPeriodenProvider.overrideWith((ref) => ferienLaden()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Den Ferien-Ladeversuch abwarten, egal ob er gelingt.
  Future<void> ferienAbwarten(ProviderContainer c) async {
    try {
      await c.read(ferienPeriodenProvider.future);
    } catch (_) {}
  }

  test('ohne Ladefehler: Ferien gesetzt, kein Fehler, keine Aufgabe',
      () async {
    final c = container(() async => ferien);
    final betriebe = await c.read(betriebeStreamProvider.future);

    expect(betriebe, hasLength(2));
    expect(betriebe.every((b) => b.ferienPerioden != null), isTrue);
    expect(istInFerien(betriebe[0], DateTime(2026, 8, 1)), isTrue);
    expect(betriebe[1].ferienPerioden, isEmpty);

    expect(c.read(ferienLadefehlerProvider), isNull);
    expect(ferienLadefehlerAufgabe(c.read(ferienLadefehlerProvider)), isNull);
  });

  test('mit Ladefehler: Betriebe da, Perioden null, Aufgabe aktiv', () async {
    final c = container(() async => throw StateError('offline'));
    final betriebe = await c.read(betriebeStreamProvider.future);
    await ferienAbwarten(c);

    // Betriebe bleiben sichtbar …
    expect(betriebe.map((b) => b.name), ['Calanda', 'Flora']);
    expect(c.read(betriebeProvider), hasLength(2));
    // … aber «Ferien unbekannt», nicht «keine Ferien».
    expect(betriebe.every((b) => b.ferienPerioden == null), isTrue);

    final fehler = c.read(ferienLadefehlerProvider);
    expect(fehler, contains('offline'));

    final a = ferienLadefehlerAufgabe(fehler)!;
    expect(a.dringend, isTrue);
    expect(a.draussen, isTrue);
    expect(a.istVorrat, isFalse);
    expect(a.route, kFerienNeuLadenAktion);
    expect(a.titel, startsWith('Ferien nicht geladen'));

    // Heute-Karte UND Glocke.
    final heute = DateTime(2026, 9, 27);
    final liste = baueAufgabenListe(
      detektoren: [a],
      aufgabenZeilen: const [],
      anstehend: const [],
      saisonVorschlaege: const [],
      saisonTermine: const [],
      aenderungsVorschlaege: 0,
      heute: heute,
    );
    final jetzt = liste.where((e) => jetztFaellig(e, heute)).toList();
    expect(jetzt.map((e) => e.key), contains('ferien_ladefehler'));
    expect(
      fuerHeuteKarte(jetzt).map((e) => e.key),
      contains('ferien_ladefehler'),
    );
  });

  test('erneut laden nach dem Fehler: Ferien kommen, Aufgabe verschwindet',
      () async {
    var offline = true;
    final c = container(() async {
      if (offline) throw StateError('offline');
      return ferien;
    });
    await c.read(betriebeStreamProvider.future);
    await ferienAbwarten(c);
    expect(c.read(ferienLadefehlerProvider), isNotNull);

    // «Erneut laden» (Aufgabe wie Tourenplan-Band) lädt Ferien UND Betriebe.
    offline = false;
    ferienNeuLaden(c.invalidate);
    final betriebe = await c.read(betriebeStreamProvider.future);
    await ferienAbwarten(c);

    expect(betriebe.every((b) => b.ferienPerioden != null), isTrue);
    expect(istInFerien(betriebe[0], DateTime(2026, 8, 1)), isTrue);
    expect(c.read(ferienLadefehlerProvider), isNull);
    expect(ferienLadefehlerAktiv, isFalse);
  });

  // M1 (Review 27.09.2026): Das assert in ferienSlots warf beim VORGESEHENEN
  // Ladefehler — im Debug fielen Betriebsliste und Aufgabenliste aus,
  // ausgerechnet samt «Ferien nicht geladen».
  test('mit Ladefehler: Ferien auswerten wirft nicht (kein assert)', () async {
    final c = container(() async => throw StateError('offline'));
    final betriebe = await c.read(betriebeStreamProvider.future);
    await ferienAbwarten(c);

    expect(ferienLadefehlerAktiv, isTrue);
    expect(istInFerien(betriebe[0], DateTime(2026, 8, 1)), isFalse);
    expect(wirksameFerienSlots(betriebe[1]), isEmpty);
  });

  // K3 (Review 27.09.2026): «Ferien nicht geladen» drei Tage wegschieben
  // hiesse drei Tage Tourenplan ohne Ferien.
  group('«Ferien nicht geladen» lässt sich nicht wegschieben', () {
    final heute = DateTime(2026, 9, 27);
    final aufgabe = ferienLadefehlerAufgabe('offline')!;
    const andere = Aufgabe(key: 'saisondaten', titel: 'Saisondaten');

    List<AufgabenEintrag> liste(List<Map<String, dynamic>> zeilen) =>
        baueAufgabenListe(
          detektoren: [aufgabe, andere],
          aufgabenZeilen: zeilen,
          anstehend: const [],
          saisonVorschlaege: const [],
          saisonTermine: const [],
          aenderungsVorschlaege: 0,
          heute: heute,
        );

    test('kein Snooze-Knopf', () {
      final eintraege = liste(const []);
      final ferienEintrag =
          eintraege.singleWhere((e) => e.key == kFerienLadefehlerKey);
      expect(ferienEintrag.snoozebar, isFalse);
      // Gegenprobe: ein gewöhnlicher Detektor bleibt snoozebar.
      expect(eintraege.singleWhere((e) => e.key == 'saisondaten').snoozebar,
          isTrue);
    });

    test('eine Snooze-Zeile blendet sie nicht aus', () {
      Map<String, dynamic> snooze(String key) => {
        'typ': 'snooze',
        'key': key,
        'snooze_bis': '2026-09-30',
      };
      final keys = liste([
        snooze(kFerienLadefehlerKey),
        snooze('saisondaten'),
      ]).map((e) => e.key);
      expect(keys, contains(kFerienLadefehlerKey));
      expect(keys, isNot(contains('saisondaten')));
    });
  });

  // M3 (Review 27.09.2026): Die Aufgabe stand in Glocke und Heute-Karte,
  // aber im Tourenplan — wo die falsche Planung entsteht — plante man
  // ahnungslos weiter.
  group('Wächter: Tourenplan zeigt das Ferien-Band', () {
    String ohneKommentare(String pfad) => File(
      pfad,
    ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

    final screen = ohneKommentare(
      'lib/presentation/screens/touren/tourenplanung_screen.dart',
    );

    test('Band hängt am ferienLadefehlerProvider', () {
      expect(
        screen,
        contains('final ferienLadefehler = ref.watch(ferienLadefehlerProvider);'),
      );
      expect(
        RegExp(
          r'if \(ferienLadefehler != null\)\s*_ferienLadefehlerBand\(',
        ).hasMatch(screen),
        isTrue,
      );
    });

    test('Band: Text und «Erneut laden» über die gemeinsame Hilfsfunktion',
        () {
      final start = screen.indexOf('Widget _ferienLadefehlerBand(');
      expect(start, isNot(-1));
      final band = screen.substring(start, screen.indexOf('bool _planBereit('));
      expect(
        band,
        contains("'Ferien nicht geladen — Betriebe könnten geschlossen sein'"),
      );
      expect(band, contains('TapKnopf('));
      expect(band, contains("text: 'Erneut laden'"));
      expect(band, contains('ferienNeuLaden(ref.invalidate)'));
    });

    test('Aufgaben-Aktion nutzt dieselbe Hilfsfunktion', () {
      final aktionen = ohneKommentare(
        'lib/presentation/widgets/aufgaben_aktionen.dart',
      );
      expect(aktionen, contains('ferienNeuLaden(ref.invalidate)'));
      expect(aktionen, isNot(contains('ref.invalidate(ferienPeriodenProvider)')));
    });
  });
}
