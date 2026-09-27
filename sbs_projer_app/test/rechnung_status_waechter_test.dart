import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratsche: Rohe Vergleiche auf `rechnungen.zahlungsstatus` dürfen nur
/// weniger werden.
///
/// WARUM (Analyse 25.09.2026, Abschnitt 2): `zahlungsstatus` mischt Zahlung,
/// Zustellung und Mahnstufe. Jeder Filter, der die Werte selbst aufzählt,
/// vergisst früher oder später einen: Der Bankabgleich nahm nur `offen` und
/// `gesendet` (gemahnte Rechnungen hätten keine Zahlung mehr bekommen), und
/// «erledigt» (bezahlt/abgeschrieben) war an 14 Stellen selbst
/// ausgeschrieben, «gemahnt» an drei. Die Mengen stehen deshalb an EINER
/// Stelle: `istOffen`/`istZahlbar`/`istGemahnt`/`anzeigeStatus` in
/// `rechnung_status.dart`, `Zahlungsstatus.erledigt` in `zahlungsstatus.dart`.
/// Seit Migration 211 (27.09.2026) kennt der Status nur noch
/// offen/bezahlt/abgeschrieben — Mahnstufe (`mahnung_stufe`), Zustellung
/// (`versendet_am`) und Heineken-Freigabe (`freigegeben_am`) sind Felder.
///
/// Gezählt werden:
/// - `zahlungsstatus == 'x'` / `!= 'x'` (auch `row['zahlungsstatus']`),
/// - Abfrage-Filter mit Literal: `.eq('zahlungsstatus', 'x')`,
///   `.not('zahlungsstatus', 'in', …)`, `.inFilter('zahlungsstatus', [...])`,
///   `zahlungsstatus.eq.x` in `.or(...)`,
/// - selbst gebaute Mengen: `{'bezahlt', 'abgeschrieben'}`,
///   `['offen', 'gesendet']`.
///
/// Stehen bleiben dürfen (und sind im Zählstand enthalten) Stellen, die
/// BEWUSST einen einzelnen Wert meinen — Stand 27.09.2026 nach Migration 211:
/// - `aufgaben_detektoren_provider.dart`, `monats_pruef_provider.dart`,
///   `rechnung_versand_status.dart`: `offen` + `versendet_am` leer heisst
///   dort «noch nicht versendet» (Versandvermerk-Frühwarnung).
/// - `einzel_abschreibung.dart`: je ein eigener Grund für `bezahlt` und
///   `abgeschrieben`.
/// - `rechnung_detail_screen.dart`: «Zahlung rückgängig» nur bei `bezahlt`.
/// - `monats_regeln.dart`: die geordnete Heineken-Stufenleiter (seit 211
///   aus `heinekenStufe`, kein DB-Wert).
/// - `kontoauszug_pdf_service.dart`: getrennte Zeilen für bezahlt und
///   abgeschrieben im Kunden-PDF.
/// Mit 211 weggefallen: die Mahnstufen-Vergleiche (`mahnregeln.dart`,
/// `mahnfall_service.dart`, `mahn_hinweis.dart`, `abschluss_regeln.dart` —
/// jetzt `mahnstufeVon`/`istGemahnt`), die Heineken-Freigabe
/// (`zaehltAlsForderung` → `freigegeben_am`) und die zwei offenen Mengen im
/// Kontoauszug (→ `istOffen`).
///
/// Nicht gezählt: die Definitionen selbst und der Heineken-Workflow
/// (`offen → gesendet → freigegeben → bezahlt`, jeder Schritt ein eigener
/// Knopf mit eigener Bedingung).
///
/// Wer eine der gezählten Dateien anfasst, stellt deren Mengen um und senkt
/// den Wert hier. Er darf nur sinken.
void main() {
  test('rohe zahlungsstatus-Vergleiche werden nicht mehr', () {
    // Startwert 27.09.2026 (B2): 47 Treffer vor der Umstellung, 26 davon
    // auf istOffen / Zahlungsstatus.erledigt / .gemahnt umgestellt → 21.
    // Migration 211 (Statusmodell-Zielbild, 27.09.2026): 21 → 11.
    // Darf nur sinken.
    const erlaubt = 11;

    const werte = 'offen|gesendet|freigegeben|bezahlt|erinnert|mahnung_1|'
        'mahnung_2|abgeschrieben';
    final muster = [
      // r.zahlungsstatus == 'offen', row['zahlungsstatus'] != 'bezahlt'
      RegExp("zahlungsstatus'?\\]?\\s*[!=]=\\s*'($werte)'"),
      // 'offen' == r.zahlungsstatus
      RegExp("'($werte)'\\s*[!=]=\\s*[\\w.!?\\[\\]']*zahlungsstatus"),
      // .eq('zahlungsstatus', 'offen'), .inFilter('zahlungsstatus', ['…'])
      RegExp(r"\.(eq|neq)\(\s*'zahlungsstatus'\s*,\s*'"),
      RegExp(r"\.inFilter\(\s*'zahlungsstatus'\s*,\s*(const\s*)?\[\s*'"),
      // .not('zahlungsstatus', 'in', '("bezahlt",…)'),
      // .filter('zahlungsstatus', 'eq', 'offen') — der WERT ist ein Literal
      RegExp(
        r"""\.(not|filter)\(\s*'zahlungsstatus'\s*,\s*'\w+'\s*,\s*'\(?\s*["'a-z]""",
      ),
      // .or('zahlungsstatus.eq.offen,…'), 'zahlungsstatus.in.(offen,…)'
      RegExp(r"""zahlungsstatus\.(eq\.|neq\.|in\.\(\s*["'a-z])"""),
      // selbst gebaute Mengen, die NUR aus Statuswerten bestehen:
      // {'bezahlt', 'abgeschrieben'}, ['offen', 'gesendet'] — nicht
      // {'bezahlt', 'abgeschrieben', 'zurueckgezogen'} (Mahnfall-Erledigung).
      RegExp(
        "[\\[{]\\s*('($werte)'\\s*,\\s*)+'($werte)'\\s*,?\\s*[\\]}]",
      ),
    ];
    const ausgenommen = {
      // Die Definitionen der Mengen.
      'lib/core/util/zahlungsstatus.dart',
      'lib/core/util/rechnung_status.dart',
      // Heineken-Workflow: jeder Schritt ein eigener Einzelwert.
      'lib/presentation/screens/heineken/',
      'lib/services/camt/heineken_matcher.dart',
    };

    final treffer = <String>[];
    final dateien = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    for (final f in dateien) {
      final pfad = f.path.replaceAll('\\', '/');
      if (ausgenommen.any(pfad.contains)) continue;
      final zeilen = f.readAsLinesSync();
      for (var i = 0; i < zeilen.length; i++) {
        final k = zeilen[i].indexOf('//');
        final code = k == -1 ? zeilen[i] : zeilen[i].substring(0, k);
        // Jede Fundstelle zählt — `a != 'x' && a != 'y'` auf einer Zeile
        // sind zwei.
        final n = muster.fold(0, (s, m) => s + m.allMatches(code).length);
        for (var j = 0; j < n; j++) {
          treffer.add('$pfad:${i + 1}');
        }
      }
    }

    expect(
      treffer.length,
      lessThanOrEqualTo(erlaubt),
      reason:
          'Es gibt ${treffer.length} rohe zahlungsstatus-Vergleiche, erlaubt '
          'sind $erlaubt. Mengen gehören nicht in den Code — istOffen/'
          'istZahlbar/anzeigeStatus (rechnung_status.dart) bzw. '
          'Zahlungsstatus.erledigt/.gemahnt (zahlungsstatus.dart). Wer eine '
          'Datei anfasst, stellt deren Vergleiche um und senkt den Wert '
          'hier.\n${treffer.join('\n')}',
    );
  });
}
