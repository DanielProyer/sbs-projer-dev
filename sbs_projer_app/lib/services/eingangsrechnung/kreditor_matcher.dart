import 'package:sbs_projer_app/data/models/kreditor_regel.dart';

/// Normalisiert IBAN/Referenz: Leerzeichen entfernen + Grossschreibung.
String _norm(String value) => value.replaceAll(' ', '').toUpperCase();

/// Findet die am besten passende aktive [KreditorRegel] für einen Scan.
///
/// Matching-Reihenfolge (vgl. Spec „Lernen — KreditorMatcher"):
///   1. IBAN exakt — wenn [iban] gesetzt ist und eine Regel mit gleicher
///      (normalisierter) IBAN existiert.
///   2. Name-Substring (case-insensitive) im [ausstellerName]:
///      a) mit passendem [referenz]-Präfix (höchste Priorität), sonst
///      b) eine namens-passende Regel OHNE Referenz-Präfix (höchste Priorität).
///   3. Sonst null.
KreditorRegel? matchKreditorRegel(
  List<KreditorRegel> regeln, {
  String? ausstellerName,
  String? iban,
  String? referenz,
}) {
  final aktive = regeln.where((r) => r.istAktiv).toList();

  // (1) IBAN exakt.
  if (iban != null && iban.isNotEmpty) {
    final ibanNorm = _norm(iban);
    for (final r in aktive) {
      if (r.lieferantIban != null &&
          r.lieferantIban!.isNotEmpty &&
          _norm(r.lieferantIban!) == ibanNorm) {
        return r;
      }
    }
  }

  // (2) Name-Substring.
  if (ausstellerName != null && ausstellerName.isNotEmpty) {
    final nameLower = ausstellerName.toLowerCase();
    final namensTreffer = aktive.where((r) =>
        r.lieferantNamePattern.isNotEmpty &&
        nameLower.contains(r.lieferantNamePattern.toLowerCase()));

    // (2a) mit Referenz-Präfix.
    if (referenz != null && referenz.isNotEmpty) {
      final refNorm = _norm(referenz);
      KreditorRegel? best;
      for (final r in namensTreffer) {
        if (r.referenzPraefix != null &&
            r.referenzPraefix!.isNotEmpty &&
            refNorm.startsWith(_norm(r.referenzPraefix!))) {
          if (best == null || r.prioritaet > best.prioritaet) best = r;
        }
      }
      if (best != null) return best;
    }

    // (2b) namens-passend OHNE Referenz-Präfix.
    KreditorRegel? best;
    for (final r in namensTreffer) {
      if (r.referenzPraefix == null || r.referenzPraefix!.isEmpty) {
        if (best == null || r.prioritaet > best.prioritaet) best = r;
      }
    }
    if (best != null) return best;
  }

  // (3) kein Treffer.
  return null;
}
