/// Zahlungsart-Auflösung für Reinigungen.
///
/// Regel (Daniel, 16.07.2026): Die Zahlungsart der REINIGUNG ist allein
/// massgebend für Buchung + Rechnung. Der Betriebs-Wert ist nur der Default
/// (Vorbelegung + Fallback für Altbestand vor v0.50, dessen Feld NULL ist).
library;

import 'package:sbs_projer_app/core/util/scor_referenz.dart';

const zahlungsarten = [
  'rechnung_mail',
  'rechnung_post',
  'rechnung_tresen',
  'barzahlung',
  'jahresrechnung',
  'heineken',
];

/// Arten, die eine EINZELrechnung mit QR erzeugen (camt-abgleichbar).
const rechnungsarten = {'rechnung_tresen', 'rechnung_mail', 'rechnung_post'};

/// ⚠️ Der 'rechnung_tresen'-Rückfall unten greift beim BETRIEBSWEG praktisch
/// nie — er ist kein Schutznetz für einen Betrieb ohne erfasste Rechnungsart.
///
/// Geprüft am 20.09.2026, nachdem ich genau das Gegenteil behauptet hatte:
/// * `betriebe.rechnungsstellung` hat in der Datenbank den Spalten-Default
///   `'rechnung_mail'` und eine CHECK-Liste der sechs gültigen Werte. Ein
///   leerer String ist dort **nicht erlaubt**.
/// * In der App ist das Feld nicht nullbar: `Betrieb.fromJson` setzt
///   `json['rechnungsstellung'] ?? 'rechnung_mail'`, `BetriebLocal` und der
///   Web-Stub tragen denselben Vorgabewert.
///
/// Heisst: Ein NULL in der Datenbank kommt hier als `'rechnung_mail'` an, nicht
/// als «nicht entschieden». Ein Betrieb ohne erfasste Art wird also **per Mail
/// verrechnet** — und hat er keine Rechnungsadresse-E-Mail, erscheint im
/// Abschluss-Dialog die rote Warnung «Rechnung geht NICHT an den Kunden».
/// Die Art ist «nicht entschieden» im Datenmodell schlicht nicht abbildbar.
///
/// Der Rückfall bleibt trotzdem stehen: Er deckt den REINIGUNGSweg ab
/// (`reinigungen.zahlungsart` ist nullbar und darf leer sein).
String resolveZahlungsart(String? reinigungsWert, String? betriebsWert) {
  if (reinigungsWert != null && reinigungsWert.isNotEmpty) {
    return reinigungsWert;
  }
  if (betriebsWert != null && betriebsWert.isNotEmpty) return betriebsWert;
  // Sicherster Default: erzeugt Rechnung + Buchung — lieber eine Rechnung zu
  // viel (sichtbar, stornierbar) als eine lautlos fehlende.
  return 'rechnung_tresen';
}

/// ACHTUNG: NICHT für die Buchungs-Entscheidung verwenden — dort zählt
/// 'jahresrechnung' zusätzlich als Rechnungs-Typ (Debitor-Buchung ohne
/// Einzelrechnung, siehe ReinigungBuchungService._rechnungsTypen).
/// Diese Funktion beantwortet nur: "erzeugt diese Art eine EINZELrechnung?"
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

/// SCOR-Referenz für den Direkt-Zahlen-QR im Reinigungstab — DIESELBE Referenz,
/// die die Rechnung bekommt (Ziffern aus `YYYY-MM-DD-<betriebNr>`, identisch zu
/// RechnungService.createFromReinigung). Damit ist auch eine spontane
/// Direktzahlung im camt über die Referenz zuordenbar. Bar/Heineken -> null.
String? qrReferenzFuerReinigung({
  required String? zahlungsart,
  required DateTime datum,
  required String? betriebNr,
}) {
  if (!istRechnungsart(zahlungsart)) return null;
  final nr = (betriebNr == null || betriebNr.isEmpty)
      ? '0000'
      : betriebNr.padLeft(4, '0');
  final nummer =
      '${datum.year}-${datum.month.toString().padLeft(2, '0')}-'
      '${datum.day.toString().padLeft(2, '0')}-$nr';
  return qrReferenzAusNummer('kundenrechnung', nummer);
}

enum WarnungsGrund { ohneRechnung, ohneBuchung }

/// Entscheidet, ob eine abgeschlossene Reinigung in der Warnung erscheint.
/// Kasse-Buchung (1000) = bar erledigt -> nie flaggen, egal was die heutige
/// Betriebs-Einstellung sagt (die 10 Fehlalarme vom 16.07.).
WarnungsGrund? warnungsGrund({
  required String art,
  required bool hatRechnung,
  required bool hatBuchung,
  required bool kasseGebucht,
}) {
  if (art == 'heineken' || art == 'jahresrechnung') return null;
  if (kasseGebucht) return null;
  if (!hatBuchung) return WarnungsGrund.ohneBuchung;
  if (istRechnungsart(art) && !hatRechnung) return WarnungsGrund.ohneRechnung;
  return null;
}
