/// Ein Abschreibungslauf: jahrgangsweise Abschreibung verjährter
/// Kundenrechnungen im Abschluss eines Geschäftsjahres (Migration 194).
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
  });

  bool get gebucht => status == 'gebucht';

  /// Satz der Rückholung aus den Summen — ein Lauf umfasst nur Jahrgänge
  /// mit einem Satz (7.7 % bis 2023, 8.1 % ab 2024).
  double get satz => netto > 0 ? (mwst / netto * 1000).round() / 10 : 0;

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
