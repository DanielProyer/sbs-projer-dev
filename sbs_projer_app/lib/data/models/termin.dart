class Termin {
  final String id;
  final String userId;
  final String betriebId;
  final DateTime datum;
  final String? uhrzeitVon;
  final String? uhrzeitBis;
  final String typ;
  final String anlass;
  final String titel;
  final String? notizen;
  final String status;
  final int erinnerungTage;
  final bool erinnerungAktiv;
  final int erinnerungVorlaufMinuten;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Termin({
    required this.id,
    required this.userId,
    required this.betriebId,
    required this.datum,
    this.uhrzeitVon,
    this.uhrzeitBis,
    this.typ = 'sonstiges',
    this.anlass = 'manuell',
    required this.titel,
    this.notizen,
    this.status = 'geplant',
    this.erinnerungTage = 3,
    this.erinnerungAktiv = false,
    this.erinnerungVorlaufMinuten = 1440,
    this.createdAt,
    this.updatedAt,
  });

  factory Termin.fromJson(Map<String, dynamic> json) {
    return Termin(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      datum: DateTime.parse(json['datum']),
      uhrzeitVon: json['uhrzeit_von'],
      uhrzeitBis: json['uhrzeit_bis'],
      typ: json['typ'] ?? 'sonstiges',
      anlass: json['anlass'] ?? 'manuell',
      titel: json['titel'],
      notizen: json['notizen'],
      status: json['status'] ?? 'geplant',
      erinnerungTage: json['erinnerung_tage'] ?? 3,
      erinnerungAktiv: json['erinnerung_aktiv'] ?? false,
      erinnerungVorlaufMinuten: json['erinnerung_vorlauf_minuten'] ?? 1440,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'datum': datum.toIso8601String().split('T').first,
      'uhrzeit_von': uhrzeitVon,
      'uhrzeit_bis': uhrzeitBis,
      'typ': typ,
      'anlass': anlass,
      'titel': titel,
      'notizen': notizen,
      'status': status,
      'erinnerung_tage': erinnerungTage,
      'erinnerung_aktiv': erinnerungAktiv,
      'erinnerung_vorlauf_minuten': erinnerungVorlaufMinuten,
    };
  }
}
