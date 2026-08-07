import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

/// Matcht camt-Transaktionen automatisch mit Betrieben.
/// Strategie: Exakt → Contains → Wort-Overlap.
class CamtBetriebMatcher {
  /// Matcht Transaktionen gegen eine Liste von Betrieben.
  /// betriebe: Liste von {id, name}-Maps.
  static void matchAll(
    List<CamtTransaction> transactions,
    List<Map<String, String>> betriebe,
  ) {
    for (final tx in transactions) {
      final match = findBestMatch(tx.partyName, betriebe);
      if (match != null) {
        tx.matchedBetriebId = match['id'];
        tx.matchedBetriebName = match['name'];
      }
    }
  }

  /// Stufe 2 der Matching-Kette: exakter Treffer gegen gelernte Zahler-Aliase.
  /// Die [betriebe]-Maps tragen optional `aliase` = normalisierte Aliase, mit
  /// Zeilenumbruch verbunden. Liefert den EINDEUTIGEN Betrieb oder null
  /// (0 oder mehrere Treffer).
  static Map<String, String>? matchByAlias(
    String? zahlername,
    List<Map<String, String>> betriebe,
  ) {
    if (zahlername == null) return null;
    final norm = zahlernameNorm(zahlername);
    if (norm.isEmpty) return null;
    Map<String, String>? treffer;
    for (final b in betriebe) {
      final aliase = (b['aliase'] ?? '')
          .split('\n')
          .where((a) => a.trim().isNotEmpty);
      if (aliase.any((a) => zahlernameNorm(a) == norm)) {
        if (treffer != null) return null; // mehrdeutig → kein Auto-Treffer
        treffer = b;
      }
    }
    return treffer;
  }

  /// „Sicherer" exakter Namens-Treffer: Parteiname == Betriebsname (getrimmt,
  /// case-insensitive). Liefert nur bei EINDEUTIGKEIT den Betrieb, sonst null
  /// (0 oder mehrere gleichnamige). Anders als [findBestMatch] rein exakt —
  /// dient (neben [matchByAlias]) als auto-fähige Vertrauensquelle.
  static Map<String, String>? matchExakt(
    String? partyName,
    List<Map<String, String>> betriebe,
  ) {
    if (partyName == null || partyName.trim().isEmpty) return null;
    final p = partyName.toLowerCase().trim();
    Map<String, String>? treffer;
    for (final b in betriebe) {
      if (b['name']!.toLowerCase().trim() == p) {
        if (treffer != null) return null; // mehrdeutig → nicht sicher
        treffer = b;
      }
    }
    return treffer;
  }

  /// Matcht eine im Verwendungszweck genannte **Betriebnummer** (z.B. Davos
  /// Klosters Bergbahnen / Weisse Arena: `0151_2026_04_04` → Heineken-Nr. 0151
  /// = Armando Klosters). Leading-Zero-tolerant (Zahlvergleich).
  ///
  /// Vorrang-Stufen (Fix 07.08.2026): Zuerst NUR `heineken_nr` — das ist die
  /// eigene Betriebsnummer und DB-weit eindeutig. Erst wenn dort nichts trifft,
  /// zählen `we_nummer`/`ag_nummer`. Die Hausnummer `nr` zählt gar nicht mehr:
  /// 185 Betriebe hatten eine Haus-/WE-/AG-Nummer, die mit der heineken_nr
  /// eines anderen Betriebs kollidierte → «mehrdeutig» → das Routing der
  /// Sammelzahler (Weisse Arena, Davos Klosters) fiel auf den unscharfen
  /// Namens-Match zurück und traf den falschen Betrieb.
  static Map<String, String>? matchByNummer(
    String? nummer,
    List<Map<String, String>> betriebe,
  ) {
    final norm = _normNr(nummer);
    if (norm == null) return null;
    // Stufe 1: eigene Betriebsnummer (heineken_nr) — eindeutig oder gar nicht.
    Map<String, String>? treffer;
    for (final b in betriebe) {
      if (_normNr(b['heineken_nr']) == norm) {
        if (treffer != null) return null; // mehrdeutig
        treffer = b;
      }
    }
    if (treffer != null) return treffer;
    // Stufe 2: WE-/AG-Nummer (Heineken-Fremdnummern). Hausnummer `nr` bewusst
    // NICHT — eine Strassen-Hausnummer identifiziert keinen Betrieb.
    for (final b in betriebe) {
      if ([b['we_nummer'], b['ag_nummer']].any((k) => _normNr(k) == norm)) {
        if (treffer != null) return null; // mehrdeutig
        treffer = b;
      }
    }
    return treffer;
  }

  /// Normalisiert eine Nummer für den Vergleich: führende Nullen egal
  /// (`0151` == `151`), sonst getrimmt/kleingeschrieben. Null bei leer.
  static String? _normNr(String? s) {
    final t = s?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    return n != null ? n.toString() : t.toLowerCase();
  }

  /// Findet den besten Betrieb-Match für einen Parteinamen.
  static Map<String, String>? findBestMatch(
    String? partyName,
    List<Map<String, String>> betriebe,
  ) {
    if (partyName == null || partyName.isEmpty) return null;
    final partyLower = partyName.toLowerCase().trim();

    // 1. Exakter Match
    for (final b in betriebe) {
      if (b['name']!.toLowerCase().trim() == partyLower) return b;
    }

    // 2. Contains (Betriebsname in Parteiname oder umgekehrt)
    for (final b in betriebe) {
      final betriebLower = b['name']!.toLowerCase().trim();
      if (partyLower.contains(betriebLower) ||
          betriebLower.contains(partyLower)) {
        return b;
      }
    }

    // 3. Wort-Overlap (mind. 2 Wörter oder 1 langes Wort)
    final partyWords = _significantWords(partyLower);
    Map<String, String>? bestMatch;
    int bestScore = 0;

    for (final b in betriebe) {
      final betriebWords = _significantWords(b['name']!.toLowerCase());
      final overlap = partyWords.intersection(betriebWords).length;
      if (overlap > bestScore && (overlap >= 2 || (overlap == 1 && partyWords.first.length >= 6))) {
        bestScore = overlap;
        bestMatch = b;
      }
    }

    return bestMatch;
  }

  /// Extrahiert signifikante Wörter (≥3 Zeichen, keine Rechtsform-Abkürzungen).
  static Set<String> _significantWords(String text) {
    const ignore = {'gmbh', 'ag', 'und', 'the', 'zum', 'zur', 'der', 'die', 'das', 'von'};
    return text
        .split(RegExp(r'[\s,.\-/+&]+'))
        .where((w) => w.length >= 3 && !ignore.contains(w))
        .toSet();
  }
}
