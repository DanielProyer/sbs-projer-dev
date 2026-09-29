/// Ein Abschreibungslauf: jahrgangsweise Abschreibung verjährter
/// Kundenrechnungen im Abschluss eines Geschäftsjahres (Migration 194,
/// Buchungsmuster seit 215: brutto per 31.12., MWST-Rückholung am
/// Entscheidtag).
class AbschreibungLauf {
  final String id;
  final int geschaeftsjahr;
  final List<int> jahrgaenge;
  final DateTime buchungsdatum;
  final int mwstJahr;
  final int mwstQuartal;
  final int anzahl;
  final double netto;
  final double mwst;
  final double brutto;
  final String status;
  final bool ruecknahmeMoeglich;
  final DateTime? zurueckgenommenAm;
  final String? notizen;
  final DateTime? createdAt;

  /// Seit Migration 215: die Sammelbuchungen der MWST-Rückholung
  /// (`2200 an 3805`, je Satz eine, am Entscheidtag). Leer bei Läufen vor
  /// 215 — und solange 215 nicht angewendet ist (Spalte fehlt).
  final List<String> buchungMwstIds;

  const AbschreibungLauf({
    required this.id,
    required this.geschaeftsjahr,
    required this.jahrgaenge,
    required this.buchungsdatum,
    required this.mwstJahr,
    required this.mwstQuartal,
    required this.anzahl,
    required this.netto,
    required this.mwst,
    required this.brutto,
    required this.status,
    required this.ruecknahmeMoeglich,
    this.zurueckgenommenAm,
    this.notizen,
    this.createdAt,
    this.buchungMwstIds = const [],
  });

  bool get gebucht => status == 'gebucht';

  /// Satz der Rückholung aus den Summen (7.7 % bis 2023, 8.1 % ab 2024).
  /// Umfasst der Lauf Jahrgänge mit verschiedenen Sätzen, ist das ein
  /// Mischwert — siehe [mehrereSaetze].
  double get satz => netto > 0 ? (mwst / netto * 1000).round() / 10 : 0;

  /// Seit Migration 215 steht je Satz eine Sammelbuchung — mehr als eine
  /// heisst: der Lauf mischt Sätze (z. B. 2023 zu 7.7 % und 2024 zu 8.1 %
  /// im Abschluss 2029). Läufe vor 215 und der 2019er per SQL haben keine
  /// Sammelbuchungen in der Liste; sie umfassen je nur einen Satz.
  bool get mehrereSaetze => buchungMwstIds.length > 1;

  /// Für die Lauf-Karte: «7.7 %» — oder «mehrere Sätze» statt eines
  /// Mischsatzes, den es im MWST-Formular nicht gibt.
  String get satzText => mehrereSaetze ? 'mehrere Sätze' : '$satz %';

  /// Lauf nach dem Muster vor Migration 215: je Rechnung `3805 an 1100`
  /// netto UND `2200 an 1100` MWST per 31.12., Ziff. 235 in Q4 des
  /// Geschäftsjahrs. Seit 215 — und beim per SQL gebuchten 2019er — steht
  /// per 31.12. nur die Brutto-Buchung; die Rückholung liegt als
  /// Sammelbuchung am Entscheidtag.
  bool get rueckholungJeRechnung =>
      buchungMwstIds.isEmpty &&
      ruecknahmeMoeglich &&
      mwst > 0 &&
      mwstJahr == geschaeftsjahr &&
      mwstQuartal == 4;

  /// Buchungen per 31.12., die eine Rücknahme löscht — ohne die
  /// Sammelbuchungen der Rückholung ([buchungMwstIds]).
  int get buchungenPer31Dez => rueckholungJeRechnung ? anzahl * 2 : anzahl;

  factory AbschreibungLauf.fromJson(Map<String, dynamic> j) => AbschreibungLauf(
    id: j['id'] as String,
    geschaeftsjahr: j['geschaeftsjahr'] as int,
    jahrgaenge: [
      for (final x in (j['jahrgaenge'] as List? ?? const [])) x as int,
    ],
    buchungsdatum: DateTime.parse(j['buchungsdatum'] as String),
    mwstJahr: j['mwst_jahr'] as int,
    mwstQuartal: j['mwst_quartal'] as int,
    anzahl: j['anzahl'] as int? ?? 0,
    netto: _d(j['netto']),
    mwst: _d(j['mwst']),
    brutto: _d(j['brutto']),
    status: j['status'] as String? ?? 'gebucht',
    ruecknahmeMoeglich: j['ruecknahme_moeglich'] as bool? ?? true,
    zurueckgenommenAm: j['zurueckgenommen_am'] != null
        ? DateTime.parse(j['zurueckgenommen_am'] as String)
        : null,
    notizen: j['notizen'] as String?,
    createdAt: j['created_at'] != null
        ? DateTime.parse(j['created_at'] as String)
        : null,
    // Fehlt die Spalte (App vor Migration 215 ausgeliefert), bleibt die
    // Liste leer — der Screen muss trotzdem laden.
    buchungMwstIds: [
      for (final x in (j['buchung_mwst_ids'] as List? ?? const [])) x as String,
    ],
  );
}

/// Eine Rechnung innerhalb eines Laufs — mit Status vorher und den IDs der
/// beiden Buchungen, damit der Lauf zurückgenommen werden kann.
class AbschreibungPosition {
  final String id;
  final String laufId;
  final String rechnungId;
  final String? rechnungsnummer;
  final String? betrieb;
  final int jahrgang;
  final String kategorie;
  final double netto;
  final double mwst;
  final double brutto;
  final String statusVorher;

  const AbschreibungPosition({
    required this.id,
    required this.laufId,
    required this.rechnungId,
    required this.rechnungsnummer,
    required this.betrieb,
    required this.jahrgang,
    required this.kategorie,
    required this.netto,
    required this.mwst,
    required this.brutto,
    required this.statusVorher,
  });

  factory AbschreibungPosition.fromJson(Map<String, dynamic> j) =>
      AbschreibungPosition(
        id: j['id'] as String,
        laufId: j['lauf_id'] as String,
        rechnungId: j['rechnung_id'] as String,
        rechnungsnummer: j['rechnungsnummer'] as String?,
        betrieb: j['betrieb'] as String?,
        jahrgang: j['jahrgang'] as int,
        kategorie: j['kategorie'] as String,
        netto: _d(j['netto']),
        mwst: _d(j['mwst']),
        brutto: _d(j['brutto']),
        statusVorher: j['status_vorher'] as String,
      );
}

double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
