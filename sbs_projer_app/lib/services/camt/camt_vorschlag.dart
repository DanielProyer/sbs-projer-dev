import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

enum CamtVorschlagTyp { ausgabe, heineken }

/// Ein vorgeschlagener Buchungsvorgang aus Bereich 2 (Übriges), der in der
/// Bestätigungs-Phase NICHT automatisch gebucht, sondern vom Benutzer
/// bestätigt werden muss. Hält die Live-Objekte (tx + Vorlage/Rechnung), damit
/// die Buchung über die bestehenden Booker laufen kann.
class CamtVorschlag {
  final CamtTransaction tx;
  final CamtVorschlagTyp typ;
  final BuchungsVorlage? vorlage; // bei typ == ausgabe
  final Rechnung? heinekenRechnung; // bei typ == heineken
  final String label; // z.B. "Büromiete → 6000"

  CamtVorschlag({
    required this.tx,
    required this.typ,
    this.vorlage,
    this.heinekenRechnung,
    required this.label,
  });
}

/// Ergebnis der Plan-Phase: bestätigbare Vorschläge + manuelle (Prüfliste) +
/// übersprungene (Saldovortrag etc.).
class CamtPlanErgebnis {
  final List<CamtVorschlag> vorschlaege;
  final List<CamtTransaction> pruefliste;
  final int uebersprungen;

  CamtPlanErgebnis(this.vorschlaege, this.pruefliste, this.uebersprungen);
}
