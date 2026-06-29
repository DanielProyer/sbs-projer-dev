/// DTO für eine Eingangsrechnung (Kreditor / Lieferantenrechnung).
///
/// Plain-Dart-Klasse mit fromJson-Factory + toJson (snake_case Keys),
/// passend zur Supabase-Tabelle `eingangsrechnung` (Migration 106 + 107,
/// inkl. beleg_pfad/beleg_dateiname).
class Eingangsrechnung {
  final String id;
  final String userId;
  final String? ausstellerName;
  final String? ausstellerUid;
  final String? ausstellerStrasse;
  final String? ausstellerHausnr;
  final String? ausstellerPlz;
  final String? ausstellerOrt;
  final String? ausstellerLand;
  final String? lieferantIban;
  final String? qrReferenz;
  final String? referenzTyp;
  final double betragBrutto;
  final double? mwstSatz;
  final int? vorsteuerKonto;
  final bool mwstPflichtig;
  final String? rechnungsnummer;
  final DateTime? rechnungsdatum;
  final DateTime? faelligkeit;
  final int? aufwandskonto;
  final String? geschaeftsfallId;
  final String? kategorie;
  final bool istNurInfo;
  final String? dokTyp;
  final String? status;
  final DateTime? gebuchtAm;
  final bool zahlungVorgemerkt;
  final String? zahlungsfileId;
  final DateTime? exportiertAm;
  final DateTime? bezahltAm;
  final String? buchungStufe1Id;
  final String? buchungStufe2Id;
  final String? camtTxKey;
  final double? konfidenz;
  final String? belegId;
  final String? belegPfad;
  final String? belegDateiname;
  final bool qrGelesen;
  final String? qrAbweichungen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Eingangsrechnung({
    required this.id,
    required this.userId,
    this.ausstellerName,
    this.ausstellerUid,
    this.ausstellerStrasse,
    this.ausstellerHausnr,
    this.ausstellerPlz,
    this.ausstellerOrt,
    this.ausstellerLand,
    this.lieferantIban,
    this.qrReferenz,
    this.referenzTyp,
    this.betragBrutto = 0,
    this.mwstSatz,
    this.vorsteuerKonto,
    this.mwstPflichtig = true,
    this.rechnungsnummer,
    this.rechnungsdatum,
    this.faelligkeit,
    this.aufwandskonto,
    this.geschaeftsfallId,
    this.kategorie,
    this.istNurInfo = false,
    this.dokTyp,
    this.status,
    this.gebuchtAm,
    this.zahlungVorgemerkt = false,
    this.zahlungsfileId,
    this.exportiertAm,
    this.bezahltAm,
    this.buchungStufe1Id,
    this.buchungStufe2Id,
    this.camtTxKey,
    this.konfidenz,
    this.belegId,
    this.belegPfad,
    this.belegDateiname,
    this.qrGelesen = false,
    this.qrAbweichungen,
    this.createdAt,
    this.updatedAt,
  });

  factory Eingangsrechnung.fromJson(Map<String, dynamic> json) {
    return Eingangsrechnung(
      id: json['id'],
      userId: json['user_id'],
      ausstellerName: json['aussteller_name'],
      ausstellerUid: json['aussteller_uid'],
      ausstellerStrasse: json['aussteller_strasse'],
      ausstellerHausnr: json['aussteller_hausnr'],
      ausstellerPlz: json['aussteller_plz'],
      ausstellerOrt: json['aussteller_ort'],
      ausstellerLand: json['aussteller_land'],
      lieferantIban: json['lieferant_iban'],
      qrReferenz: json['qr_referenz'],
      referenzTyp: json['referenz_typ'],
      betragBrutto: _d(json['betrag_brutto'], 0),
      mwstSatz: _toDouble(json['mwst_satz']),
      vorsteuerKonto: _toInt(json['vorsteuer_konto']),
      mwstPflichtig: json['mwst_pflichtig'] ?? true,
      rechnungsnummer: json['rechnungsnummer'],
      rechnungsdatum: _toDate(json['rechnungsdatum']),
      faelligkeit: _toDate(json['faelligkeit']),
      aufwandskonto: _toInt(json['aufwandskonto']),
      geschaeftsfallId: json['geschaeftsfall_id'],
      kategorie: json['kategorie'],
      istNurInfo: json['ist_nur_info'] ?? false,
      dokTyp: json['dok_typ'],
      status: json['status'],
      gebuchtAm: _toDate(json['gebucht_am']),
      zahlungVorgemerkt: json['zahlung_vorgemerkt'] ?? false,
      zahlungsfileId: json['zahlungsfile_id'],
      exportiertAm: _toDate(json['exportiert_am']),
      bezahltAm: _toDate(json['bezahlt_am']),
      buchungStufe1Id: json['buchung_stufe1_id'],
      buchungStufe2Id: json['buchung_stufe2_id'],
      camtTxKey: json['camt_tx_key'],
      konfidenz: _toDouble(json['konfidenz']),
      belegId: json['beleg_id'],
      belegPfad: json['beleg_pfad'],
      belegDateiname: json['beleg_dateiname'],
      qrGelesen: json['qr_gelesen'] ?? false,
      qrAbweichungen: json['qr_abweichungen'],
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'aussteller_name': ausstellerName,
      'aussteller_uid': ausstellerUid,
      'aussteller_strasse': ausstellerStrasse,
      'aussteller_hausnr': ausstellerHausnr,
      'aussteller_plz': ausstellerPlz,
      'aussteller_ort': ausstellerOrt,
      'aussteller_land': ausstellerLand,
      'lieferant_iban': lieferantIban,
      'qr_referenz': qrReferenz,
      'referenz_typ': referenzTyp,
      'betrag_brutto': betragBrutto,
      'mwst_satz': mwstSatz,
      'vorsteuer_konto': vorsteuerKonto,
      'mwst_pflichtig': mwstPflichtig,
      'rechnungsnummer': rechnungsnummer,
      'rechnungsdatum': rechnungsdatum?.toIso8601String().split('T').first,
      'faelligkeit': faelligkeit?.toIso8601String().split('T').first,
      'aufwandskonto': aufwandskonto,
      'geschaeftsfall_id': geschaeftsfallId,
      'kategorie': kategorie,
      'ist_nur_info': istNurInfo,
      'dok_typ': dokTyp,
      'status': status,
      'gebucht_am': gebuchtAm?.toIso8601String(),
      'zahlung_vorgemerkt': zahlungVorgemerkt,
      'zahlungsfile_id': zahlungsfileId,
      'exportiert_am': exportiertAm?.toIso8601String(),
      'bezahlt_am': bezahltAm?.toIso8601String().split('T').first,
      'buchung_stufe1_id': buchungStufe1Id,
      'buchung_stufe2_id': buchungStufe2Id,
      'camt_tx_key': camtTxKey,
      'konfidenz': konfidenz,
      'beleg_id': belegId,
      'beleg_pfad': belegPfad,
      'beleg_dateiname': belegDateiname,
      'qr_gelesen': qrGelesen,
      'qr_abweichungen': qrAbweichungen,
    };
  }

  static double _d(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
