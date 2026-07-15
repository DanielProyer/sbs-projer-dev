import 'package:sbs_projer_app/data/models/camt_regel.dart';

class RegelMatcher {
  /// IBAN vergleichbar machen: Auf Rechnungen steht sie gruppiert
  /// („CH04 3000 0001 …"), im camt kompakt. Ohne Normalisierung würde eine
  /// von Hand eingetippte Regel-IBAN nie greifen.
  static String? normIban(String? s) {
    if (s == null) return null;
    final n = s.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return n.isEmpty ? null : n;
  }

  /// Vorlage-ID der am besten passenden aktiven Regel, sonst null.
  /// Match: match_iban == partyIban (normalisiert) ODER match_name als
  /// Substring in "partyName additionalInfo remittanceInfo" (case-insensitive).
  /// Höchste prioritaet gewinnt. remittanceInfo (Mitteilung) erlaubt z.B. die
  /// Trennung gleicher Empfänger nach Zweck (Lohn vs. „Miete Büro").
  static String? matchVorlageId({
    String? partyName,
    String? partyIban,
    String? additionalInfo,
    String? remittanceInfo,
    required List<CamtRegel> regeln,
  }) {
    final text =
        '${partyName ?? ''} ${additionalInfo ?? ''} ${remittanceInfo ?? ''}'
            .toLowerCase();
    final txIban = normIban(partyIban);
    CamtRegel? best;
    for (final r in regeln) {
      final regelIban = normIban(r.matchIban);
      final ibanHit =
          regelIban != null && txIban != null && regelIban == txIban;
      final nameHit = r.matchName != null && r.matchName!.isNotEmpty &&
          text.contains(r.matchName!.toLowerCase());
      if (ibanHit || nameHit) {
        if (best == null || r.prioritaet > best.prioritaet) best = r;
      }
    }
    return best?.buchungsVorlageId;
  }
}
