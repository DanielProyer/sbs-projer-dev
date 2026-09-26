/// Wann braucht der Abschluss einer Reinigung noch einen Dialog? (V6,
/// Analyse-Runde 5 «Tagesbetrieb»)
///
/// **Warum:** Bis v0.14x öffnete jeder Abschluss den Dialog mit der
/// Zahlungsart-Auswahl — in 82 % der Fälle wurde die Vorgabe des Betriebs
/// unverändert übernommen, der Dialog war ein Tipp ohne Entscheidung. Seit V6
/// steht die Zahlungsart als Zeile im Formular; der Dialog kommt nur noch,
/// wenn es etwas zu sagen oder zu entscheiden gibt. Leere Menge = direkt
/// abschliessen.
library;

import 'package:sbs_projer_app/core/util/zahlungsart.dart';

enum AbschlussDialogGrund {
  /// Per Mail, aber keine Rechnungsadresse-E-Mail — die Rechnung ginge NICHT
  /// an den Kunden. Der Dialog bietet das E-Mail-Feld an.
  mailOhneAdresse,

  /// `betriebe.service_hinweis` ist gesetzt (z. B. «Nächste Reinigung
  /// GRATIS») — muss beim Abschluss sichtbar werden (Fall Chleina Pub).
  serviceHinweis,

  /// Gewählte Art weicht von der Betriebs-Vorgabe ab — der Dialog bietet
  /// «als Vorgabe speichern» an.
  abweichung,

  /// Booster/Eissäule wurden vor dem Service ausgeschaltet und müssen wieder
  /// an (`ServiceSchalter.hinweisEnde`). Ohne Dialog ginge dieser Hinweis
  /// verloren — dann friert oder wärmt die Anlage.
  schalterHinweis,
}

bool _leer(String? s) => s == null || s.trim().isEmpty;

Set<AbschlussDialogGrund> abschlussDialogGruende({
  required String gewaehlt,
  required String? vorgabeBetrieb,
  required String? kundenEmail,
  required String? serviceHinweis,
  String? schalterHinweis,
}) => {
  if (gewaehlt == 'rechnung_mail' && _leer(kundenEmail))
    AbschlussDialogGrund.mailOhneAdresse,
  if (!_leer(serviceHinweis)) AbschlussDialogGrund.serviceHinweis,
  if (gewaehlt != resolveZahlungsart(null, vorgabeBetrieb))
    AbschlussDialogGrund.abweichung,
  if (!_leer(schalterHinweis)) AbschlussDialogGrund.schalterHinweis,
};

/// Die sechs Zahlungsarten mit Anzeigetext — Reihenfolge und Texte wie das
/// frühere Dropdown im Abschluss-Dialog.
const zahlungsartAuswahl = <(String, String)>[
  ('rechnung_mail', 'Per E-Mail'),
  ('rechnung_post', 'Per Post'),
  ('rechnung_tresen', 'Rechnung Tresen (EZS)'),
  ('barzahlung', 'Barzahlung'),
  ('jahresrechnung', 'Jahresrechnung'),
  ('heineken', 'Via Heineken (monatlich)'),
];

String zahlungsartLabel(String art) {
  for (final (wert, text) in zahlungsartAuswahl) {
    if (wert == art) return text;
  }
  return art;
}
