class GeschaeftEinstellungen {
  final String id;
  final String userId;
  final String? firmaName;
  final String? strasse;
  final String? plzOrt;
  final String? gfVorname;
  final String? gfName;
  final String? telefon;
  final String? mailGeschaeft;
  final String? mailPrivat;
  final String? mwstNummer;
  final String? uidNummer;
  final String? gfAhvNr;
  final DateTime? gfGeburtsdatum;

  const GeschaeftEinstellungen({
    this.id = '',
    this.userId = '',
    this.firmaName,
    this.strasse,
    this.plzOrt,
    this.gfVorname,
    this.gfName,
    this.telefon,
    this.mailGeschaeft,
    this.mailPrivat,
    this.mwstNummer,
    this.uidNummer,
    this.gfAhvNr,
    this.gfGeburtsdatum,
  });

  // Fallback-Konstanten = heutige fix codierte Werte.
  static const kFirma = 'SBS Projer GmbH';
  static const kStrasse = 'Via Rezia 8';
  static const kPlzOrt = '7013 Domat/Ems';
  static const kTelefon = '076 566 58 06';
  static const kMail = 'dani.proyer@gmail.com';

  static String? _clean(String? s) => (s != null && s.trim().isNotEmpty) ? s.trim() : null;

  String get firma => _clean(firmaName) ?? kFirma;
  String get adresseStrasse => _clean(strasse) ?? kStrasse;
  String get adressePlzOrt => _clean(plzOrt) ?? kPlzOrt;
  String get telefonOrFallback => _clean(telefon) ?? kTelefon;
  String get gfVollname => '${gfVorname ?? ''} ${gfName ?? ''}'.trim();
  String get mailEmpfaenger => _clean(mailGeschaeft) ?? _clean(mailPrivat) ?? kMail;
  int get gfGeburtsjahr => gfGeburtsdatum?.year ?? 1990;
  String get mwstZeile {
    final m = _clean(mwstNummer);
    return m == null ? '' : '$m MWST';
  }

  factory GeschaeftEinstellungen.fromJson(Map<String, dynamic> j) => GeschaeftEinstellungen(
        id: j['id']?.toString() ?? '',
        userId: j['user_id']?.toString() ?? '',
        firmaName: j['firma_name'],
        strasse: j['strasse'],
        plzOrt: j['plz_ort'],
        gfVorname: j['gf_vorname'],
        gfName: j['gf_name'],
        telefon: j['telefon'],
        mailGeschaeft: j['mail_geschaeft'],
        mailPrivat: j['mail_privat'],
        mwstNummer: j['mwst_nummer'],
        uidNummer: j['uid_nummer'],
        gfAhvNr: j['gf_ahv_nr'],
        gfGeburtsdatum: j['gf_geburtsdatum'] != null ? DateTime.parse(j['gf_geburtsdatum']) : null,
      );

  Map<String, dynamic> toJson() => {
        'firma_name': firmaName,
        'strasse': strasse,
        'plz_ort': plzOrt,
        'gf_vorname': gfVorname,
        'gf_name': gfName,
        'telefon': telefon,
        'mail_geschaeft': mailGeschaeft,
        'mail_privat': mailPrivat,
        'mwst_nummer': mwstNummer,
        'uid_nummer': uidNummer,
        'gf_ahv_nr': gfAhvNr,
        'gf_geburtsdatum': gfGeburtsdatum?.toIso8601String().split('T').first,
      };
}
