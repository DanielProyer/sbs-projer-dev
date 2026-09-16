import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_regeln.dart';

MonatsKontext leer({int jahr = 2026, int monat = 8, DateTime? heute}) =>
    MonatsKontext(
      jahr: jahr,
      monat: monat,
      heute: heute ?? DateTime(2026, 9, 16),
      einsaetze: const [],
      mailRechnungenOffen: 0,
      heinekenStatus: null,
      bergTage: const {},
      pauschalenTage: const {},
      camtDeckung: const [],
      offenePrueflisteImMonat: 0,
      lohnMonate: const {},
    );

void main() {
  test('Zeitraum: von und bis umfassen den ganzen Monat', () {
    final k = leer(jahr: 2026, monat: 2);
    expect(k.von, DateTime(2026, 2, 1));
    expect(k.bis, DateTime(2026, 2, 28));
    expect(
      leer(jahr: 2024, monat: 2).bis,
      DateTime(2024, 2, 29),
      reason: 'Schaltjahr',
    );
    expect(leer(jahr: 2026, monat: 12).bis, DateTime(2026, 12, 31));
  });

  test('laufender Monat wird erkannt', () {
    expect(
      leer(
        jahr: 2026,
        monat: 9,
        heute: DateTime(2026, 9, 16),
      ).istLaufenderMonat,
      isTrue,
    );
    expect(
      leer(
        jahr: 2026,
        monat: 8,
        heute: DateTime(2026, 9, 16),
      ).istLaufenderMonat,
      isFalse,
    );
  });

  test('pruefeMonat laeuft ueber die registrierten Regeln', () {
    // Nach Task 1 ist die Liste leer; die Vollzaehligkeit prueft Task 4,
    // wenn alle zehn Regeln stehen — so bleibt kein roter Commit zurueck.
    expect(pruefeMonat(leer()), hasLength(alleMonatsRegeln().length));
  });
}
