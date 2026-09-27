import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sbs_projer_app/core/util/diktat_aufgabe_betrieb.dart';
import 'package:sbs_projer_app/data/models/einsatz_diktat_ergebnis.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/diktat_sheet.dart';

/// Diktierte Aufgabe mit Betrieb (Migration 212, Entscheid Daniel
/// 27.09.2026): «Beim Rössli den Hahn mitnehmen».
void main() {
  const betriebe = [
    (id: 'a', name: 'Sunset Seehotel', ort: 'Eich'),
    (id: 'b', name: 'Sunset Bar', ort: 'Chur'),
    (id: 'c', name: 'Restaurant Rössli', ort: 'Ilanz'),
    (id: 'e', name: 'Hotel Sport', ort: 'Klosters'),
  ];

  group('betriebAusText', () {
    test('eindeutig → Id und Name', () {
      final r = betriebAusText('Beim Rössli Hahn mitnehmen', betriebe);
      expect(r.id, 'c');
      expect(r.name, 'Restaurant Rössli');
      expect(r.kandidaten, isEmpty);
    });

    test('verhörter Name («Rossli») trifft trotzdem', () {
      expect(betriebAusText('Rossli', betriebe).id, 'c');
    });

    test('mehrdeutig → keine Id, nur Kandidaten', () {
      final r = betriebAusText('Sunset anrufen', betriebe);
      expect(r.id, isNull);
      expect(r.kandidaten.map((k) => k.id), containsAll(['a', 'b']));
    });

    test('Gattungswort allein → nichts', () {
      final r = betriebAusText('Hotel anrufen', betriebe);
      expect(r.id, isNull);
      expect(r.kandidaten, isEmpty);
    });
  });

  group('nenntBetriebExakt', () {
    test('alle unterscheidenden Namensteile, Umlaut gefaltet', () {
      expect(nenntBetriebExakt('Rössli', betriebe[2]), isTrue);
      expect(nenntBetriebExakt('Rossli', betriebe[2]), isTrue);
      expect(nenntBetriebExakt('Restaurant Rössli', betriebe[2]), isTrue);
      expect(nenntBetriebExakt('Sport', betriebe[3]), isTrue);
    });

    test('Tippfehler oder Teil des Namens → nein', () {
      expect(nenntBetriebExakt('Rösli', betriebe[2]), isFalse);
      expect(nenntBetriebExakt('Sunset', betriebe[0]), isFalse);
      expect(nenntBetriebExakt('', betriebe[0]), isFalse);
    });
  });

  group('aufgabeBetriebAusDiktat', () {
    DiktatBetrieb zuordnen(
      Map<String, dynamic> json, {
      String text = 'Aufgabe',
    }) => aufgabeBetriebAusDiktat(
      ergebnis: EinsatzDiktatErgebnis.fromJson({'art': 'aufgabe', ...json}),
      text: text,
      betriebe: betriebe,
    );

    test('1. die Function hat zugeordnet → dieser Betrieb', () {
      final r = zuordnen({'betrieb_id': 'c', 'betrieb_name_erkannt': 'Rössli'});
      expect(r.id, 'c');
      expect(r.name, 'Restaurant Rössli');
    });

    test('1. erfundene Id (nicht in der Liste) wird nicht übernommen', () {
      final r = zuordnen({
        'betrieb_id': 'gibts-nicht',
        'betrieb_name_erkannt': 'Rössli',
      });
      // … fällt auf den erkannten Namen zurück.
      expect(r.id, 'c');
    });

    test('2. Kandidaten der Function → zum Antippen, nichts vorgewählt', () {
      final r = zuordnen({
        'betrieb_name_erkannt': 'Sunset',
        'betrieb_kandidaten': [
          {'id': 'a', 'name': 'Sunset Seehotel'},
          {'id': 'b', 'name': 'Sunset Bar'},
          {'id': 'x', 'name': 'Gibts nicht'},
        ],
      });
      expect(r.id, isNull);
      expect(r.kandidaten.map((k) => k.id), ['a', 'b']);
    });

    test('3. Name erkannt, aber nicht zugeordnet → App-Erkennung', () {
      final r = zuordnen({'betrieb_name_erkannt': 'Rossli'});
      expect(r.id, 'c');
    });

    // Review K6: Die Tippfehler-Toleranz machte aus einem verhörten Namen
    // still einen vorgewählten Betrieb.
    test('3. nur ähnlicher Einzeltreffer (Tippfehler) → Chip, nicht vorgewählt',
        () {
      final r = zuordnen({'betrieb_name_erkannt': 'Rösli'});
      expect(r.id, isNull);
      expect(r.kandidaten.single.id, 'c');
    });

    test('3. Teiltreffer («Seehotel» → «Sunset Seehotel») → Chip', () {
      final r = zuordnen({'betrieb_name_erkannt': 'Seehotel'});
      expect(r.id, isNull);
      expect(r.kandidaten.single.id, 'a');
    });

    test('3. exakter Name mit Ort daneben → vorgewählt', () {
      final r = zuordnen({'betrieb_name_erkannt': 'Rössli Ilanz'});
      expect(r.id, 'c');
      expect(r.kandidaten, isEmpty);
    });

    test('3. erkannter Name ohne Treffer → kein Betrieb', () {
      final r = zuordnen({'betrieb_name_erkannt': 'Adler'});
      expect(r.id, isNull);
      expect(r.kandidaten, isEmpty);
    });

    test('4. nichts erkannt: Treffer im Text nur als Kandidat, nie vorgewählt', () {
      final r = zuordnen(const {}, text: 'Trikot für Sport bestellen');
      expect(r.id, isNull);
      expect(r.kandidaten.single.id, 'e');
    });

    test('4. nichts erkannt, nichts im Text → kein Betrieb', () {
      final r = zuordnen(const {}, text: 'Steuererklärung einreichen');
      expect(r.id, isNull);
      expect(r.kandidaten, isEmpty);
    });
  });

  test('Diktat-Sheet: Aufgabe zeigt den Betrieb und speichert ihn mit', () {
    final code = File(
      'lib/presentation/widgets/diktat_sheet.dart',
    ).readAsStringSync();
    expect(code, contains('aufgabeBetriebAusDiktat('));
    expect(code, isNot(contains("_zeigtBetrieb => _art != 'aufgabe'")));
    final speichern = code.substring(code.indexOf("case 'aufgabe':"));
    expect(
      speichern.substring(0, speichern.indexOf('break;')),
      contains('betriebId: _betriebId'),
    );
  });

  // Review K6: Eine von der Function erfundene Id reiste bei Störung/Montage
  // ungeprüft mit — nach dem Wechsel auf «Aufgabe» scheiterte das Speichern
  // am Fremdschlüssel.
  test('Diktat-Sheet: Betriebs-Id nur aus der Liste, auch nach Artwechsel', () {
    final code = File(
      'lib/presentation/widgets/diktat_sheet.dart',
    ).readAsStringSync();
    expect(code, contains('_betriebId = _bekannteBetriebId(e.betriebId);'));
    expect(code, isNot(contains('_betriebId = e.betriebId;')));
    expect(code, contains('onTap: () => _artWechseln(a),'));
    final wechsel = code.substring(code.indexOf('void _artWechseln('));
    expect(
      wechsel.substring(0, wechsel.indexOf('});')),
      contains('_betriebId = _bekannteBetriebId(_betriebId);'),
    );
  });

  // Review M5: Eine diktierte Aufgabe erschien erst nach einem Neustart.
  testWidgets('Diktat-Sheet schliessen lädt Aufgaben-Tabelle und Liste neu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var zeilenLaeufe = 0;
    var listenLaeufe = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aufgabenZeilenProvider.overrideWith((ref) async {
            zeilenLaeufe++;
            return const [];
          }),
          aufgabenListeProvider.overrideWith((ref) async {
            listenLaeufe++;
            return const [];
          }),
          draussenAufgabenProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(aufgabenZeilenProvider);
                ref.watch(aufgabenListeProvider);
                return GestureDetector(
                  onTap: () => zeigeDiktatSheet(context),
                  child: const Text('diktieren'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect((zeilenLaeufe, listenLaeufe), (1, 1));

    await tester.tap(find.text('diktieren'));
    await tester.pumpAndSettle();
    expect(find.text('Diktieren'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Diktieren'), findsNothing);
    expect(zeilenLaeufe, 2);
    expect(listenLaeufe, 2);
  });
}
