import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wer in der Oberfläche einen Datensatz speichert, muss den zugehörigen
/// Listen-Provider neu laden — sonst erscheint der neue Betrieb oder die neue
/// Störung erst nach einem Browser-Refresh.
///
/// WARUM (Daniel, 29.09.2026): «ich habe heute einen neuen Betrieb erstellt
/// und eine Störung auf diesen Betrieb erfasst, beides war erst nach einem
/// Refresh sichtbar.» Das Diktat-Sheet speicherte Betrieb, Störung und
/// Montage, lud aber nur die Aufgaben-Provider neu. Auf Web ist jeder
/// `watchAll()`-Strom einmalig (`Stream.fromFuture`), Riverpod bekommt eine
/// Änderung also NUR über `invalidate(<x>StreamProvider)` mit.
///
/// Prüfung je Datei (grob, aber wirksam): Steht `XRepository.save(` in einer
/// Datei unter `lib/presentation/`, muss dieselbe Datei auch
/// `invalidate(xStreamProvider` enthalten. Wer das Neuladen bewusst
/// woanders erledigt, trägt die Datei mit Begründung in [_ausnahmen] ein.
const _regeln = <String, String>{
  'BetriebRepository.save(': 'betriebeStreamProvider',
  'StoerungRepository.save(': 'stoerungenStreamProvider',
  'MontageRepository.save(': 'montagenStreamProvider',
  'EigenauftragRepository.save(': 'eigenauftraegeStreamProvider',
  'EroeffnungsreinigungRepository.save(': 'eroeffnungsreinigungenStreamProvider',
  'ReinigungRepository.save(': 'reinigungenStreamProvider',
};

/// Dateien, die das Neuladen nachweislich anders lösen — mit Grund.
const _ausnahmen = <String, String>{};

void main() {
  test('jede Speicherstelle in der Oberfläche lädt ihren Provider neu', () {
    final verstoesse = <String>[];
    for (final f in Directory('lib/presentation')
        .listSync(recursive: true)
        .whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final pfad = f.path.replaceAll(r'\', '/');
      if (_ausnahmen.keys.any(pfad.endsWith)) continue;
      final quelle = f.readAsStringSync();
      for (final regel in _regeln.entries) {
        if (!quelle.contains(regel.key)) continue;
        if (quelle.contains('invalidate(${regel.value}')) continue;
        verstoesse.add('$pfad: ${regel.key} ohne invalidate(${regel.value})');
      }
    }
    expect(
      verstoesse,
      isEmpty,
      reason:
          'Nach dem Speichern den Listen-Provider neu laden '
          '(ref.invalidate(...)), sonst erscheint der Datensatz erst nach '
          'einem Refresh. Begründete Ausnahmen in _ausnahmen eintragen.',
    );
  });
}
