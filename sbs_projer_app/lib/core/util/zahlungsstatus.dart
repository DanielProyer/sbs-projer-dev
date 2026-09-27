/// Erlaubte Werte von `rechnungen.zahlungsstatus` — dieselbe Liste wie der
/// CHECK der letzten Migration, die ihn setzt (Wächter:
/// test/zahlungsstatus_waechter_test.dart).
///
/// Seit Migration 211 (Entscheid Daniel 27.09.2026) sagt der Status NUR noch,
/// ob Geld fliesst: `offen`, `bezahlt`, `abgeschrieben`. Zustellung steht in
/// `versendet_am`/`uebergeben_am`, die Mahnstufe in `mahnung_stufe` (0–3),
/// die Heineken-Freigabe in `freigegeben_am`. Was die App anzeigt
/// («Gesendet», «1. Mahnung», «Freigegeben»), leitet `anzeigeSchluessel`
/// (`rechnung_status.dart`) aus diesen Feldern ab.
abstract final class Zahlungsstatus {
  static const offen = 'offen';
  static const bezahlt = 'bezahlt';
  static const abgeschrieben = 'abgeschrieben';
  static const alle = {offen, bezahlt, abgeschrieben};
  static const erledigt = {bezahlt, abgeschrieben};

  /// Früher erlaubte Werte — der CHECK lehnt sie ab (PostgrestException).
  /// Die ersten sechs seit 081–083, die übrigen fünf seit 211 (dort je auf
  /// `offen` + Feld umgeschrieben).
  static const altwerte = {
    'entwurf',
    'versendet',
    'gestellt',
    'teilbezahlt',
    'ueberfaellig',
    'storniert',
    'gesendet',
    'freigegeben',
    'erinnert',
    'mahnung_1',
    'mahnung_2',
  };

  /// Status aus einem GESPEICHERTEN Vorher-Stand (Mahnschreiben-Protokoll,
  /// vor 211 geschrieben): ein Altwert wird `offen`. Wer ihn zurückschreibt,
  /// darf keinen Altwert in die DB tragen — der CHECK würde abbrechen.
  static String ausGespeichert(Object? wert) =>
      wert is String && alle.contains(wert) ? wert : offen;

  /// Mahnstufe, die ein Altwert ausdrückt (1–3 wie `mahnung_stufe`), sonst 0.
  /// WARUM: Bis v0.144.0 schrieb der Mahnlauf für die Erinnerung
  /// `mahnung_stufe = 0` — dort war der Status die einzige Spur der Mahnung.
  /// Gegenstück in SQL: `rechnung_stufe_aus_altstatus` (Migration 211).
  static int stufeAusAltwert(Object? wert) => switch (wert) {
        'erinnert' => 1,
        'mahnung_1' => 2,
        'mahnung_2' => 3,
        _ => 0,
      };
}
