class Reinigung {
  final String id;
  final String userId;
  final String anlageId;
  final String betriebId;
  final DateTime datum;
  final String? uhrzeitStart;
  final String? uhrzeitEnde;
  final int? dauerMinuten;

  // Checkliste
  final bool hatDurchlaufkuehler;
  final bool hatBuffetanstich;
  final bool hatKuehlkeller;
  final bool hatFasskuehler;
  final bool begleitkuehlungKontrolliert;
  final bool installationAllgemeinKontrolliert;
  final bool aligalAnschluesseKontrolliert;
  final bool durchlaufkuehlerAusgeblasen;
  final bool wasserstandKontrolliert;
  final bool wasserGewechselt;
  final bool leitungWasserVorgespuelt;
  final bool leitungsreinigungReinigungsmittel;
  final bool foerderdruckKontrolliert;
  final bool zapfhahnZerlegtGereinigt;
  final bool zapfkopfZerlegtGereinigt;
  final bool servicekarteAusgefuellt;
  final Map<String, String> checklisteNotizen;

  // Unterschriften
  final String? unterschriftTechniker;
  final String? unterschriftKunde;
  final String? unterschriftKundeName;
  final String? notizen;

  // Preis
  final String? preislisteId;
  final String? serviceTyp;
  final int anzahlHaehneEigen;
  final int anzahlHaehneOrion;
  final int anzahlHaehneFremd;
  final int anzahlHaehneWein;
  final int anzahlHaehneAndererStandort;
  final bool istBergkunde;
  final double? preisGrundtarif;
  final double? preisZusatzHaehne;
  final double? bergkundenZuschlag;
  final double? preisNetto;
  final double? mwstSatz;
  final double? preisMwst;
  final double? preisBrutto;
  final String status;
  final bool istSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Reinigung({
    required this.id,
    required this.userId,
    required this.anlageId,
    required this.betriebId,
    required this.datum,
    this.uhrzeitStart,
    this.uhrzeitEnde,
    this.dauerMinuten,
    this.hatDurchlaufkuehler = false,
    this.hatBuffetanstich = false,
    this.hatKuehlkeller = false,
    this.hatFasskuehler = false,
    this.begleitkuehlungKontrolliert = false,
    this.installationAllgemeinKontrolliert = false,
    this.aligalAnschluesseKontrolliert = false,
    this.durchlaufkuehlerAusgeblasen = false,
    this.wasserstandKontrolliert = false,
    this.wasserGewechselt = false,
    this.leitungWasserVorgespuelt = false,
    this.leitungsreinigungReinigungsmittel = false,
    this.foerderdruckKontrolliert = false,
    this.zapfhahnZerlegtGereinigt = false,
    this.zapfkopfZerlegtGereinigt = false,
    this.servicekarteAusgefuellt = false,
    this.checklisteNotizen = const {},
    this.unterschriftTechniker,
    this.unterschriftKunde,
    this.unterschriftKundeName,
    this.notizen,
    this.preislisteId,
    this.serviceTyp,
    this.anzahlHaehneEigen = 0,
    this.anzahlHaehneOrion = 0,
    this.anzahlHaehneFremd = 0,
    this.anzahlHaehneWein = 0,
    this.anzahlHaehneAndererStandort = 0,
    this.istBergkunde = false,
    this.preisGrundtarif,
    this.preisZusatzHaehne,
    this.bergkundenZuschlag,
    this.preisNetto,
    this.mwstSatz,
    this.preisMwst,
    this.preisBrutto,
    this.status = 'offen',
    this.istSynced = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Reinigung.fromJson(Map<String, dynamic> json) {
    return Reinigung(
      id: json['id'],
      userId: json['user_id'],
      anlageId: json['anlage_id'],
      betriebId: json['betrieb_id'],
      datum: DateTime.parse(json['datum']),
      uhrzeitStart: json['uhrzeit_start'],
      uhrzeitEnde: json['uhrzeit_ende'],
      dauerMinuten: json['dauer_minuten'],
      hatDurchlaufkuehler: json['hat_durchlaufkuehler'] ?? false,
      hatBuffetanstich: json['hat_buffetanstich'] ?? false,
      hatKuehlkeller: json['hat_kuehlkeller'] ?? false,
      hatFasskuehler: json['hat_fasskuehler'] ?? false,
      begleitkuehlungKontrolliert: json['begleitkuehlung_kontrolliert'] ?? false,
      installationAllgemeinKontrolliert: json['installation_allgemein_kontrolliert'] ?? false,
      aligalAnschluesseKontrolliert: json['aligal_anschluesse_kontrolliert'] ?? false,
      durchlaufkuehlerAusgeblasen: json['durchlaufkuehler_ausgeblasen'] ?? false,
      wasserstandKontrolliert: json['wasserstand_kontrolliert'] ?? false,
      wasserGewechselt: json['wasser_gewechselt'] ?? false,
      leitungWasserVorgespuelt: json['leitung_wasser_vorgespuelt'] ?? false,
      leitungsreinigungReinigungsmittel: json['leitungsreinigung_reinigungsmittel'] ?? false,
      foerderdruckKontrolliert: json['foerderdruck_kontrolliert'] ?? false,
      zapfhahnZerlegtGereinigt: json['zapfhahn_zerlegt_gereinigt'] ?? false,
      zapfkopfZerlegtGereinigt: json['zapfkopf_zerlegt_gereinigt'] ?? false,
      servicekarteAusgefuellt: json['servicekarte_ausgefuellt'] ?? false,
      checklisteNotizen: json['checkliste_notizen'] != null
          ? Map<String, String>.from(json['checkliste_notizen'])
          : {},
      unterschriftTechniker: json['unterschrift_techniker'],
      unterschriftKunde: json['unterschrift_kunde'],
      unterschriftKundeName: json['unterschrift_kunde_name'],
      notizen: json['notizen'],
      preislisteId: json['preisliste_id'],
      serviceTyp: json['service_typ'],
      anzahlHaehneEigen: json['anzahl_haehne_eigen'] ?? 0,
      anzahlHaehneOrion: json['anzahl_haehne_orion'] ?? 0,
      anzahlHaehneFremd: json['anzahl_haehne_fremd'] ?? 0,
      anzahlHaehneWein: json['anzahl_haehne_wein'] ?? 0,
      anzahlHaehneAndererStandort: json['anzahl_haehne_anderer_standort'] ?? 0,
      istBergkunde: json['ist_bergkunde'] ?? false,
      preisGrundtarif: _toDouble(json['preis_grundtarif']),
      preisZusatzHaehne: _toDouble(json['preis_zusatz_haehne']),
      bergkundenZuschlag: _toDouble(json['bergkunden_zuschlag']),
      preisNetto: _toDouble(json['preis_netto']),
      mwstSatz: _toDouble(json['mwst_satz']),
      preisMwst: _toDouble(json['preis_mwst']),
      preisBrutto: _toDouble(json['preis_brutto']),
      status: json['status'] ?? 'offen',
      istSynced: json['ist_synced'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'anlage_id': anlageId,
      'betrieb_id': betriebId,
      'datum': datum.toIso8601String().split('T').first,
      'uhrzeit_start': uhrzeitStart,
      'uhrzeit_ende': uhrzeitEnde,
      'hat_durchlaufkuehler': hatDurchlaufkuehler,
      'hat_buffetanstich': hatBuffetanstich,
      'hat_kuehlkeller': hatKuehlkeller,
      'hat_fasskuehler': hatFasskuehler,
      'begleitkuehlung_kontrolliert': begleitkuehlungKontrolliert,
      'installation_allgemein_kontrolliert': installationAllgemeinKontrolliert,
      'aligal_anschluesse_kontrolliert': aligalAnschluesseKontrolliert,
      'durchlaufkuehler_ausgeblasen': durchlaufkuehlerAusgeblasen,
      'wasserstand_kontrolliert': wasserstandKontrolliert,
      'wasser_gewechselt': wasserGewechselt,
      'leitung_wasser_vorgespuelt': leitungWasserVorgespuelt,
      'leitungsreinigung_reinigungsmittel': leitungsreinigungReinigungsmittel,
      'foerderdruck_kontrolliert': foerderdruckKontrolliert,
      'zapfhahn_zerlegt_gereinigt': zapfhahnZerlegtGereinigt,
      'zapfkopf_zerlegt_gereinigt': zapfkopfZerlegtGereinigt,
      'servicekarte_ausgefuellt': servicekarteAusgefuellt,
      'checkliste_notizen': checklisteNotizen,
      'unterschrift_techniker': unterschriftTechniker,
      'unterschrift_kunde': unterschriftKunde,
      'unterschrift_kunde_name': unterschriftKundeName,
      'notizen': notizen,
      'preisliste_id': preislisteId,
      'service_typ': serviceTyp,
      'anzahl_haehne_eigen': anzahlHaehneEigen,
      'anzahl_haehne_orion': anzahlHaehneOrion,
      'anzahl_haehne_fremd': anzahlHaehneFremd,
      'anzahl_haehne_wein': anzahlHaehneWein,
      'anzahl_haehne_anderer_standort': anzahlHaehneAndererStandort,
      'ist_bergkunde': istBergkunde,
      'preis_grundtarif': preisGrundtarif,
      'preis_zusatz_haehne': preisZusatzHaehne,
      'bergkunden_zuschlag': bergkundenZuschlag,
      'preis_netto': preisNetto,
      'mwst_satz': mwstSatz,
      'preis_mwst': preisMwst,
      'preis_brutto': preisBrutto,
      'status': status,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
