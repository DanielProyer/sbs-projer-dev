import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Migration 215: «Jahrgang abschreiben» bucht nach dem 2019-Muster.
///
/// WARUM: Bis 214 buchte der App-Schritt je Rechnung `3805 an 1100 netto` und
/// `2200 an 1100 MWST`, beide per 31.12. des Geschäftsjahrs, und legte die
/// MWST-Periode auf Q4 dieses Jahres. Der Abschluss findet aber im Folgejahr
/// statt — Q4 ist dann meist eingereicht, die Buchung erzwänge eine
/// Korrekturabrechnung. Richtig (Art. 41 Abs. 2 MWSTG, Entgeltsminderung in
/// der Periode des Entscheids): Verlust BRUTTO per 31.12. auf 3805, die
/// Rückholung als Sammelbuchung `2200 an 3805` am Entscheidtag, Ziff. 235 im
/// laufenden Quartal. Genau so lief der Jahrgang 2019 (JA2025_A_MWST).
///
/// Die Hauptsession wendet die Migration nach dem Review an — dieser Test
/// prüft die DATEI, damit ein späteres Umformulieren keine Regel verliert.
void main() {
  final datei = File(
    '../Datenbank/migrations/215_abschreibung_entscheidtag.sql',
  );
  late final String roh;
  late final String sql; // ohne Kommentare

  setUpAll(() {
    expect(datei.existsSync(), isTrue, reason: datei.path);
    roh = datei.readAsStringSync();
    sql = roh
        .split('\n')
        .map((z) {
          final k = z.indexOf('--');
          return k == -1 ? z : z.substring(0, k);
        })
        .join('\n');
  });

  String block(String anfang) {
    final start = sql.indexOf(anfang);
    expect(start, isNot(-1), reason: 'nicht gefunden: $anfang');
    final ende = sql.indexOf(r'$$;', start);
    return sql.substring(start, ende == -1 ? sql.length : ende);
  }

  String view() {
    final start = sql.indexOf('VIEW view_entgeltsminderung');
    expect(start, isNot(-1), reason: 'View fehlt');
    return sql.substring(start, sql.indexOf(';', start));
  }

  test('Kopfkommentar nennt das WARUM (2019-Muster, Art. 41 MWSTG, §9)', () {
    expect(roh, contains('2019-Muster'));
    expect(roh, contains('Art. 41 Abs. 2 MWSTG'));
    expect(roh, contains('jahresabschluss-2025.md'));
  });

  test('Lauf merkt sich die Sammelbuchungen der MWST-Rückholung', () {
    expect(
      sql,
      contains(
        'ADD COLUMN IF NOT EXISTS buchung_mwst_ids uuid[] NOT NULL '
        "DEFAULT '{}'",
      ),
    );
  });

  test('Eindeutiger Index «ein gebuchter Lauf je Jahr» fällt (214 wirkt)', () {
    // Der Index aus 194 blockiert den zweiten Lauf, den 214 erlauben wollte
    // (Abschluss 2025: 2019 per SQL, 2020 per App am 01.10.2026).
    expect(
      sql,
      contains('DROP INDEX IF EXISTS abschreibung_laeufe_ein_gebuchter'),
    );
  });

  group('abschreibung_jahrgang_buchen', () {
    late String f;
    setUpAll(() {
      f = block(
        'CREATE OR REPLACE FUNCTION abschreibung_jahrgang_buchen'
        '(p_geschaeftsjahr INTEGER, p_rechnung_ids UUID[])',
      );
    });

    test('je Rechnung EINE Buchung 3805 an 1100 brutto per 31.12.', () {
      expect(f, contains('make_date(p_geschaeftsjahr, 12, 31)'));
      expect(f, contains('3805, 1100, r.betrag_brutto, 0, 0, r.betrag_brutto'));
      expect(f, isNot(contains('3805, 1100, r.betrag_netto')));
      expect(f, contains("'intern', 'abschreibung', r.id, p_geschaeftsjahr"));
      expect(f, contains('(brutto)'));
    });

    test('keine MWST-Buchung 2200 an 1100 je Rechnung mehr', () {
      expect(f, isNot(contains('2200, 1100')));
      expect(f, isNot(contains('r.mwst_betrag, 0, 0, r.mwst_betrag')));
    });

    test('je Satz eine Sammelbuchung 2200 an 3805 am Entscheidtag', () {
      expect(f, contains('2200, 3805, s.mwst, 0, 0, s.mwst'));
      expect(f, contains('round(p.mwst / p.netto * 100, 1)'));
      expect(f, contains('GROUP BY 1'));
      expect(f, contains("format('JA%s_A_MWST_%s'"));
      expect(f, contains("replace(s.satz::text, '.', '_')"));
      expect(f, contains("'_L%s'"));
      expect(f, contains('Ziff. 235 Q%s/%s'));
      // Keine beleg_id: die Sicht zählt die Sammelbuchung nicht doppelt.
      expect(f, contains("'intern', 'abschreibung', NULL, v_mwst_jahr"));
      expect(f, contains('v_mwst_ids := v_mwst_ids || v_mwst_id'));
      expect(f, contains('buchung_mwst_ids = v_mwst_ids'));
    });

    test('Entscheidtag bestimmt Datum und MWST-Periode — Schweizer Datum', () {
      // Die Datenbank läuft in UTC: `current_date` wäre zwischen 00:00 und
      // 02:00 Schweizer Zeit noch der Vortag — am Quartalsersten das falsche
      // Quartal.
      expect(f, contains("(now() AT TIME ZONE 'Europe/Zurich')::date"));
      expect(f, contains('EXTRACT(YEAR FROM v_entscheid)'));
      expect(f, contains('EXTRACT(QUARTER FROM v_entscheid)'));
      expect(f, contains('VALUES (v_user, v_entscheid,'));
      expect(f, contains('v_datum, v_mwst_jahr, v_mwst_quartal'));
      expect(f, isNot(contains('p_geschaeftsjahr, 4,')));
    });

    test('Wächter aus 214 bleibt, und zuerst wird gesperrt', () {
      expect(f, contains("RAISE EXCEPTION 'Schon in einem gebuchten Lauf"));
      expect(f, contains('p.rechnung_id = ANY (p_rechnung_ids)'));
      expect(f, contains("rg.zahlungsstatus IN ('bezahlt', 'abgeschrieben')"));
      final sperre = f.indexOf('FOR UPDATE');
      expect(sperre, isNot(-1));
      expect(
        sperre,
        lessThan(f.indexOf("'Schon in einem gebuchten Lauf")),
        reason: 'Ohne Sperre vor der Prüfung buchte ein Doppelklick doppelt, '
            'sobald der eindeutige Index weg ist',
      );
    });

    test('Positionen behalten netto, mwst, brutto; keine MWST-Buchung-Id', () {
      expect(f, contains('r.betrag_netto, r.mwst_betrag, r.betrag_brutto'));
      expect(f, contains('v_brutto_id, NULL'));
    });
  });

  group('abschreibung_lauf_zuruecknehmen', () {
    late String f;
    setUpAll(() {
      f = block('CREATE OR REPLACE FUNCTION abschreibung_lauf_zuruecknehmen(');
    });

    test('löscht auch die Sammelbuchungen, prüft sie vorher auf Storno', () {
      expect(f, contains('id = ANY (l.buchung_mwst_ids) AND ist_storniert'));
      expect(f, contains('storno_von_id = ANY (l.buchung_mwst_ids)'));
      expect(
        f,
        contains(
          'DELETE FROM buchungen WHERE id = ANY (l.buchung_mwst_ids) '
          'AND user_id = v_user',
        ),
      );
      expect(
        f.indexOf('storno_von_id = ANY (l.buchung_mwst_ids)'),
        lessThan(f.indexOf('FOR p IN')),
        reason: 'Storno-Prüfung vor jedem Löschen',
      );
    });

    test('Rest wie 211: Status offen, Altwert hebt die Mahnstufe', () {
      expect(f, contains("SET zahlungsstatus = 'offen'"));
      expect(f, contains('rechnung_stufe_aus_altstatus(p.status_vorher)'));
      expect(f, contains('IF NOT l.ruecknahme_moeglich THEN'));
      expect(
        f,
        contains(
          'DELETE FROM buchungen WHERE id IN (p.buchung_netto_id, '
          'p.buchung_mwst_id) AND user_id = v_user',
        ),
      );
    });
  });

  group('view_entgeltsminderung', () {
    test('Jahrgangsläufe je Satz aus den Positionen, nicht als Mischsatz', () {
      final v = view();
      expect(v, contains('security_invoker = true'));
      expect(v, contains('JOIN abschreibung_positionen p ON p.lauf_id = l.id'));
      expect(v, contains('round(p.mwst / p.netto * 100, 1) AS satz'));
      expect(v, contains('sum(p.netto)'));
      expect(v, contains('sum(p.mwst)'));
      expect(v, contains('GROUP BY l.id'));
      expect(v, isNot(contains('round(l.mwst / l.netto')));
    });

    test('Spalten in derselben Reihenfolge wie heute', () {
      final v = view();
      final erster = v.substring(0, v.indexOf('UNION ALL'));
      final spalten = [
        'l.user_id',
        'AS jahr',
        'AS quartal',
        'AS satz',
        'AS netto',
        'AS mwst',
        'AS anzahl',
        'AS text',
      ];
      var letzte = -1;
      for (final s in spalten) {
        final i = erster.indexOf(s);
        expect(i, greaterThan(letzte), reason: s);
        letzte = i;
      }
    });

    test('Einzelabschreibungen unverändert (209c)', () {
      final v = view();
      expect(
        v,
        contains(
          'NOT EXISTS (SELECT 1 FROM abschreibung_positionen p '
          'WHERE p.rechnung_id = b.beleg_id)',
        ),
      );
      expect(v, contains('JOIN rechnungen r ON r.id = b.beleg_id'));
      expect(v, contains("format('Einzelabschreibungen (%s %s)'"));
    });

    test('Kommentar der Sicht nachgezogen', () {
      expect(sql, contains('COMMENT ON VIEW view_entgeltsminderung IS'));
      expect(sql, contains('seit 215'));
    });
  });
}
