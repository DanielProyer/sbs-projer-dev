import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';

/// Ordnet eine camt-Belastung (DBIT/Ausgang) einer offenen Eingangsrechnung zu.
///
/// Reine Funktion (kein IO) — die Kandidaten (offene, Stufe-1-gebuchte
/// Eingangsrechnungen) werden übergeben. Reihenfolge der Match-Kette:
/// 1. strukturierte Referenz (QRR/SCOR, normalisiert) + Betrag — **maßgeblich**:
///    Ist eine Referenz vorhanden, entscheidet sie allein (eindeutig oder
///    manuell); kein Durchfallen auf schwächere Kriterien.
/// 2. Lieferant-IBAN + Betrag
/// 3. Aussteller-Name (token-basiert, ganze Wörter) + Betrag
/// Mehrdeutig (>1 Treffer) oder kein Treffer -> null (Bestätigungs-Flow ->
/// Prüfliste / manuell). Lieber False-Negative (manuell) als False-Positive
/// (Fehlbuchung).
class KreditorenAbgleichService {
  /// Rechtsform-Tokens, die beim Namensvergleich ignoriert werden.
  static const _rechtsform = {
    'ag', 'gmbh', 'sa', 'sarl', 'sagl', 'ltd', 'inc', 'co', 'kg', 'llc'
  };

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
  static bool _betragGleich(double a, double b) => _round2(a) == _round2(b);
  static String _ibanNorm(String? s) =>
      (s ?? '').replaceAll(' ', '').toUpperCase();

  /// Tokenisiert einen Namen: Kleinbuchstaben, ohne Satzzeichen/Rechtsform.
  static Set<String> _tokens(String? s) {
    final n = (s ?? '').toLowerCase().replaceAll(RegExp('[^a-z0-9äöü ]'), ' ');
    return n
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_rechtsform.contains(t))
        .toSet();
  }

  static Eingangsrechnung? match(
      CamtTransaction tx, List<Eingangsrechnung> kandidaten) {
    if (tx.isCredit) return null; // nur Belastungen (Ausgang)
    final betrag = tx.amount;

    // 1) strukturierte Referenz (QRR/SCOR) — maßgeblich, wenn vorhanden.
    final ref = scorRefNorm(tx.strukturierteReferenz ?? '');
    if (ref.isNotEmpty) {
      final t = kandidaten
          .where((e) =>
              scorRefNorm(e.qrReferenz ?? '') == ref &&
              _betragGleich(e.betragBrutto, betrag))
          .toList();
      if (t.length == 1) return t.first;
      // Referenz vorhanden, aber 0 oder >1 Treffer => Widerspruch -> manuell.
      // KEIN Durchfallen auf IBAN/Name (sonst würde die FALSCHE Rechnung
      // desselben Lieferanten mit zufällig gleichem Betrag gebucht).
      return null;
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

    // 3) Aussteller-Name (token-basiert) + Betrag.
    final txTokens = _tokens(tx.partyName);
    if (txTokens.isNotEmpty) {
      final t = kandidaten.where((e) {
        final anTokens = _tokens(e.ausstellerName);
        if (anTokens.isEmpty) return false;
        // Mind. ein signifikantes Token (>=4 Zeichen) gegen Kurznamen-Fehl-
        // treffer; ALLE Aussteller-Tokens müssen als ganze Wörter im
        // Bank-Namen vorkommen (verhindert 'Post' -> 'PostFinance').
        final signifikant = anTokens.any((tok) => tok.length >= 4);
        return signifikant &&
            anTokens.every(txTokens.contains) &&
            _betragGleich(e.betragBrutto, betrag);
      }).toList();
      if (t.length == 1) return t.first;
      if (t.length > 1) return null;
    }
    return null;
  }
}
