import 'package:sbs_projer_app/data/models/camt_transaction.dart';

/// True, wenn die Transaktion in Bereich 1 (Kundenzahlungs-Abgleich) gehört.
/// Bereich 1 = Gutschrift, die weder Saldovortrag, Heineken noch Bargeld
/// (Geldautomaten-/Post-/SIX-Einzahlung) ist. Alles andere → Bereich 2.
/// Bewusst unabhängig von der Betrieb-Erkennung — der Abgleich in Bereich 1
/// sucht den Betrieb selbst (via effektiverZahlername).
bool istKundenzahlungsKandidat(CamtTransaction tx) {
  if (!tx.isCredit) return false;
  final info = '${tx.additionalInfo ?? ''} ${tx.partyName ?? ''}'.toLowerCase();
  if (info.contains('saldovortrag')) return false;
  if ((tx.partyName ?? '').toLowerCase().contains('heineken')) return false;
  if (info.contains('geldautomaten') ||
      info.contains('posteinzahlung') ||
      info.contains('six token')) {
    return false;
  }
  return true;
}
