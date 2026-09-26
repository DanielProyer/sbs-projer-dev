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
  final String? firmenIban;
  final String? gfAhvNr;
  final DateTime? gfGeburtsdatum;
  // Startort (Zuhause) für Anfahrt/Heimweg im Tourenplan (Spec 2026-07-29 §3).
  final double? startortLat;
  final double? startortLng;

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
    this.firmenIban,
    this.gfAhvNr,
    this.gfGeburtsdatum,
    this.startortLat,
    this.startortLng,
  });

  // Fallback-Konstanten = heutige fix codierte Werte.
  static const kFirma = 'SBS Projer GmbH';
  static const kStrasse = 'Via Rezia 8';
  static const kPlzOrt = '7013 Domat/Ems';
  static const kTelefon = '076 566 58 06';
  static const kMail = 'dani.proyer@gmail.com';

  /// Firmen-Mail auf PDFs (Fusszeilen); [kMail] ist der Mail-EMPFÄNGER.
  static const kMailGeschaeft = 'sbs.projer@gmail.com';
  static const kMwstNummer = 'CHE-413.083.919';

  /// Firmen-IBAN (Graubündner Kantonalbank). Einzige Stelle im Code, an der
  /// sie steht — gelesen über [zahlungsIbanKompakt]/[zahlungsIbanFormatiert].
  static const kIban = 'CH66 0077 4010 3765 5060 1';

  static String? _clean(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;

  String get firma => _clean(firmaName) ?? kFirma;
  String get adresseStrasse => _clean(strasse) ?? kStrasse;
  String get adressePlzOrt => _clean(plzOrt) ?? kPlzOrt;
  /// Nur der Ort aus «PLZ Ort» (Briefdatum «Domat/Ems, 26.09.2026»).
  String get adresseOrt {
    final s = adressePlzOrt;
    final i = s.indexOf(' ');
    return i <= 0 ? s : s.substring(i + 1).trim();
  }

  String get telefonOrFallback => _clean(telefon) ?? kTelefon;
  String get gfVollname => '${gfVorname ?? ''} ${gfName ?? ''}'.trim();
  String get mailEmpfaenger =>
      _clean(mailGeschaeft) ?? _clean(mailPrivat) ?? kMail;
  int get gfGeburtsjahr => gfGeburtsdatum?.year ?? 1990;
  String get mwstZeile {
    final m = _clean(mwstNummer);
    return m == null ? '' : '$m MWST';
  }

  /// Absenderblock unter Kunden-Mails: Firma, Adresse, Telefon.
  String get mailSignatur =>
      '$firma\n$adresseStrasse\n$adressePlzOrt\n$telefonOrFallback';

  String get mailGeschaeftOderFallback =>
      _clean(mailGeschaeft) ?? kMailGeschaeft;
  String get mwstNummerOderFallback => _clean(mwstNummer) ?? kMwstNummer;

  /// «CHE-… MWST» für Briefkopf/Fuss, mit Rückfall auf [kMwstNummer].
  String get mwstZeileOderFallback => '$mwstNummerOderFallback MWST';

  // ── Zahlungsdaten: bewusst KONSTANT, nie aus der DB ────────────────────
  //
  // Grund: Eine versehentlich geänderte, leere oder falsche Einstellung
  // (`firmen_iban`, Adresse) würde Kundengeld über den QR-Zahlteil auf ein
  // fremdes Konto lenken. Wer zahlt, sieht nur den QR-Code. Deshalb lesen
  // QR-Zahlteil, QR-Dialog, IBAN-Zeilen in PDFs und im Rechnungsdetail nur
  // diese statischen Werte (Entscheid Runde 4, 26.09.2026). `firmenIban` dient
  // allein dem eigenen Zahlerkonto im pain.001-Export.

  /// IBAN ohne Leerzeichen (für den QR-Code).
  static String get zahlungsIbanKompakt => kIban.replaceAll(' ', '');

  /// IBAN in Vierergruppen (für die Anzeige).
  static String get zahlungsIbanFormatiert => kIban;

  /// Zahlungsempfänger im QR-Zahlteil.
  static String get zahlungsEmpfaengerName => kFirma;

  /// («Via Rezia», «8») — Strasse und Hausnummer getrennt, wie die
  /// QR-Rechnung sie verlangt.
  static (String, String) get zahlungsEmpfaengerStrasse {
    const s = kStrasse;
    final i = s.lastIndexOf(' ');
    if (i <= 0) return (s, '');
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  /// («7013», «Domat/Ems»).
  static (String, String) get zahlungsEmpfaengerPlzOrt {
    const s = kPlzOrt;
    final i = s.indexOf(' ');
    if (i <= 0) return ('', s);
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  factory GeschaeftEinstellungen.fromJson(Map<String, dynamic> j) =>
      GeschaeftEinstellungen(
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
        firmenIban: j['firmen_iban'],
        gfAhvNr: j['gf_ahv_nr'],
        gfGeburtsdatum: j['gf_geburtsdatum'] != null
            ? DateTime.parse(j['gf_geburtsdatum'])
            : null,
        startortLat: (j['startort_lat'] as num?)?.toDouble(),
        startortLng: (j['startort_lng'] as num?)?.toDouble(),
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
    'firmen_iban': firmenIban,
    'gf_ahv_nr': gfAhvNr,
    'gf_geburtsdatum': gfGeburtsdatum?.toIso8601String().split('T').first,
    'startort_lat': startortLat,
    'startort_lng': startortLng,
  };
}
