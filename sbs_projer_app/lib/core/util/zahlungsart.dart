/// Zahlungsart-Auflösung für Reinigungen.
///
/// Regel (Daniel, 16.07.2026): Die Zahlungsart der REINIGUNG ist allein
/// massgebend für Buchung + Rechnung. Der Betriebs-Wert ist nur der Default
/// (Vorbelegung + Fallback für Altbestand vor v0.50, dessen Feld NULL ist).
library;

const zahlungsarten = [
  'rechnung_mail', 'rechnung_post', 'rechnung_tresen',
  'barzahlung', 'jahresrechnung', 'heineken',
];

/// Arten, die eine EINZELrechnung mit QR erzeugen (camt-abgleichbar).
const rechnungsarten = {'rechnung_tresen', 'rechnung_mail', 'rechnung_post'};

String resolveZahlungsart(String? reinigungsWert, String? betriebsWert) {
  if (reinigungsWert != null && reinigungsWert.isNotEmpty) return reinigungsWert;
  if (betriebsWert != null && betriebsWert.isNotEmpty) return betriebsWert;
  // Sicherster Default: erzeugt Rechnung + Buchung — lieber eine Rechnung zu
  // viel (sichtbar, stornierbar) als eine lautlos fehlende.
  return 'rechnung_tresen';
}

bool istRechnungsart(String? art) => rechnungsarten.contains(art);

/// Erklärt VOR dem Abschluss, was die gewählte Art auslöst — die 38 fehlenden
/// Rechnungen blieben 3 Wochen unsichtbar, weil genau das nirgends stand.
String zahlungsartKlartext(String art, {required String? kundenEmail}) {
  switch (art) {
    case 'rechnung_tresen':
      return 'Rechnung + Einzahlungsschein, Übergabe vor Ort, kein Versand';
    case 'rechnung_mail':
      return kundenEmail == null || kundenEmail.isEmpty
          ? '⚠ Keine Rechnungsadresse-E-Mail — Rechnung geht NICHT an den Kunden'
          : 'Rechnung per Mail an $kundenEmail';
    case 'rechnung_post':
      return 'Rechnung per Mail an dich (Ausdrucken + Post)';
    case 'barzahlung':
      return 'Bar kassiert → Kasse, keine Rechnung';
    case 'heineken':
      return 'Keine Einzelrechnung — läuft über die Heineken-Monatsabrechnung';
    case 'jahresrechnung':
      return 'Keine Einzelrechnung — läuft über die Jahresrechnung';
    default:
      return art;
  }
}
