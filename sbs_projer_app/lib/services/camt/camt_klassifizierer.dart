import 'package:sbs_projer_app/data/models/camt_transaction.dart';

enum TxKategorie {
  kundenzahlung, heinekenEingang, bargeldEinzahlung, ausgabe,
  saldovortrag, unbekannt,
}

class CamtKlassifizierer {
  static TxKategorie kategorie(CamtTransaction tx, {required bool betriebErkannt}) {
    final info = '${tx.additionalInfo ?? ''} ${tx.partyName ?? ''}'.toLowerCase();
    if (info.contains('saldovortrag')) return TxKategorie.saldovortrag;
    if (tx.isCredit) {
      if ((tx.partyName ?? '').toLowerCase().contains('heineken')) {
        return TxKategorie.heinekenEingang;
      }
      if (info.contains('geldautomaten') || info.contains('posteinzahlung') ||
          info.contains('six token')) {
        return TxKategorie.bargeldEinzahlung;
      }
      if (betriebErkannt) return TxKategorie.kundenzahlung;
      return TxKategorie.unbekannt;
    }
    return TxKategorie.ausgabe; // Ausgaben-Regelwerk in Phase 2; vorerst Prüfliste
  }
}
