import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';

/// Ordnet eine camt-Belastung (DBIT/Ausgang) einer offenen Eingangsrechnung zu.
///
/// Reine Funktion (kein IO) — die Kandidaten (offene, Stufe-1-gebuchte
/// Eingangsrechnungen) werden übergeben. Reihenfolge der Match-Kette:
/// 1. strukturierte Referenz (QRR/SCOR, normalisiert) + Betrag
/// 2. Lieferant-IBAN + Betrag
/// 3. Aussteller-Name (Substring, beidseitig) + Betrag
/// Mehrdeutig (>1 Treffer auf einer Stufe) oder kein Treffer -> null
/// (landet im Bestätigungs-Flow in der Prüfliste / manuell).
class KreditorenAbgleichService {
  static double _round2(double v) => (v * 100).roundToDouble() / 100;
  static bool _betragGleich(double a, double b) => _round2(a) == _round2(b);
  static String _ibanNorm(String? s) =>
      (s ?? '').replaceAll(' ', '').toUpperCase();

  static Eingangsrechnung? match(
      CamtTransaction tx, List<Eingangsrechnung> kandidaten) {
    if (tx.isCredit) return null; // nur Belastungen (Ausgang)
    final betrag = tx.amount;

    // 1) strukturierte Referenz (QRR/SCOR) exakt + Betrag
    final ref = scorRefNorm(tx.strukturierteReferenz ?? '');
    if (ref.isNotEmpty) {
      final t = kandidaten
          .where((e) =>
              scorRefNorm(e.qrReferenz ?? '') == ref &&
              _betragGleich(e.betragBrutto, betrag))
          .toList();
      if (t.length == 1) return t.first;
      if (t.length > 1) return null; // mehrdeutig
    }

    // 2) Lieferant-IBAN + Betrag
    final iban = _ibanNorm(tx.partyIban);
    if (iban.isNotEmpty) {
      final t = kandidaten
          .where((e) =>
              _ibanNorm(e.lieferantIban) == iban &&
              _betragGleich(e.betragBrutto, betrag))
          .toList();
      if (t.length == 1) return t.first;
      if (t.length > 1) return null;
    }

    // 3) Aussteller-Name (Substring, beidseitig) + Betrag
    final name = (tx.partyName ?? '').toLowerCase().trim();
    if (name.isNotEmpty) {
      final t = kandidaten.where((e) {
        final an = (e.ausstellerName ?? '').toLowerCase().trim();
        if (an.isEmpty) return false;
        return (name.contains(an) || an.contains(name)) &&
            _betragGleich(e.betragBrutto, betrag);
      }).toList();
      if (t.length == 1) return t.first;
    }
    return null;
  }
}
