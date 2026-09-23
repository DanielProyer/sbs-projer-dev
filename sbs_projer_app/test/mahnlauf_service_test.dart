import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/rechnung/mahnlauf_service.dart';

/// Reine Hilfsfunktionen von `MahnlaufService` — Protokoll und «zurücknehmen»
/// hängen daran, dass diese beiden Funktionen exakt zueinander passen
/// (`vorherStand` muss jedes Feld liefern, das `updateFuerStufe` je setzt).
void main() {
  Rechnung rechnung({
    String zahlungsstatus = 'offen',
    int mahnungStufe = 0,
    DateTime? letzteMahnungAm,
    DateTime? erinnerungAm,
    DateTime? mahnung1Am,
    DateTime? mahnung2Am,
    DateTime? mahnFristBis,
  }) {
    return Rechnung(
      id: 'r1',
      userId: 'u1',
      rechnungstyp: 'kundenrechnung',
      rechnungsdatum: DateTime.utc(2026, 8, 1),
      faelligkeitsdatum: DateTime.utc(2026, 8, 31),
      zahlungsstatus: zahlungsstatus,
      mahnungStufe: mahnungStufe,
      letzteMahnungAm: letzteMahnungAm,
      erinnerungAm: erinnerungAm,
      mahnung1Am: mahnung1Am,
      mahnung2Am: mahnung2Am,
      mahnFristBis: mahnFristBis,
    );
  }

  group('updateFuerStufe', () {
    test('1. Mahnung am 23.09.2026: Status, Stufe, Frist +10 Tage — '
        'keine anderen Datumsfelder', () {
      final m = MahnlaufService.updateFuerStufe(
        MahnStufe.mahnung1,
        DateTime.utc(2026, 9, 23),
      );
      expect(m['zahlungsstatus'], 'mahnung_1');
      expect(m['mahnung_stufe'], 1);
      expect(m['letzte_mahnung_am'], '2026-09-23');
      expect(m['mahnung_1_am'], '2026-09-23');
      expect(m['mahn_frist_bis'], '2026-10-03');
      // Nur die stufeneigenen Datumsfelder — kein erinnerung_am/mahnung_2_am.
      expect(m.containsKey('erinnerung_am'), isFalse);
      expect(m.containsKey('mahnung_2_am'), isFalse);
      expect(m.keys, hasLength(5));
    });

    test('Erinnerung setzt erinnerung_am, nicht mahnung_1_am/mahnung_2_am', () {
      final m = MahnlaufService.updateFuerStufe(
        MahnStufe.erinnerung,
        DateTime.utc(2026, 9, 23),
      );
      expect(m['zahlungsstatus'], 'erinnert');
      expect(m['mahnung_stufe'], 0);
      expect(m['erinnerung_am'], '2026-09-23');
      expect(m.containsKey('mahnung_1_am'), isFalse);
      expect(m.containsKey('mahnung_2_am'), isFalse);
    });

    test('Letzte Mahnung setzt mahnung_2_am, Status mahnung_2', () {
      final m = MahnlaufService.updateFuerStufe(
        MahnStufe.letzte,
        DateTime.utc(2026, 9, 23),
      );
      expect(m['zahlungsstatus'], 'mahnung_2');
      expect(m['mahnung_stufe'], 2);
      expect(m['mahnung_2_am'], '2026-09-23');
      expect(m.containsKey('erinnerung_am'), isFalse);
      expect(m.containsKey('mahnung_1_am'), isFalse);
    });
  });

  group('vorherStand', () {
    test('enthält genau die sieben Felder im DB-Format (yyyy-MM-dd oder null)', () {
      final r = rechnung(
        zahlungsstatus: 'mahnung_1',
        mahnungStufe: 1,
        letzteMahnungAm: DateTime.utc(2026, 9, 10),
        erinnerungAm: DateTime.utc(2026, 8, 20),
        mahnung1Am: DateTime.utc(2026, 9, 10),
        mahnFristBis: DateTime.utc(2026, 9, 20),
      );
      final v = MahnlaufService.vorherStand(r);
      expect(v.keys.toSet(), {
        'zahlungsstatus',
        'mahnung_stufe',
        'letzte_mahnung_am',
        'erinnerung_am',
        'mahnung_1_am',
        'mahnung_2_am',
        'mahn_frist_bis',
      });
      expect(v['zahlungsstatus'], 'mahnung_1');
      expect(v['mahnung_stufe'], 1);
      expect(v['letzte_mahnung_am'], '2026-09-10');
      expect(v['erinnerung_am'], '2026-08-20');
      expect(v['mahnung_1_am'], '2026-09-10');
      expect(v['mahnung_2_am'], isNull);
      expect(v['mahn_frist_bis'], '2026-09-20');
    });

    test('unberührte Rechnung: nur zahlungsstatus/mahnung_stufe gesetzt, Rest null', () {
      final v = MahnlaufService.vorherStand(rechnung());
      expect(v['zahlungsstatus'], 'offen');
      expect(v['mahnung_stufe'], 0);
      expect(v['letzte_mahnung_am'], isNull);
      expect(v['erinnerung_am'], isNull);
      expect(v['mahnung_1_am'], isNull);
      expect(v['mahnung_2_am'], isNull);
      expect(v['mahn_frist_bis'], isNull);
    });

    test('vorherStand + updateFuerStufe können dieselbe Rechnung wiederherstellen '
        '(Grundlage für "zurücknehmen")', () {
      final r = rechnung(mahnungStufe: 0, zahlungsstatus: 'offen');
      final v = MahnlaufService.vorherStand(r);
      final u = MahnlaufService.updateFuerStufe(
        MahnStufe.erinnerung,
        DateTime.utc(2026, 9, 23),
      );
      // Jedes von updateFuerStufe gesetzte Feld muss in vorherStand vorkommen
      // (sonst bliebe ein Feld nach "zurücknehmen" auf dem neuen Stand).
      for (final key in u.keys) {
        expect(v.containsKey(key), isTrue, reason: 'vorherStand fehlt "$key"');
      }
    });
  });
}
