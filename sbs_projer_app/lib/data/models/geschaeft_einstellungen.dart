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
  /// sie steht — QR-Zahlteil, Rechnungs-/Mahn-/Kontoauszug-/Heineken-PDF und
  /// Rechnungsdetail lesen sie über [ibanKompakt] bzw. [ibanFormatiert].
  static const kIban = 'CH66 0077 4010 3765 5060 1';

  static String? _clean(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;

  String get firma => _clean(firmaName) ?? kFirma;
  String get adresseStrasse => _clean(strasse) ?? kStrasse;
  String get adressePlzOrt => _clean(plzOrt) ?? kPlzOrt;
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

  /// Strasse und Hausnummer getrennt (die QR-Rechnung verlangt beides
  /// einzeln): «Via Rezia 8» → («Via Rezia», «8»).
  (String, String) get strasseUndNr {
    final s = adresseStrasse.trim();
    final i = s.lastIndexOf(' ');
    if (i <= 0) return (s, '');
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  /// PLZ und Ort getrennt: «7013 Domat/Ems» → («7013», «Domat/Ems»).
  (String, String) get plzUndOrt {
    final s = adressePlzOrt.trim();
    final i = s.indexOf(' ');
    if (i <= 0) return ('', s);
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }

  /// IBAN ohne Leerzeichen, wie sie in den QR-Code gehört. Aus [firmenIban],
  /// sofern das eine gültige CH/LI-IBAN ist (Prüfziffer mod 97) — eine leere
  /// oder vertippte Einstellung darf keine Zahlung auf ein falsches Konto
  /// lenken; dann gilt [kIban].
  String get ibanKompakt =>
      ibanNormalisiert(firmenIban) ?? kIban.replaceAll(' ', '');

  /// IBAN in Vierergruppen für die Anzeige, z. B. «CH66 0077 … 1».
  String get ibanFormatiert {
    final k = ibanKompakt;
    final sb = StringBuffer();
    for (var i = 0; i < k.length; i += 4) {
      if (i > 0) sb.write(' ');
      sb.write(k.substring(i, i + 4 > k.length ? k.length : i + 4));
    }
    return sb.toString();
  }

  /// Normalisiert eine IBAN (Leerzeichen weg, Grossbuchstaben) und prüft sie;
  /// null, wenn leer, nicht CH/LI oder die Prüfziffer nicht stimmt.
  static String? ibanNormalisiert(String? roh) {
    if (roh == null) return null;
    final k = roh.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (!RegExp(r'^(CH|LI)\d{2}[0-9A-Z]{17}$').hasMatch(k)) return null;
    final umgestellt = k.substring(4) + k.substring(0, 4);
    var rest = 0;
    for (final c in umgestellt.codeUnits) {
      final wert = c >= 65 ? c - 55 : c - 48; // A=10 … Z=35
      rest = int.parse('$rest$wert') % 97;
    }
    return rest == 1 ? k : null;
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
