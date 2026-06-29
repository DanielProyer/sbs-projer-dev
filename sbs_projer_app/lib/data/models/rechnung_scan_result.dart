/// Ergebnis der OCR-Analyse einer Eingangsrechnung via Edge-Function
/// `parse-rechnung` (Claude). Plain-Dart mit robustem Parsing (String ODER num).
class RechnungScanResult {
  final bool istRechnung;
  final String dokTyp; // rechnung|akontorechnung|schlussrechnung|mahnung|gutschrift|info
  final bool istNurInfo;
  final String? ausstellerName;
  final String? ausstellerUid;
  final String? empfaengerIban;
  final String? referenz;
  final String? referenzTyp; // QRR|SCOR|NON
  final String? rechnungsnummer;
  final DateTime? rechnungsdatum;
  final DateTime? faelligkeit;
  final double betragZahlbar;
  final String? waehrung;
  final double mwstSatz;
  final bool mwstPflichtig;
  final double konfidenz;
  final String? kategorie; // code aus eingangsrechnung_kategorie

  RechnungScanResult({
    required this.istRechnung,
    required this.dokTyp,
    required this.istNurInfo,
    this.ausstellerName,
    this.ausstellerUid,
    this.empfaengerIban,
    this.referenz,
    this.referenzTyp,
    this.rechnungsnummer,
    this.rechnungsdatum,
    this.faelligkeit,
    this.betragZahlbar = 0,
    this.waehrung,
    this.mwstSatz = 0,
    this.mwstPflichtig = true,
    this.konfidenz = 0,
    this.kategorie,
  });

  factory RechnungScanResult.fromJson(Map<String, dynamic> json) {
    return RechnungScanResult(
      istRechnung: json['ist_rechnung'] == true,
      dokTyp: json['dok_typ'] as String? ?? 'rechnung',
      istNurInfo: json['ist_nur_info'] == true,
      ausstellerName: json['aussteller_name'] as String?,
      ausstellerUid: json['aussteller_uid'] as String?,
      empfaengerIban: json['empfaenger_iban'] as String?,
      referenz: json['referenz'] as String?,
      referenzTyp: json['referenz_typ'] as String?,
      rechnungsnummer: json['rechnungsnummer'] as String?,
      rechnungsdatum: _toDate(json['rechnungsdatum']),
      faelligkeit: _toDate(json['faelligkeit']),
      betragZahlbar: _d(json['betrag_zahlbar']),
      waehrung: json['waehrung'] as String?,
      mwstSatz: _d(json['mwst_satz']),
      mwstPflichtig: json['mwst_pflichtig'] != false,
      konfidenz: _d(json['konfidenz']),
      kategorie: json['kategorie'] as String?,
    );
  }

  static double _d(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
