import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/models/mahnschreiben.dart';
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

  group('darfZuruecksetzen (Review 23.09.2026 — CRITICAL: nie eine Zahlung überschreiben)', () {
    final nachher = MahnlaufService.updateFuerStufe(
      MahnStufe.erinnerung,
      DateTime.utc(2026, 9, 23),
    );

    test('unverändert seit dem Schreiben -> ja', () {
      final aktuell = {
        'zahlungsstatus': nachher['zahlungsstatus'],
        'mahnung_stufe': nachher['mahnung_stufe'],
        'letzte_mahnung_am': nachher['letzte_mahnung_am'],
      };
      final p = MahnlaufService.darfZuruecksetzen(aktuell, nachher);
      expect(p.erlaubt, isTrue);
      expect(p.grund, isNull);
    });

    test('inzwischen bezahlt -> nein, Grund "inzwischen bezahlt"', () {
      final aktuell = {
        'zahlungsstatus': 'bezahlt',
        'mahnung_stufe': nachher['mahnung_stufe'],
        'letzte_mahnung_am': nachher['letzte_mahnung_am'],
      };
      final p = MahnlaufService.darfZuruecksetzen(aktuell, nachher);
      expect(p.erlaubt, isFalse);
      expect(p.grund, 'inzwischen bezahlt');
    });

    test('abgeschrieben zählt ebenfalls als "inzwischen bezahlt" (kein Zurücksetzen)', () {
      final aktuell = {
        'zahlungsstatus': 'abgeschrieben',
        'mahnung_stufe': nachher['mahnung_stufe'],
        'letzte_mahnung_am': nachher['letzte_mahnung_am'],
      };
      final p = MahnlaufService.darfZuruecksetzen(aktuell, nachher);
      expect(p.erlaubt, isFalse);
      expect(p.grund, 'inzwischen bezahlt');
    });

    test('seither weiter gemahnt (höhere Stufe) -> nein', () {
      final aktuell = {
        'zahlungsstatus': 'mahnung_1',
        'mahnung_stufe': 1,
        'letzte_mahnung_am': nachher['letzte_mahnung_am'],
      };
      final p = MahnlaufService.darfZuruecksetzen(aktuell, nachher);
      expect(p.erlaubt, isFalse);
      expect(p.grund, 'seither weiter gemahnt');
    });

    test('kein nachher-Zustand (altes Schreiben) -> nein, nie automatisch', () {
      final aktuell = {
        'zahlungsstatus': nachher['zahlungsstatus'],
        'mahnung_stufe': nachher['mahnung_stufe'],
        'letzte_mahnung_am': nachher['letzte_mahnung_am'],
      };
      final p = MahnlaufService.darfZuruecksetzen(aktuell, null);
      expect(p.erlaubt, isFalse);
      expect(p.grund, isNotNull);
    });

    test('letzte_mahnung_am weicht ab (z.B. manuell korrigiert) -> nein, "geändert"', () {
      final aktuell = {
        'zahlungsstatus': nachher['zahlungsstatus'],
        'mahnung_stufe': nachher['mahnung_stufe'],
        'letzte_mahnung_am': '2026-09-24',
      };
      final p = MahnlaufService.darfZuruecksetzen(aktuell, nachher);
      expect(p.erlaubt, isFalse);
      expect(p.grund, 'geändert');
    });
  });

  group('MahnlaufFehler', () {
    test('toString liefert NUR die Meldung, keine "Instance of"-Verpackung', () {
      final f = MahnlaufFehler('keine Verbindung', mahnschreibenId: 'm1');
      expect(f.toString(), 'keine Verbindung');
      expect(f.mahnschreibenId, 'm1');
    });

    test('mahnschreibenId ist optional (Fehler vor dem Protokoll)', () {
      final f = MahnlaufFehler('keine Verbindung');
      expect(f.mahnschreibenId, isNull);
      expect(f.toString(), 'keine Verbindung');
    });
  });

  group('istJuengstesSchreiben (nur das jüngste Schreiben darf zurücksetzen)', () {
    Mahnschreiben schreiben(String id, DateTime am,
        {List<String> rechnungen = const ['r1'], DateTime? zurueck}) {
      return Mahnschreiben(
        id: id,
        userId: 'u1',
        betriebId: 'b1',
        stufe: 0,
        rechnungIds: rechnungen,
        kanal: 'mail',
        test: true,
        fristBis: am.add(const Duration(days: 10)),
        vorher: const {},
        erstelltAm: am,
        zurueckgenommenAm: zurueck,
      );
    }

    final alt = schreiben('m1', DateTime.utc(2026, 9, 1));
    final neu = schreiben('m2', DateTime.utc(2026, 9, 20));

    test('einziges Schreiben -> jüngstes', () {
      expect(
        MahnlaufService.istJuengstesSchreiben([alt], rechnungId: 'r1', kandidat: alt),
        isTrue,
      );
    });

    test('es gibt ein neueres Schreiben derselben Rechnung -> nein', () {
      expect(
        MahnlaufService.istJuengstesSchreiben([neu, alt], rechnungId: 'r1', kandidat: alt),
        isFalse,
      );
      expect(
        MahnlaufService.istJuengstesSchreiben([neu, alt], rechnungId: 'r1', kandidat: neu),
        isTrue,
      );
    });

    test('neueres Schreiben zurückgenommen -> älteres ist wieder das jüngste', () {
      final neuZurueck = schreiben('m2', DateTime.utc(2026, 9, 20),
          zurueck: DateTime.utc(2026, 9, 21));
      expect(
        MahnlaufService.istJuengstesSchreiben([neuZurueck, alt],
            rechnungId: 'r1', kandidat: alt),
        isTrue,
      );
    });

    test('neueres Schreiben einer ANDEREN Rechnung zählt nicht', () {
      final andere =
          schreiben('m3', DateTime.utc(2026, 9, 22), rechnungen: const ['r2']);
      expect(
        MahnlaufService.istJuengstesSchreiben([andere, alt],
            rechnungId: 'r1', kandidat: alt),
        isTrue,
      );
    });
  });

  group('aufraeumPlan (Abbruch beim Setzen der Stufen, Review N-1)', () {
    final updates = {
      'r1': MahnlaufService.updateFuerStufe(MahnStufe.erinnerung, DateTime.utc(2026, 9, 23)),
      'r2': MahnlaufService.updateFuerStufe(MahnStufe.mahnung1, DateTime.utc(2026, 9, 23)),
      'r3': MahnlaufService.updateFuerStufe(MahnStufe.erinnerung, DateTime.utc(2026, 9, 23)),
    };
    final vorher = {
      'r1': {'zahlungsstatus': 'offen', 'mahnung_stufe': 0},
      'r2': {'zahlungsstatus': 'erinnert', 'mahnung_stufe': 0},
      'r3': {'zahlungsstatus': 'gesendet', 'mahnung_stufe': 0},
    };

    test('nur die schon gesetzten (vor der gescheiterten) werden zurückgesetzt', () {
      final plan = MahnlaufService.aufraeumPlan(
        reihenfolge: const ['r1', 'r2', 'r3'],
        gescheitert: 'r3',
        updates: updates,
        vorher: vorher,
      );
      expect(plan.map((s) => s.rechnungId), ['r1', 'r2']);
      // Zurück auf den Vorher-Stand, aber nur, wenn noch der gesetzte Status gilt.
      expect(plan.first.felder, vorher['r1']);
      expect(plan.first.erwarteterStatus, 'erinnert');
      expect(plan[1].erwarteterStatus, 'mahnung_1');
    });

    test('scheitert schon die erste: nichts zurückzusetzen', () {
      expect(
        MahnlaufService.aufraeumPlan(
          reihenfolge: const ['r1', 'r2'],
          gescheitert: 'r1',
          updates: updates,
          vorher: vorher,
        ),
        isEmpty,
      );
    });
  });
}
