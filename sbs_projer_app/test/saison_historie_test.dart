import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/saison_historie.dart';

/// Entscheidet beim Speichern eines Betriebs, ob die bisherige Saison ins
/// Archiv gehört. Auslöser ist allein das START-Datum: ein neuer Start heisst
/// «neue Saison», das bisherige Fenster ist damit Geschichte. Ein geändertes
/// ENDE ist dagegen eine Korrektur derselben Saison und darf keinen zweiten,
/// halbrichtigen Eintrag erzeugen (Entscheid Daniel 08.09.2026).
void main() {
  final start2025 = DateTime(2025, 12, 13);
  final ende2026 = DateTime(2026, 3, 29);

  test('neuer Start → bisherige Saison wandert komplett ins Archiv', () {
    final e = saisonArchivEintrag(
      saison: 'winter',
      altStart: start2025,
      altEnde: ende2026,
      neuStart: DateTime(2026, 12, 11),
    );
    expect(e, isNotNull);
    expect(e!.saison, 'winter');
    expect(e.start, start2025);
    expect(e.ende, ende2026);
  });

  test('nur das Ende geändert → kein Archiveintrag (Korrektur)', () {
    expect(
      saisonArchivEintrag(
        saison: 'winter',
        altStart: start2025,
        altEnde: ende2026,
        neuStart: start2025,
      ),
      isNull,
    );
  });

  test('unverändert gespeichert → kein Archiveintrag', () {
    expect(
      saisonArchivEintrag(
        saison: 'sommer',
        altStart: DateTime(2026, 5, 13),
        altEnde: DateTime(2026, 10, 11),
        neuStart: DateTime(2026, 5, 13),
      ),
      isNull,
    );
  });

  test('vorher gar keine Saison erfasst → nichts zu archivieren', () {
    expect(
      saisonArchivEintrag(
        saison: 'winter',
        altStart: null,
        altEnde: null,
        neuStart: DateTime(2026, 12, 11),
      ),
      isNull,
    );
  });

  test('Saison wird geleert → alter Wert wird trotzdem festgehalten', () {
    // Sonst verschwände er spurlos, und genau dafür gibt es das Archiv.
    final e = saisonArchivEintrag(
      saison: 'winter',
      altStart: start2025,
      altEnde: ende2026,
      neuStart: null,
    );
    expect(e?.start, start2025);
  });

  test('nur Start ohne Ende erfasst → wird als Teilangabe archiviert', () {
    final e = saisonArchivEintrag(
      saison: 'sommer',
      altStart: DateTime(2026, 5, 13),
      altEnde: null,
      neuStart: DateTime(2027, 5, 20),
    );
    expect(e, isNotNull);
    expect(e!.ende, isNull);
  });

  test('Uhrzeit im Datum ändert nichts an der Gleichheit', () {
    expect(
      saisonArchivEintrag(
        saison: 'winter',
        altStart: DateTime(2025, 12, 13),
        altEnde: ende2026,
        neuStart: DateTime(2025, 12, 13, 14, 30),
      ),
      isNull,
    );
  });
}
