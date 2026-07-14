import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Reinigungs-Rechnungen werden seit 30.05.2026 scharf versendet. Backfill-
/// Rechnungen (Excel-Import) liegen alle vor diesem Datum und werden dadurch
/// automatisch ausgeschlossen.
final _versandScharfAb = DateTime(2026, 5, 29);

/// Eine Mail-/Post-Rechnung ab Scharfstellung, die noch `offen` ist und kein
/// Versanddatum hat, wurde erzeugt aber nie versendet (Versand fehlgeschlagen).
/// Dient als Frühwarnung, damit keine erzeugte Rechnung unversendet liegen bleibt.
bool rechnungNichtVersendet(Rechnung r) {
  final va = r.versandart;
  if (va != 'rechnung_mail' && va != 'rechnung_post') return false;
  if (r.zahlungsstatus != 'offen') return false;
  if (r.versendetAm != null) return false;
  return r.rechnungsdatum.isAfter(_versandScharfAb);
}
