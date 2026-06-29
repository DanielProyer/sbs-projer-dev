import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/data/models/kreditor_regel.dart';

/// Vorgeschlagene Konten für eine Eingangsrechnung.
class KontoVorschlag {
  final int? aufwandskonto;
  final int? vorsteuerKonto;
  const KontoVorschlag({this.aufwandskonto, this.vorsteuerKonto});
}

/// Schlägt Aufwands-/Vorsteuerkonto vor. Reihenfolge:
/// 1. Aussteller-Regel (spezifisch) — komplett übernehmen.
/// 2. Kategorie-Default (aus der Config-Tabelle).
/// 3. sonst leer (manuell).
KontoVorschlag schlageKontoVor({
  required String? kategorie,
  required List<EingangsrechnungKategorie> kategorien,
  KreditorRegel? regelTreffer,
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
          vorsteuerKonto: k.defaultVorsteuerKonto,
        );
      }
    }
  }
  return const KontoVorschlag();
}
