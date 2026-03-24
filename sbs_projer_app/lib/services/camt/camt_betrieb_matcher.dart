import 'package:sbs_projer_app/data/models/camt_transaction.dart';

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
