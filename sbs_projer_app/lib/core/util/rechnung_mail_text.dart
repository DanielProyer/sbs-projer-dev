/// Textbausteine der Rechnungs-Mail — rein, testbar, eine Wahrheit für alle
/// Versandwege (Reinigungsabschluss, Reinigungsformular, Rechnungsdetail).
library;

import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Zahlungsaufforderung mit dem Betrag, den der Kunde tatsächlich zahlt
/// (`zuZahlen`, auf 5 Rappen). Ist ein Kundenguthaben verrechnet, sagt der
/// Satz das dazu — sonst wundert sich der Kunde über den tieferen Betrag.
String zahlungsSatzMail(Rechnung rechnung) {
  // Ganz durch Guthaben gedeckt: keine Zahlungsaufforderung (Review I2).
  if (rechnung.guthabenVerrechnet > 0 && rechnung.zuZahlen < 0.005) {
    return 'Der Betrag wurde vollständig mit Ihrem Guthaben verrechnet — '
        'es ist nichts zu zahlen.';
  }
  final betrag = rundeAuf5Rappen(rechnung.zuZahlen).toStringAsFixed(2);
  final zusatz = rechnung.guthabenVerrechnet > 0
      ? ' (nach Verrechnung Ihres Guthabens von CHF '
            '${rechnung.guthabenVerrechnet.toStringAsFixed(2)})'
      : '';
  return 'Ich bitte Sie den offenen Betrag von CHF $betrag$zusatz '
      'innerhalb von 30 Tagen mit dem beiliegenden Einzahlungsschein '
      'zu begleichen.';
}
