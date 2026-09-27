import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/storage/material_ansicht_speicher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ansicht (Liste/Karten) und zuletzt gewählte Kategorie des Material-Screens
/// bleiben im Browser gemerkt.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('leer → Liste, keine Kategorie', () async {
    final s = await MaterialAnsichtSpeicher.lade();
    expect(s.ansicht, MaterialAnsicht.liste);
    expect(s.kategorieId, isNull);
  });

  test('Roundtrip Ansicht und Kategorie', () async {
    await MaterialAnsichtSpeicher.speichereAnsicht(MaterialAnsicht.karten);
    await MaterialAnsichtSpeicher.speichereKategorie('k-hahn');
    final s = await MaterialAnsichtSpeicher.lade();
    expect(s.ansicht, MaterialAnsicht.karten);
    expect(s.kategorieId, 'k-hahn');

    await MaterialAnsichtSpeicher.speichereAnsicht(MaterialAnsicht.liste);
    expect((await MaterialAnsichtSpeicher.lade()).ansicht,
        MaterialAnsicht.liste);
  });

  test('Kategorie null entfernt den Schlüssel', () async {
    await MaterialAnsichtSpeicher.speichereKategorie('k-hahn');
    await MaterialAnsichtSpeicher.speichereKategorie(null);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(MaterialAnsichtSpeicher.schluesselKategorie),
      isFalse,
    );
    expect((await MaterialAnsichtSpeicher.lade()).kategorieId, isNull);
  });

  test('Schlüsselnamen und gespeicherte Werte sind stabil', () async {
    // Die Werte liegen in Browsern, die über Versionen hinweg leben —
    // Umbenennen würde still alles Gemerkte verlieren.
    await MaterialAnsichtSpeicher.speichereAnsicht(MaterialAnsicht.karten);
    await MaterialAnsichtSpeicher.speichereKategorie('ohne');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('material_ansicht'), 'karten');
    expect(prefs.getString('material_kategorie'), 'ohne');
  });

  test('unbekannter Ansichtswert → Liste', () async {
    SharedPreferences.setMockInitialValues({'material_ansicht': 'kacheln'});
    expect((await MaterialAnsichtSpeicher.lade()).ansicht,
        MaterialAnsicht.liste);
  });

  test('falscher Typ im Speicher → Standard statt Absturz', () async {
    SharedPreferences.setMockInitialValues({
      'material_ansicht': 3,
      'material_kategorie': true,
    });
    final s = await MaterialAnsichtSpeicher.lade();
    expect(s.ansicht, MaterialAnsicht.liste);
    expect(s.kategorieId, isNull);
  });
}
