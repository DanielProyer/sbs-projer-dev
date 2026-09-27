import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/eigene_aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_aktionen.dart';
import 'package:sbs_projer_app/presentation/widgets/betrieb/aufgaben_akte_karte.dart';

/// Sektion «Aufgaben (n)» auf der Betriebsseite (Migration 212, Entscheid
/// Daniel 27.09.2026) — am Handy (360 px).

final _heute = DateTime(2026, 9, 27, 10);

final _offen = EigeneAufgabe(
  id: 'o1',
  titel: 'Hahn mitnehmen',
  faelligAm: DateTime(2026, 9, 25),
  betriebId: 'b1',
);
final _erledigt = EigeneAufgabe(
  id: 'e1',
  titel: 'Fass zurücknehmen',
  erledigtAm: DateTime(2026, 9, 26, 9),
  betriebId: 'b1',
);

class _Aufrufe {
  var neu = 0;
  var neuLaden = 0;
  final bearbeitet = <String>[];
  final erledigt = <String>[];
}

Future<_Aufrufe> _zeige(
  WidgetTester tester,
  AsyncValue<List<EigeneAufgabe>> aufgaben,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final r = _Aufrufe();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AufgabenAkteInhalt(
              aufgaben: aufgaben,
              heute: _heute,
              onNeu: () => r.neu++,
              onBearbeiten: (a) => r.bearbeitet.add(a.id),
              onErledigen: (a) => r.erledigt.add(a.id),
              onNeuLaden: () => r.neuLaden++,
            ),
          ],
        ),
      ),
    ),
  );
  return r;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  testWidgets('Titel zählt die offenen; offene mit Kreis, erledigte mit Haken', (
    tester,
  ) async {
    await _zeige(tester, AsyncValue.data([_offen, _erledigt]));
    expect(find.text('Aufgaben (1)'), findsOneWidget);
    expect(find.text('Hahn mitnehmen'), findsOneWidget);
    expect(find.text('überfällig seit 2 Tagen'), findsOneWidget);
    expect(find.text('Fass zurücknehmen'), findsOneWidget);
    expect(find.text('erledigt 26.09.'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«+ Neue Aufgabe», Kreis hakt ab, Zeile bearbeitet', (
    tester,
  ) async {
    final r = await _zeige(tester, AsyncValue.data([_offen, _erledigt]));
    await tester.tap(find.text('Neue Aufgabe'));
    await tester.tap(find.byKey(const Key('aufgabe_erledigen_o1')));
    await tester.tap(find.text('Hahn mitnehmen'));
    await tester.tap(find.text('Fass zurücknehmen'));
    expect(r.neu, 1);
    expect(r.erledigt, ['o1']);
    expect(r.bearbeitet, ['o1', 'e1']);
  });

  testWidgets('erledigte Aufgabe hat keinen Abhaken-Knopf', (tester) async {
    await _zeige(tester, AsyncValue.data([_erledigt]));
    expect(find.byKey(const Key('aufgabe_erledigen_e1')), findsNothing);
    expect(find.text('Aufgaben (0)'), findsOneWidget);
  });

  testWidgets('leer: Hinweis, Anlegen bleibt möglich', (tester) async {
    final r = await _zeige(tester, const AsyncValue.data([]));
    expect(find.text('Aufgaben (0)'), findsOneWidget);
    expect(find.text('Keine offenen Aufgaben'), findsOneWidget);
    await tester.tap(find.text('Neue Aufgabe'));
    expect(r.neu, 1);
  });

  testWidgets('lädt: Titel ohne Zahl', (tester) async {
    await _zeige(tester, const AsyncValue.loading());
    expect(find.text('Aufgaben'), findsOneWidget);
    expect(find.text('Wird geladen …'), findsOneWidget);
  });

  // Review K8: Bis 27.09.2026 schluckte der Provider den Fehler — hier
  // stand dann «Keine offenen Aufgaben».
  testWidgets('Ladefehler: kurze Meldung ohne Rohtext, «Erneut laden»', (
    tester,
  ) async {
    final r = await _zeige(
      tester,
      AsyncValue.error(
        Exception('ClientException: Failed to fetch, uri=https://x/rest/v1'),
        StackTrace.empty,
      ),
    );
    expect(find.text('Aufgaben nicht geladen: keine Verbindung'), findsOneWidget);
    expect(find.textContaining('ClientException'), findsNothing);
    expect(find.text('Keine offenen Aufgaben'), findsNothing);
    await tester.tap(find.text('Erneut laden'));
    expect(r.neuLaden, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('langer Titel am Handy ohne Überlauf', (tester) async {
    await _zeige(
      tester,
      AsyncValue.data([
        EigeneAufgabe(
          id: 'x',
          titel: 'Neuen Kompressor für die Kühlung bestellen und beim '
              'nächsten Besuch den alten mitnehmen, Rechnung an Heineken',
          faelligAm: DateTime(2026, 10, 1),
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keine CanvasKit-toten Widgets', (tester) async {
    await _zeige(tester, AsyncValue.data([_offen, _erledigt]));
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  // Review K7: Der Kreis liegt direkt neben der Zeile — ein Fehlgriff hakte
  // bisher unwiderruflich ab.
  group('Abhaken mit «Rückgängig»', () {
    Future<({List<String> erledigt, List<String> geoeffnet, List<int> laeufe})>
    abhaken(WidgetTester tester, {Object? fehler}) async {
      final erledigt = <String>[];
      final geoeffnet = <String>[];
      final laeufe = [0];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aufgabenZeilenProvider.overrideWith((ref) async {
              laeufe[0]++;
              return const [];
            }),
            draussenAufgabenProvider.overrideWith((ref) async => const []),
            aufgabenListeProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  // hält die Tabelle am Leben — zählt das Neuladen
                  ref.watch(aufgabenZeilenProvider);
                  return GestureDetector(
                    onTap: () => eigeneAufgabeErledigen(
                      context,
                      'o1',
                      erledigen: (id) async {
                        if (fehler != null) throw fehler;
                        erledigt.add(id);
                      },
                      wiederOeffnen: (id) async => geoeffnet.add(id),
                    ),
                    child: const Text('abhaken'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('abhaken'));
      await tester.pumpAndSettle();
      return (erledigt: erledigt, geoeffnet: geoeffnet, laeufe: laeufe);
    }

    testWidgets('«Erledigt» mit «Rückgängig», das wieder öffnet und neu lädt',
        (tester) async {
      final r = await abhaken(tester);
      expect(r.erledigt, ['o1']);
      expect(r.laeufe.single, 2); // nach dem Abhaken neu geladen
      expect(find.text('Erledigt'), findsOneWidget);
      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(r.geoeffnet, ['o1']);
      expect(r.laeufe.single, 3); // nach dem Rückgängig neu geladen
    });

    testWidgets('Fehler beim Abhaken: Meldung, kein «Rückgängig»', (
      tester,
    ) async {
      final r = await abhaken(
        tester,
        fehler: Exception('ClientException: Failed to fetch'),
      );
      expect(r.erledigt, isEmpty);
      expect(find.text('Nicht erledigt: keine Verbindung'), findsOneWidget);
      expect(find.text('Rückgängig'), findsNothing);
    });
  });

  test('Betriebsseite: Sektion nach «Geplanter Service», vor den Einsätzen', () {
    final code = File(
      'lib/presentation/screens/betriebe/betrieb_detail_screen.dart',
    ).readAsStringSync();
    final service = code.indexOf('_ServiceTerminSection(betrieb: betrieb)');
    final aufgaben = code.indexOf('AufgabenAkteKarte(');
    final einsaetze = code.indexOf('EinsaetzeAkteKarte(');
    expect(service, greaterThanOrEqualTo(0));
    expect(aufgaben, greaterThan(service));
    expect(einsaetze, greaterThan(aufgaben));
  });
}
