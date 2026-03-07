class BetriebKontakt {
  final String id;
  final String userId;
  final String betriebId;
  final String? vorname;
  final String nachname;
  final String? funktion;
  final String? telefon;
  final String? email;
  final String? telefonNormalized;
  final String? phoneContactId;
  final DateTime? phoneLastSyncedAt;
  final String kontaktMethode;
  final bool istHauptkontakt;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BetriebKontakt({
    required this.id,
    required this.userId,
    required this.betriebId,
    this.vorname,
    required this.nachname,
    this.funktion,
    this.telefon,
    this.email,
    this.telefonNormalized,
    this.phoneContactId,
    this.phoneLastSyncedAt,
    this.kontaktMethode = 'telefon',
    this.istHauptkontakt = false,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory BetriebKontakt.fromJson(Map<String, dynamic> json) {
    return BetriebKontakt(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      vorname: json['vorname'],
      nachname: json['nachname'],
      funktion: json['funktion'],
      telefon: json['telefon'],
      email: json['email'],
      telefonNormalized: json['telefon_normalized'],
      phoneContactId: json['phone_contact_id'],
      phoneLastSyncedAt: json['phone_last_synced_at'] != null
          ? DateTime.parse(json['phone_last_synced_at'])
          : null,
      kontaktMethode: json['kontakt_methode'] ?? 'telefon',
      istHauptkontakt: json['ist_hauptkontakt'] ?? false,
      notizen: json['notizen'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'vorname': vorname,
      'nachname': nachname,
      'funktion': funktion,
      'telefon': telefon,
      'email': email,
      'telefon_normalized': telefonNormalized,
      'phone_contact_id': phoneContactId,
      'kontakt_methode': kontaktMethode,
      'ist_hauptkontakt': istHauptkontakt,
      'notizen': notizen,
    };
  }

  String get vollerName {
    if (vorname != null && vorname!.isNotEmpty) {
      return '$vorname $nachname';
    }
    return nachname;
  }
}
