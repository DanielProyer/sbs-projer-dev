import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';

/// Vorgeschlagene Konten für eine Eingangsrechnung.
class KontoVorschlag {
  final int? aufwandskonto;
  final int? vorsteuerKonto;
  const KontoVorschlag({this.aufwandskonto, this.vorsteuerKonto});
}

/// Schlägt Aufwands-/Vorsteuerkonto vor. Reihenfolge:
/// 1. Aussteller-Regel (spezifisch) — komplett übernehmen (autoritativ).
/// 2. Kategorie-Default (aus der Config-Tabelle).
/// 3. sonst leer (manuell).
///
/// [mwstRelevant] steuert NUR den Kategorie-Zweig: ist die Rechnung nicht
/// MwSt-relevant (nicht pflichtig oder Satz 0), wird der Vorsteuer-Default der
/// Kategorie unterdrückt. Die Aussteller-Regel bleibt autoritativ (unberührt).
KontoVorschlag schlageKontoVor({
  required String? kategorie,
  required List<EingangsrechnungKategorie> kategorien,
  KreditorRegel? regelTreffer,
  bool mwstRelevant = true,
}) {
  if (regelTreffer != null) {
    return KontoVorschlag(
      aufwandskonto: regelTreffer.aufwandskonto,
      vorsteuerKonto: regelTreffer.vorsteuerKonto,
    );
  }
  if (kategorie != null) {
    for (final k in kategorien) {
      if (k.code == kategorie) {
        return KontoVorschlag(
          aufwandskonto: k.defaultAufwandskonto,
          vorsteuerKonto: mwstRelevant ? k.defaultVorsteuerKonto : null,
        );
      }
    }
  }
  return const KontoVorschlag();
}
