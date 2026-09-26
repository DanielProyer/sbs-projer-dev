/// Verrechnung von Kundenguthaben beim Zahlungseingang — reine Logik, testbar.
///
/// Eine Rechnung mit `guthabenVerrechnet > 0` wurde dem Kunden mit
/// «abzüglich Guthaben» gestellt: Er zahlt nur [Rechnung.zuZahlen]. Beim
/// Zuordnen bucht die App die Zahlung (1020/1100 bzw. 1000/1100) über
/// «zu zahlen» und zusätzlich **Soll 2030 / Haben 1100** über das Guthaben —
/// so ist der Debitor ausgeglichen, ohne dass die Differenz als Verlust 3805
/// endet (Plan 2026-09-25-kundenguthaben, Task 3).
///
/// Zahlt der Kunde trotz Guthaben (praktisch) den vollen Betrag — Zahlung ≥
/// Brutto − 5 Rappen —, wird NICHT verrechnet: Die Zahlung gilt gegen das
/// Brutto, `guthaben_verrechnet` der Rechnung geht auf 0 zurück und das
/// Guthaben bleibt auf 2030 für die nächste Rechnung stehen. Alles darunter
/// verrechnet das Guthaben; ein Rest über «zu zahlen» ist Mehrzahlung
/// (Review I1: 120 bei 143.75 / Guthaben 30 → 113.75 + 30 + 6.25 auf 8000).
library;

import 'dart:convert';

import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';

/// Toleranz unter dem Brutto, ab der eine Zahlung als «voll bezahlt» gilt.
const double kGuthabenToleranz = 0.05;

/// Wird das Guthaben verrechnet? Nur wenn Guthaben da ist und die Zahlung
/// unter Brutto − 5 Rappen liegt (alles 5-Rappen-gerundet).
bool guthabenWirdVerrechnet({
  required double zahlung,
  required double summeBrutto,
  required double summeGuthaben,
}) {
  if (rundeAuf5Rappen(summeGuthaben) <= 0) return false;
  return rundeAuf5Rappen(zahlung) <
      rundeAuf5Rappen(summeBrutto) - kGuthabenToleranz - 1e-9;
}

/// Ganz durch Guthaben gedeckt: nichts zu zahlen (Review I2). Solche
/// Rechnungen werden beim Anlegen sofort verrechnet und bezahlt gesetzt.
bool istVollMitGuthabenGedeckt(Rechnung r) =>
    r.guthabenVerrechnet > 0 && r.zuZahlen < 0.005;

/// Eine Rechnung im Buchungsplan.
class ZahlungsPlanZeile {
  final Rechnung rechnung;

  /// Zahlungseingang Soll 1020 (bzw. 1000) / Haben 1100. 0 = keine Zeile.
  final double bank;

  /// Verrechnung Soll 2030 / Haben 1100. 0 = keine Zeile.
  final double verrechnung;

  /// Wird `guthaben_verrechnet` auf 0 zurückgesetzt: der alte Wert (für die
  /// Notiz der Zahlungsbuchung, damit «Zahlung rückgängig» ihn
  /// zurückschreiben kann — Review I5). Sonst 0.
  final double guthabenVorher;

  const ZahlungsPlanZeile(this.rechnung, this.bank, this.verrechnung,
      {this.guthabenVorher = 0});
}

/// Was beim Zuordnen einer Zahlung gebucht wird.
class DifferenzPlan {
  final List<ZahlungsPlanZeile> zeilen;

  /// > 0 Mehrzahlung (8000), < 0 Minderzahlung (3805), 5-Rappen-gerundet.
  final double differenz;

  /// Guthaben wird verrechnet (Verrechnungszeilen vorhanden).
  final bool guthabenVerrechnet;

  /// Zahlung deckte den vollen Betrag trotz Guthaben: `guthaben_verrechnet`
  /// der Rechnungen auf 0 zurücksetzen, Guthaben bleibt bestehen.
  final bool guthabenZuruecksetzen;

  /// Hinweis für Log/Oberfläche, oder null.
  final String? hinweis;

  const DifferenzPlan({
    required this.zeilen,
    required this.differenz,
    required this.guthabenVerrechnet,
    required this.guthabenZuruecksetzen,
    this.hinweis,
  });

  double get summeVerrechnung => rundeAufRappen(
      zeilen.fold<double>(0, (s, z) => s + z.verrechnung));

  /// `zahlung_betrag` der Rechnung beim Setzen auf bezahlt: was der Kunde
  /// für diese Rechnung zu zahlen hatte.
  double gezahltFuer(Rechnung r) =>
      guthabenVerrechnet ? r.zuZahlen : r.betragBrutto;
}

/// Plant die Buchungen einer (Sammel-)Zahlung über [rechnungen].
///
/// - Hauptzeile je Rechnung = «zu zahlen» (bzw. Brutto ohne Verrechnung),
///   5-Rappen-gerundet. Bei erlassener Minderzahlung wird der Verlust von
///   HINTEN über die Hauptzeilen verteilt (je höchstens deren Basis) — die
///   Bank erhält genau den Zahlbetrag (Review I4).
/// - Verrechnungszeile je Rechnung mit Guthaben (nur wenn verrechnet).
/// - Differenz gegen die Summe der Hauptzeilen-Basis.
DifferenzPlan differenzPlan(List<Rechnung> rechnungen, double zahlbetrag) {
  // Der Zahlbetrag kommt von der Bank (camt) oder aus der Kasse — beides
  // rappengenau, nie auf 5 Rappen. Nur die Rechnungsbasis («zu zahlen»
  // /Brutto) ist 5-Rappen-gestellt (Review Runde 3, Bankbetrag-Falle
  // 94.03 auf 94.05: 1020 wäre sonst 94.05 gebucht worden, 2 Rappen vom
  // Kontoauszug abweichend).
  final zahlung = rundeAufRappen(zahlbetrag);
  var summeBrutto = 0.0;
  var summeGuthaben = 0.0;
  for (final r in rechnungen) {
    summeBrutto += rundeAuf5Rappen(r.betragBrutto);
    summeGuthaben += r.guthabenVerrechnet > 0
        ? rundeAuf5Rappen(r.guthabenVerrechnet)
        : 0;
  }
  final verrechnen = guthabenWirdVerrechnet(
    zahlung: zahlung,
    summeBrutto: summeBrutto,
    summeGuthaben: summeGuthaben,
  );
  final zuruecksetzen = !verrechnen && rundeAuf5Rappen(summeGuthaben) > 0;

  double basis(Rechnung r) =>
      rundeAuf5Rappen(verrechnen ? r.zuZahlen : r.betragBrutto);

  final basen = [for (final r in rechnungen) basis(r)];
  final summeBasis =
      rundeAuf5Rappen(basen.fold<double>(0, (s, b) => s + b));
  final differenz = rundeAufRappen(zahlung - summeBasis);

  // Verlust von hinten verteilen — rappengenau, damit die Bankzeilen in
  // Summe wieder exakt den (rappengenauen) Zahlbetrag ergeben.
  final bank = List<double>.of(basen);
  if (differenz < 0) {
    var rest = differenz.abs();
    for (var i = bank.length - 1; i >= 0 && rest > 0.001; i--) {
      final k = rest < bank[i] ? rest : bank[i];
      bank[i] = rundeAufRappen(bank[i] - k);
      rest = rundeAufRappen(rest - k);
    }
  }

  final zeilen = <ZahlungsPlanZeile>[
    for (var i = 0; i < rechnungen.length; i++)
      ZahlungsPlanZeile(
        rechnungen[i],
        bank[i],
        verrechnen && rechnungen[i].guthabenVerrechnet > 0
            ? rundeAuf5Rappen(rechnungen[i].guthabenVerrechnet)
            : 0,
        guthabenVorher: zuruecksetzen && rechnungen[i].guthabenVerrechnet > 0
            ? rechnungen[i].guthabenVerrechnet
            : 0,
      ),
  ];

  return DifferenzPlan(
    zeilen: zeilen,
    differenz: differenz,
    guthabenVerrechnet: verrechnen,
    guthabenZuruecksetzen: zuruecksetzen,
    hinweis: zuruecksetzen
        ? 'Zahlung deckt den vollen Rechnungsbetrag — Kundenguthaben CHF '
            '${rundeAuf5Rappen(summeGuthaben).toStringAsFixed(2)} nicht '
            'verrechnet, es bleibt auf $kKontoKundenguthaben bestehen'
        : null,
  );
}

/// Aktive Verrechnungsbuchung Soll 2030 / Haben 1100 (Belegtyp sonstiges).
bool istGuthabenVerrechnung(Buchung b) =>
    b.sollKonto == kKontoKundenguthaben &&
    b.habenKonto == 1100 &&
    b.belegTyp == 'sonstiges' &&
    zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId);

const _notizSchluessel = 'guthaben_verrechnet';

/// Notiz der Zahlungsbuchung, wenn `guthaben_verrechnet` beim Verbuchen auf
/// 0 gesetzt wurde — «Zahlung rückgängig» schreibt den Wert zurück (I5).
String guthabenNotiz(double vorher) => jsonEncode({_notizSchluessel: vorher});

/// Gesicherter `guthaben_verrechnet`-Wert aus einer Buchungsnotiz, oder
/// null (robust gegen fremde Notizen und Unsinn).
double? guthabenAusNotiz(String? notizen) {
  if (notizen == null || notizen.trim().isEmpty) return null;
  Object? roh;
  try {
    roh = jsonDecode(notizen);
  } catch (_) {
    return null;
  }
  if (roh is! Map) return null;
  final w = roh[_notizSchluessel];
  if (w is! num || w <= 0) return null;
  return w.toDouble();
}

/// Betrag einer Forderung für Abgleich-Listen: «zu zahlen», bei Guthaben
/// mit Hinweis.
String forderungBetragText(Rechnung r) {
  if (r.guthabenVerrechnet <= 0) {
    return '${r.betragBrutto.toStringAsFixed(2)} CHF';
  }
  return '${r.zuZahlen.toStringAsFixed(2)} CHF '
      '(nach Guthaben ${r.guthabenVerrechnet.toStringAsFixed(2)})';
}
