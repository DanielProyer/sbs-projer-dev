import 'package:sbs_projer_app/core/util/iban_qrr.dart';
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/services/eingangsrechnung/pain001_writer.dart';

/// Prüft eine Zahlung auf Konsistenz für das GKB-pain.001-File.
///
/// Leere Liste = exportierbar; sonst die Gründe. Verhindert, dass ein einzelner
/// inkonsistenter Datensatz den ganzen GKB-Batch ablehnt (Fehler CH16/17/21):
/// QR-IBAN ⟺ QRR untrennbar, SCOR nie mit QR-IBAN, IBAN/Ort/Betrag vorhanden.
List<String> pruefeZahlung(Pain001Payment p) {
  final fehler = <String>[];

  final iban = p.cdtrIban.replaceAll(' ', '').toUpperCase();
  final ibanOk =
      iban.length == 21 && (iban.startsWith('CH') || iban.startsWith('LI'));
  if (iban.isEmpty) {
    fehler.add('IBAN fehlt');
  } else if (!ibanOk) {
    fehler.add('IBAN ungültig');
  }
  final qrIban = ibanOk && istQrIban(iban);

  switch (p.referenzTyp) {
    case 'QRR':
      if (ibanOk && !qrIban) {
        fehler.add('QRR-Referenz erfordert eine QR-IBAN');
      }
      if (!qrrPruefzifferOk(p.referenz ?? '')) {
        fehler.add('QR-Referenz ungültig');
      }
      break;
    case 'SCOR':
      if (qrIban) {
        fehler.add('SCOR-Referenz nicht mit QR-IBAN zulässig');
      }
      if (!istGueltigeScor(p.referenz ?? '')) {
        fehler.add('SCOR-Referenz ungültig');
      }
      break;
    default: // 'NON'
      if (qrIban) {
        fehler.add('QR-IBAN erfordert eine QR-Referenz');
      }
  }

  if ((p.cdtrTwnNm ?? '').trim().isEmpty) {
    fehler.add('Ort des Lieferanten fehlt');
  }
  if (p.betrag <= 0) {
    fehler.add('Betrag muss grösser als 0 sein');
  }
  return fehler;
}
