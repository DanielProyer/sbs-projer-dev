import 'package:sbs_projer_app/data/models/camt_regel.dart';

class RegelMatcher {
  /// Vorlage-ID der am besten passenden aktiven Regel, sonst null.
  /// Match: match_iban == partyIban ODER match_name als Substring in
  /// "partyName additionalInfo remittanceInfo" (case-insensitive).
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
    CamtRegel? best;
    for (final r in regeln) {
      final ibanHit = r.matchIban != null && r.matchIban!.isNotEmpty &&
          r.matchIban == partyIban;
      final nameHit = r.matchName != null && r.matchName!.isNotEmpty &&
          text.contains(r.matchName!.toLowerCase());
      if (ibanHit || nameHit) {
        if (best == null || r.prioritaet > best.prioritaet) best = r;
      }
    }
    return best?.buchungsVorlageId;
  }
}
