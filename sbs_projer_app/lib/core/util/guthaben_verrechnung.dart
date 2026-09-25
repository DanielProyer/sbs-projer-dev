/// Verrechnung von Kundenguthaben beim Zahlungseingang — reine Logik, testbar.
///
/// Eine Rechnung mit `guthabenVerrechnet > 0` wurde dem Kunden mit
/// «abzüglich Guthaben» gestellt: Er zahlt nur [Rechnung.zuZahlen]. Beim
/// Zuordnen bucht die App die Zahlung (1020/1100 bzw. 1000/1100) über
/// «zu zahlen» und zusätzlich **Soll 2030 / Haben 1100** über das Guthaben —
/// so ist der Debitor ausgeglichen, ohne dass die Differenz als Verlust 3805
/// endet (Plan 2026-09-25-kundenguthaben, Task 3).
///
/// Zahlt der Kunde trotz Guthaben den vollen Betrag (Zahlung >
/// zu zahlen + 5 Rappen), wird NICHT verrechnet: Die Zahlung gilt gegen das
/// Brutto, `guthaben_verrechnet` der Rechnung geht auf 0 zurück und das
/// Guthaben bleibt auf 2030 für die nächste Rechnung stehen.
library;

import 'package:sbs_projer_app/core/util/guthaben.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';

/// Toleranz, bis zu der eine Zahlung noch als «zu zahlen» gilt.
const double kGuthabenToleranz = 0.05;

/// Wird das Guthaben verrechnet? Nur wenn Guthaben da ist und die Zahlung
/// höchstens «zu zahlen» + 5 Rappen beträgt (alles 5-Rappen-gerundet).
bool guthabenWirdVerrechnet({
  required double zahlung,
  required double summeZuZahlen,
  required double summeGuthaben,
}) {
  if (rundeAuf5Rappen(summeGuthaben) <= 0) return false;
  return rundeAuf5Rappen(zahlung) <=
      rundeAuf5Rappen(summeZuZahlen) + kGuthabenToleranz + 1e-9;
}

/// Eine Rechnung im Buchungsplan.
class ZahlungsPlanZeile {
  final Rechnung rechnung;

  /// Zahlungseingang Soll 1020 (bzw. 1000) / Haben 1100. 0 = keine Zeile.
  final double bank;

  /// Verrechnung Soll 2030 / Haben 1100. 0 = keine Zeile.
  final double verrechnung;

  const ZahlungsPlanZeile(this.rechnung, this.bank, this.verrechnung);
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
  /// für diese Rechnung tatsächlich zu zahlen hatte.
  double gezahltFuer(Rechnung r) =>
      guthabenVerrechnet ? r.zuZahlen : r.betragBrutto;
}

/// Plant die Buchungen einer (Sammel-)Zahlung über [rechnungen].
///
/// - Hauptzeile je Rechnung = «zu zahlen» (bzw. Brutto ohne Verrechnung),
///   5-Rappen-gerundet; bei erlassener Minderzahlung wird die LETZTE Zeile
///   um den Verlust gekürzt (Bank erhält nur den Zahlbetrag).
/// - Verrechnungszeile je Rechnung mit Guthaben (nur wenn verrechnet).
/// - Differenz gegen die Summe der Hauptzeilen-Basis.
DifferenzPlan differenzPlan(List<Rechnung> rechnungen, double zahlbetrag) {
  final zahlung = rundeAuf5Rappen(zahlbetrag);
  var summeZuZahlen = 0.0;
  var summeGuthaben = 0.0;
  for (final r in rechnungen) {
    summeZuZahlen += rundeAuf5Rappen(r.zuZahlen);
    summeGuthaben += r.guthabenVerrechnet > 0
        ? rundeAuf5Rappen(r.guthabenVerrechnet)
        : 0;
  }
  final verrechnen = guthabenWirdVerrechnet(
    zahlung: zahlung,
    summeZuZahlen: summeZuZahlen,
    summeGuthaben: summeGuthaben,
  );
  final zuruecksetzen = !verrechnen && rundeAuf5Rappen(summeGuthaben) > 0;

  double basis(Rechnung r) =>
      rundeAuf5Rappen(verrechnen ? r.zuZahlen : r.betragBrutto);

  var summeBasis = 0.0;
  for (final r in rechnungen) {
    summeBasis += basis(r);
  }
  summeBasis = rundeAuf5Rappen(summeBasis);
  final differenz = rundeAuf5Rappen(zahlung - summeBasis);

  final kuerzung = (differenz < 0 &&
          rechnungen.isNotEmpty &&
          differenz.abs() < basis(rechnungen.last))
      ? rundeAuf5Rappen(differenz.abs())
      : 0.0;

  final zeilen = <ZahlungsPlanZeile>[
    for (var i = 0; i < rechnungen.length; i++)
      ZahlungsPlanZeile(
        rechnungen[i],
        i == rechnungen.length - 1
            ? rundeAuf5Rappen(basis(rechnungen[i]) - kuerzung)
            : basis(rechnungen[i]),
        verrechnen && rechnungen[i].guthabenVerrechnet > 0
            ? rundeAuf5Rappen(rechnungen[i].guthabenVerrechnet)
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

/// Betrag einer Forderung für Abgleich-Listen: «zu zahlen», bei Guthaben
/// mit Hinweis.
String forderungBetragText(Rechnung r) {
  if (r.guthabenVerrechnet <= 0) {
    return '${r.betragBrutto.toStringAsFixed(2)} CHF';
  }
  return '${r.zuZahlen.toStringAsFixed(2)} CHF '
      '(nach Guthaben ${r.guthabenVerrechnet.toStringAsFixed(2)})';
}
