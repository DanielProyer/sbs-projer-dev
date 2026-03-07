class PikettDienst {
  final String id;
  final String userId;
  final DateTime datumStart;
  final DateTime datumEnde;
  final String? referenzNr;
  final bool istAktiv;
  final String? preislisteId;
  final double? pauschale;
  final int anzahlFeiertage;
  final double? feiertagZuschlag;
  final double? pauschaleGesamt;
  final DateTime? abrechnungsMonat;
  final bool abgerechnet;
  final String? googleCalendarEventId;
  final String kalenderSyncStatus;
  final String? kalenderSyncFehler;
  final DateTime? kalenderSyncAt;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PikettDienst({
    required this.id,
    required this.userId,
    required this.datumStart,
    required this.datumEnde,
    this.referenzNr,
    this.istAktiv = false,
    this.preislisteId,
    this.pauschale,
    this.anzahlFeiertage = 0,
    this.feiertagZuschlag,
    this.pauschaleGesamt,
    this.abrechnungsMonat,
    this.abgerechnet = false,
    this.googleCalendarEventId,
    this.kalenderSyncStatus = 'pending',
    this.kalenderSyncFehler,
    this.kalenderSyncAt,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory PikettDienst.fromJson(Map<String, dynamic> json) {
    return PikettDienst(
      id: json['id'],
      userId: json['user_id'],
      datumStart: DateTime.parse(json['datum_start']),
      datumEnde: DateTime.parse(json['datum_ende']),
      referenzNr: json['referenz_nr'],
      istAktiv: json['ist_aktiv'] ?? false,
      preislisteId: json['preisliste_id'],
      pauschale: _toDouble(json['pauschale']),
      anzahlFeiertage: json['anzahl_feiertage'] ?? 0,
      feiertagZuschlag: _toDouble(json['feiertag_zuschlag']),
      pauschaleGesamt: _toDouble(json['pauschale_gesamt']),
      abrechnungsMonat: json['abrechnungs_monat'] != null
          ? DateTime.parse(json['abrechnungs_monat'])
          : null,
      abgerechnet: json['abgerechnet'] ?? false,
      googleCalendarEventId: json['google_calendar_event_id'],
      kalenderSyncStatus: json['kalender_sync_status'] ?? 'pending',
      kalenderSyncFehler: json['kalender_sync_fehler'],
      kalenderSyncAt: json['kalender_sync_at'] != null
          ? DateTime.parse(json['kalender_sync_at'])
          : null,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'datum_start': datumStart.toIso8601String().split('T').first,
      'datum_ende': datumEnde.toIso8601String().split('T').first,
      'referenz_nr': referenzNr,
      'ist_aktiv': istAktiv,
      'preisliste_id': preislisteId,
      'pauschale': pauschale,
      'anzahl_feiertage': anzahlFeiertage,
      'feiertag_zuschlag': feiertagZuschlag,
      'pauschale_gesamt': pauschaleGesamt,
      'abrechnungs_monat': abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': abgerechnet,
      'google_calendar_event_id': googleCalendarEventId,
      'kalender_sync_status': kalenderSyncStatus,
      'notizen': notizen,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}
