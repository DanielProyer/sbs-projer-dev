/// Strukturierte Daten aus einem Swiss-QR-Code (QR-Rechnung).
///
/// Quelle ist der dekodierte QR-Payload (QRType "SPC", Version 0200). Diese
/// Werte sind prüfziffer-gesichert und gelten als WAHRHEIT gegenüber der
/// KI-Texterkennung.
class SwissQrData {
  final String iban;
  final String referenzTyp; // 'QRR' | 'SCOR' | 'NON'
  final String? referenz;
  final double? betrag;
  final String waehrung;
  final String? cdtrName;

  const SwissQrData({
    required this.iban,
    required this.referenzTyp,
    this.referenz,
    this.betrag,
    required this.waehrung,
    this.cdtrName,
  });
}

/// Parst einen Swiss-QR-Payload (Zeilen-Format gemäss Swiss Implementation
/// Guidelines QR-Rechnung). Gibt null zurück, wenn es kein gültiger
/// Swiss-QR-Payload ist (Header != "SPC" / keine IBAN).
///
/// Feldreihenfolge (0-basiert): 0 SPC · 1 Version · 2 Coding · 3 IBAN ·
/// 4–10 Creditor(7) · 11–17 UltimateCreditor(7) · 18 Amount · 19 Currency ·
/// 20–26 UltimateDebtor(7) · 27 ReferenceType · 28 Reference · 29 Unstructured ·
/// 30 Trailer "EPD".
SwissQrData? parseSwissQrPayload(String payload) {
  final lines =
      payload.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  if (lines.length < 12 || lines[0].trim() != 'SPC') return null;

  String at(int i) => (i >= 0 && i < lines.length) ? lines[i].trim() : '';

  final iban = at(3).replaceAll(' ', '');
  if (iban.isEmpty) return null;

  final betrag = double.tryParse(at(18));
  final waehrung = at(19).isEmpty ? 'CHF' : at(19);

  // Referenztyp/-referenz: bevorzugt feste Position 27/28, sonst via EPD-Trailer.
  String refTyp = at(27);
  String? ref = at(28).isEmpty ? null : at(28);
  if (refTyp != 'QRR' && refTyp != 'SCOR' && refTyp != 'NON') {
    final epd = lines.indexWhere((l) => l.trim() == 'EPD');
    if (epd >= 3) {
      refTyp = at(epd - 3);
      ref = at(epd - 2).isEmpty ? null : at(epd - 2);
    }
  }
  if (refTyp != 'QRR' && refTyp != 'SCOR' && refTyp != 'NON') refTyp = 'NON';
  if (refTyp == 'NON') {
    ref = null;
  } else {
    ref = ref?.replaceAll(' ', '');
  }

  return SwissQrData(
    iban: iban,
    referenzTyp: refTyp,
    referenz: ref,
    betrag: betrag,
    waehrung: waehrung,
    cdtrName: at(5).isEmpty ? null : at(5),
  );
}

/// Vergleicht QR-Werte mit der KI-Texterkennung und liefert eine
/// menschenlesbare Beschreibung der Abweichungen (null = keine Abweichung).
/// Verglichen werden IBAN, Referenz und Betrag (jeweils nur, wenn beide Seiten
/// einen Wert haben).
String? qrAbweichungen({
  String? qrIban,
  String? kiIban,
  String? qrRef,
  String? kiRef,
  double? qrBetrag,
  double? kiBetrag,
}) {
  String norm(String? s) => (s ?? '').replaceAll(' ', '').toUpperCase();
  final abw = <String>[];

  if (qrIban != null &&
      qrIban.isNotEmpty &&
      kiIban != null &&
      kiIban.isNotEmpty &&
      norm(qrIban) != norm(kiIban)) {
    abw.add('IBAN (QR: $qrIban / Text: $kiIban)');
  }
  if (qrRef != null &&
      qrRef.isNotEmpty &&
      kiRef != null &&
      kiRef.isNotEmpty &&
      norm(qrRef) != norm(kiRef)) {
    abw.add('Referenz (QR: $qrRef / Text: $kiRef)');
  }
  if (qrBetrag != null &&
      qrBetrag > 0 &&
      kiBetrag != null &&
      (qrBetrag - kiBetrag).abs() > 0.01) {
    abw.add(
        'Betrag (QR: ${qrBetrag.toStringAsFixed(2)} / Text: ${kiBetrag.toStringAsFixed(2)})');
  }

  return abw.isEmpty ? null : abw.join('; ');
}
