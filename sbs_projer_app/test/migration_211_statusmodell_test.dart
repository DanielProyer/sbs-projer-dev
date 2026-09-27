import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Migration 211 (Statusmodell-Zielbild, Entscheid Daniel 27.09.2026) wird
/// vom Controller nach Review angewendet — dieser Test prüft die DATEI auf die
/// Umschreib-Regeln, damit ein späteres Umformulieren keine Regel verliert.
///
/// Zielbild: `zahlungsstatus` ∈ {offen, bezahlt, abgeschrieben}; Zustellung =
/// versendet_am/uebergeben_am; Mahnstufe = mahnung_stufe (1 erinnert,
/// 2 Mahnung 1, 3 Mahnung 2); Heineken-Freigabe = freigegeben_am.
void main() {
  final datei = File('../Datenbank/migrations/211_zahlungsstatus_zielbild.sql');
  late final String roh;
  late final String sql; // ohne Kommentare

  setUpAll(() {
    expect(datei.existsSync(), isTrue, reason: datei.path);
    roh = datei.readAsStringSync();
    sql = roh
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
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

  int pos(Pattern p) {
    final i = sql.indexOf(p);
    expect(i, isNot(-1), reason: 'nicht gefunden: $p');
    return i;
  }

  test('Snapshot in eigenem Schema, NICHT in public (RLS-Leck, Migration 176)',
      () {
    expect(sql, contains('CREATE SCHEMA IF NOT EXISTS snapshot_status_umbau'));
    expect(
      sql,
      contains('CREATE TABLE snapshot_status_umbau.snapshot_status_umbau_211'),
    );
    expect(sql, isNot(contains('public.snapshot')));
    for (final spalte in [
      'rechnungsnummer',
      'zahlungsstatus',
      'mahnung_stufe',
      'versendet_am',
      'uebergeben_am',
      'updated_at',
      'now()',
    ]) {
      expect(block('CREATE TABLE snapshot_status_umbau'), contains(spalte));
    }
    // Rückweg steht als Kommentar in der Datei.
    expect(roh, contains('RÜCKWEG'));
  });

  test('Snapshot vor jedem Umschreiben', () {
    final snap = pos('CREATE TABLE snapshot_status_umbau');
    expect(snap, lessThan(pos('ADD COLUMN IF NOT EXISTS freigegeben_am')));
    expect(snap, lessThan(pos(RegExp(r'UPDATE rechnungen\s+SET mahnung_stufe'))));
  });

  test('freigegeben_am: Spalte, Buchungsdatum → Zahlungsdatum → Rechnungsdatum '
      '(nie updated_at = Importtag), auch bezahlte Heineken — VOR dem '
      'Umschreiben', () {
    expect(sql, contains('ADD COLUMN IF NOT EXISTS freigegeben_am TIMESTAMPTZ'));
    final setzen = pos('SET freigegeben_am = coalesce(');
    final teil = sql.substring(setzen, sql.indexOf(';', setzen));
    expect(teil, contains("b.beleg_typ = 'rechnung'"));
    expect(teil, contains('b.soll_konto = 1100'));
    expect(teil, contains('min(b.datum)'));
    // Reihenfolge im coalesce: Buchung, Zahlungseingang, Rechnungsdatum.
    final buchung = teil.indexOf('min(b.datum)');
    final zahlung = teil.indexOf('r.zahlung_eingegangen_am::timestamptz');
    final rdatum = teil.indexOf('r.rechnungsdatum::timestamptz');
    expect(zahlung, greaterThan(buchung));
    expect(rdatum, greaterThan(zahlung));
    // updated_at ist bei 79 Import-Rechnungen der Importtag 14.07.2026.
    expect(teil, isNot(contains('updated_at')));
    expect(teil, contains("r.zahlungsstatus = 'freigegeben'"));
    expect(teil, contains("r.rechnungstyp = 'heineken_monat'"));
    expect(teil, contains("r.zahlungsstatus = 'bezahlt'"));
    expect(
      setzen,
      lessThan(pos("WHERE zahlungsstatus IN ('gesendet', 'freigegeben')")),
    );
  });

  test('Mahnstufen-Altwerte → offen + greatest(Stufe, 1/2/3)', () {
    final hilfe = block('CREATE OR REPLACE FUNCTION rechnung_stufe_aus_altstatus');
    expect(hilfe, contains("WHEN 'erinnert'  THEN 1"));
    expect(hilfe, contains("WHEN 'mahnung_1' THEN 2"));
    expect(hilfe, contains("WHEN 'mahnung_2' THEN 3"));

    final i = pos(RegExp(r'UPDATE rechnungen\s+SET mahnung_stufe = greatest'));
    final teil = sql.substring(i, sql.indexOf(';', i));
    expect(teil, contains('rechnung_stufe_aus_altstatus(zahlungsstatus)'));
    expect(teil, contains("zahlungsstatus = 'offen'"));
    expect(teil, contains("('erinnert', 'mahnung_1', 'mahnung_2')"));
  });

  test('gesendet und freigegeben → offen, NULL → offen, Stufe NULL → 0', () {
    expect(
      sql,
      contains(
        "UPDATE rechnungen SET zahlungsstatus = 'offen'\n"
        "WHERE zahlungsstatus IN ('gesendet', 'freigegeben')",
      ),
    );
    expect(
      sql,
      contains(
        "UPDATE rechnungen SET zahlungsstatus = 'offen' WHERE zahlungsstatus IS NULL",
      ),
    );
    expect(
      sql,
      contains('UPDATE rechnungen SET mahnung_stufe = 0 WHERE mahnung_stufe IS NULL'),
    );
  });

  test('CHECK, Vorgabe und NOT NULL — nach dem Umschreiben', () {
    final check = pos(
      "CHECK (zahlungsstatus IN ('offen', 'bezahlt', 'abgeschrieben'))",
    );
    expect(pos('WHERE zahlungsstatus IS NULL'), lessThan(check));
    expect(sql, contains('DROP CONSTRAINT IF EXISTS rechnungen_zahlungsstatus_check'));
    expect(sql, contains("ALTER COLUMN zahlungsstatus SET DEFAULT 'offen'"));
    final notNull = pos('ALTER COLUMN zahlungsstatus SET NOT NULL');
    expect(pos('WHERE zahlungsstatus IS NULL'), lessThan(notNull));
    expect(sql, contains('ALTER COLUMN mahnung_stufe SET NOT NULL'));
  });

  test('zahlung_erfassen: Heineken über freigegeben_am, Mahnstufen-Sperre', () {
    final f = block('CREATE OR REPLACE FUNCTION zahlung_erfassen(');
    expect(f, contains("rg.rechnungstyp = 'heineken_monat' AND rg.freigegeben_am IS NULL"));
    expect(f, isNot(contains("'freigegeben'")));
    expect(f, contains("p_vorher -> (rg.id::text) ->> 'mahnung_stufe'"));
    // Unverändert aus 209/209d: Jahressperre, Sperre vor Prüfung, bezahlt.
    expect(f, contains('geschaeftsjahr_abgeschlossen'));
    expect(f, contains('FOR UPDATE'));
    expect(f, contains("SET zahlungsstatus = 'bezahlt'"));
  });

  test('Rücknahmen schreiben nur noch offen, Altwerte heben die Stufe', () {
    final z = block('CREATE OR REPLACE FUNCTION zahlung_zuruecknehmen(');
    expect(z, contains("zahlungsstatus = 'offen'"));
    expect(z, contains("rechnung_stufe_aus_altstatus(v_vor ->> 'zahlungsstatus')"));
    expect(z, contains('mahnung_stufe = v_stufe'));
    final a = block('CREATE OR REPLACE FUNCTION abschreibung_lauf_zuruecknehmen(');
    expect(a, contains("SET zahlungsstatus = 'offen'"));
    expect(a, contains('rechnung_stufe_aus_altstatus(p.status_vorher)'));
    for (final f in [z, a]) {
      for (final alt in ['gesendet', 'freigegeben', 'erinnert', 'mahnung_1', 'mahnung_2']) {
        expect(f, isNot(contains("'$alt'")), reason: alt);
      }
    }
  });

  test('view_mahnwesen_dashboard: Empfehlung aus mahnung_stufe, invoker', () {
    final i = pos('CREATE OR REPLACE VIEW view_mahnwesen_dashboard');
    final v = sql.substring(i, sql.indexOf(';', i));
    expect(v, contains('security_invoker = on'));
    expect(v, contains('r.mahnung_stufe = 1'));
    expect(v, contains('r.mahnung_stufe >= 3'));
    for (final alt in ['gesendet', 'erinnert', 'mahnung_1', 'mahnung_2']) {
      expect(v, isNot(contains("'$alt'")), reason: alt);
    }
  });

  test('Kopfvermerk: nur als EIN apply_migration-Aufruf (atomar)', () {
    final kopf = roh.substring(0, roh.indexOf('WARUM:'));
    expect(kopf, contains('apply_migration'));
    expect(kopf, contains('atomar'));
    expect(kopf, contains('BEGIN;'));
    expect(kopf, contains('COMMIT;'));
  });

  group('Rückweg (Kommentar am Ende)', () {
    late String rueck;
    setUpAll(() {
      final start = roh.indexOf('RÜCKWEG (nur im Notfall');
      expect(start, isNot(-1));
      rueck = roh.substring(start);
    });

    String statement(String anfang) {
      final i = rueck.indexOf(anfang);
      expect(i, isNot(-1), reason: 'nicht gefunden: $anfang');
      return rueck.substring(i, rueck.indexOf(';', i));
    }

    test('nur heute offene Rechnungen, nie bezahlt/abgeschrieben aus dem '
        'Snapshot', () {
      final u = statement('update rechnungen r set zahlungsstatus = case');
      expect(u, contains("r.zahlungsstatus = 'offen'"));
      // Der Snapshot-Status wird nie 1:1 übernommen — sonst käme eine nach
      // 211 zurückgenommene Zahlung als «bezahlt» zurück.
      expect(u, isNot(contains('= s.zahlungsstatus')));
      expect(u, isNot(contains('then x.s_status')));
      expect(u, isNot(contains("then 'bezahlt'")));
      expect(u, isNot(contains("then 'abgeschrieben'")));
      // Kein zweites Status-Update, das den Snapshot ungefiltert übernimmt.
      expect(
        RegExp('update rechnungen r set zahlungsstatus').allMatches(rueck).length,
        1,
      );
    });

    test('Mahnstufe vor Zustellung: nach 211 gemahnt → erinnert/mahnung_x, '
        'nicht gesendet', () {
      final u = statement('update rechnungen r set zahlungsstatus = case');
      final m2 = u.indexOf("r.mahnung_stufe >= 3 then 'mahnung_2'");
      final m1 = u.indexOf("r.mahnung_stufe = 2  then 'mahnung_1'");
      final er = u.indexOf("r.mahnung_stufe = 1  then 'erinnert'");
      final ge = u.indexOf("then 'gesendet'");
      for (final i in [m2, m1, er, ge]) {
        expect(i, isNot(-1), reason: u);
      }
      expect(m2, lessThan(ge));
      expect(m1, lessThan(ge));
      expect(er, lessThan(ge));
      // Heineken-Freigabe aus dem Feld (kennt auch «Auf gesendet zurücksetzen»).
      expect(
        u,
        contains(
          "r.rechnungstyp = 'heineken_monat' and r.freigegeben_am is not null "
          "then 'freigegeben'",
        ),
      );
    });

    test('Zahlungsgruppen nach 211 (vorher.zahlungsstatus = offen) werden '
        'nachgezogen, solange freigegeben_am noch da ist', () {
      expect(rueck, contains("vorher.zahlungsstatus = 'offen'"));
      final g = statement('update zahlungsgruppen g set vorher');
      expect(g, contains('g.zurueckgenommen_am is null'));
      expect(g, contains('snapshot_am'));
      expect(
        rueck.indexOf('update zahlungsgruppen g set vorher'),
        lessThan(rueck.indexOf('drop column freigegeben_am')),
      );
    });
  });

  test('Prüf-Queries am Ende (vorher/nachher, nichts ausserhalb des CHECK)', () {
    expect(roh, contains('P1:'));
    expect(roh, contains('P2:'));
    expect(roh, contains('P3:'));
  });
}
