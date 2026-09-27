import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

/// Ferien-Ladefehler (Entscheid 27.09.2026): Die Betriebe bleiben sichtbar —
/// sie sind der Kern der App (Störung, Rechnung, Suche) —, tragen dann aber
/// KEINE Ferien (`ferienPerioden = null`). Das bleibt nicht still: Die
/// dringende Aufgabe «Ferien nicht geladen» steht auf Heute-Karte und Glocke.
void main() {
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

    // Die Aktion «Erneut laden» (kFerienNeuLadenAktion) invalidiert beide.
    offline = false;
    c.invalidate(ferienPeriodenProvider);
    c.invalidate(betriebeStreamProvider);
    final betriebe = await c.read(betriebeStreamProvider.future);
    await ferienAbwarten(c);

    expect(betriebe.every((b) => b.ferienPerioden != null), isTrue);
    expect(istInFerien(betriebe[0], DateTime(2026, 8, 1)), isTrue);
    expect(c.read(ferienLadefehlerProvider), isNull);
  });
}
