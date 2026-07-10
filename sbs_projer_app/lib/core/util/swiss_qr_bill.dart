/// Baut den Swiss-QR-Bill-Payload (SPC, Version 0200) als `\n`-getrennten String.
///
/// - [betrag] null oder <= 0 -> leere Betragszeile (offener Betrag).
/// - [referenz] gesetzt -> Referenztyp `SCOR`, sonst `NON`.
/// - [mitteilung] wird auf 140 Zeichen gekürzt (Swiss-QR-Standard).
/// Reihenfolge/Struktur ist identisch zur bisherigen Rechnungs-QR-Erzeugung.
String swissQrPayload({
  required String iban,
  required String creditorName,
  required String creditorStreet,
  required String creditorNr,
  required String creditorPlz,
  required String creditorOrt,
  String creditorLand = 'CH',
  double? betrag,
  String debtorName = '',
  String debtorStreet = '',
  String debtorNr = '',
  String debtorPlz = '',
  String debtorOrt = '',
  String? referenz,
  String? mitteilung,
}) {
  final info = (mitteilung != null && mitteilung.isNotEmpty)
      ? (mitteilung.length > 140 ? mitteilung.substring(0, 140) : mitteilung)
      : '';
  final betragStr = (betrag != null && betrag > 0) ? betrag.toStringAsFixed(2) : '';
  final hatDebitor = debtorName.isNotEmpty;

  final lines = <String>[
    'SPC', // QR Type
    '0200', // Version
    '1', // Coding Type (UTF-8)
    iban, // IBAN
    'S', // Creditor Address Type (structured)
    creditorName,
    creditorStreet,
    creditorNr,
    creditorPlz,
    creditorOrt,
    creditorLand,
    '', '', '', '', '', '', '', // Ultimate Creditor (7 leer)
    betragStr, // Amount
    'CHF', // Currency
    hatDebitor ? 'S' : '', // Debtor Address Type
    debtorName,
    debtorStreet,
    debtorNr,
    debtorPlz,
    debtorOrt,
    hatDebitor ? creditorLand : '', // Debtor Country
    (referenz != null && referenz.isNotEmpty) ? 'SCOR' : 'NON', // Reference Type
    referenz ?? '', // Reference
    info, // Unstructured Message
    'EPD', // Trailer
  ];
  return lines.join('\n');
}
