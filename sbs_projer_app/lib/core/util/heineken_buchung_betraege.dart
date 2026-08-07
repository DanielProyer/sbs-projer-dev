import 'package:sbs_projer_app/core/util/rundung.dart';

/// Beträge der Heineken-Hauptbuchung aus der Monatsrechnung ableiten.
///
/// Heineken wird ungerundet fakturiert (Regel Daniel 15.07.2026, siehe
/// `rundung.dart`) — die Buchung übernimmt Netto und Brutto der Rechnung
/// deshalb exakt (auf Rappen), OHNE 5-Rappen-Rundung. Die MwSt wird als
/// Differenz gebildet, damit die Invariante `brutto = netto + mwst`
/// konstruktiv gilt (`SaldoExpansion` bricht sonst im Debug-Build ab;
/// Befund B2 der Buchhaltungsprüfung 06.08.2026).
({double netto, double mwst, double brutto}) heinekenBuchungsBetraege(
    {required double netto, required double brutto}) {
  final n = rundeAufRappen(netto);
  final b = rundeAufRappen(brutto);
  return (netto: n, mwst: rundeAufRappen(b - n), brutto: b);
}
