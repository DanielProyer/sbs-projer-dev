class Kontakt {
  final String id;
  final String userId;
  final String? betriebId;
  final String vorname;
  final String? nachname;
  final String? funktion;
  final String kategorie; // 'betrieb' | 'heineken' | 'event'
  final String? rolle;
  final String? telefon;
  final String? email;
  final String? telefonNormalized;
  final String? phoneContactId;
  final DateTime? phoneLastSyncedAt;
  final String kontaktMethode;
  final bool istHauptkontakt;
  final bool istDuAnrede;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Kontakt({
    required this.id,
    required this.userId,
    this.betriebId,
    required this.vorname,
    this.nachname,
    this.funktion,
    this.kategorie = 'betrieb',
    this.rolle,
    this.telefon,
    this.email,
    this.telefonNormalized,
    this.phoneContactId,
    this.phoneLastSyncedAt,
    this.kontaktMethode = 'telefon',
    this.istHauptkontakt = false,
    this.istDuAnrede = false,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory Kontakt.fromJson(Map<String, dynamic> json) {
    return Kontakt(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      vorname: json['vorname'] ?? '',
      nachname: json['nachname'],
      funktion: json['funktion'],
      kategorie: json['kategorie'] ?? 'betrieb',
      rolle: json['rolle'],
      telefon: json['telefon'],
      email: json['email'],
      telefonNormalized: json['telefon_normalized'],
      phoneContactId: json['phone_contact_id'],
      phoneLastSyncedAt: json['phone_last_synced_at'] != null
          ? DateTime.parse(json['phone_last_synced_at'])
          : null,
      kontaktMethode: json['kontakt_methode'] ?? 'telefon',
      istHauptkontakt: json['ist_hauptkontakt'] ?? false,
      istDuAnrede: json['ist_du_anrede'] ?? false,
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
      'kategorie': kategorie,
      'rolle': rolle,
      'telefon': telefon,
      'email': email,
      'telefon_normalized': telefonNormalized,
      'phone_contact_id': phoneContactId,
      'kontakt_methode': kontaktMethode,
      'ist_hauptkontakt': istHauptkontakt,
      'ist_du_anrede': istDuAnrede,
      'notizen': notizen,
    };
  }

  String get vollerName {
    if (nachname != null && nachname!.isNotEmpty) {
      return '$vorname $nachname';
    }
    return vorname;
  }

  String get kategorieLabel => switch (kategorie) {
    'betrieb' => 'Betrieb',
    'heineken' => 'Heineken',
    'event' => 'Event',
    _ => kategorie,
  };

  String get rolleLabel => switch (rolle) {
    'geschaeftsfuehrer' => 'Geschäftsführer',
    'fb_manager' => 'F&B Manager',
    'mitarbeiter' => 'Mitarbeiter',
    'hauswart' => 'Hauswart',
    'sonstige' => 'Sonstige',
    'rsl' => 'RSL',
    'buero' => 'Büro',
    'monteur' => 'Monteur',
    'event_heineken' => 'Event Heineken',
    'pikett' => 'Pikett',
    'vertreter' => 'Vertreter',
    'ok' => 'OK',
    'bau' => 'Bau',
    'stand' => 'Stand',
    _ => rolle ?? '',
  };

  static List<String> rollenFuerKategorie(String kategorie) => switch (kategorie) {
    'betrieb' => ['geschaeftsfuehrer', 'fb_manager', 'mitarbeiter', 'hauswart', 'sonstige'],
    'heineken' => ['rsl', 'vertreter', 'buero', 'monteur', 'event_heineken', 'pikett'],
    'event' => ['ok', 'bau', 'stand'],
    _ => [],
  };

  static String rolleLabelStatic(String rolle) => switch (rolle) {
    'geschaeftsfuehrer' => 'Geschäftsführer',
    'fb_manager' => 'F&B Manager',
    'mitarbeiter' => 'Mitarbeiter',
    'hauswart' => 'Hauswart',
    'sonstige' => 'Sonstige',
    'rsl' => 'RSL',
    'buero' => 'Büro',
    'monteur' => 'Monteur',
    'event_heineken' => 'Event Heineken',
    'pikett' => 'Pikett',
    'vertreter' => 'Vertreter',
    'ok' => 'OK',
    'bau' => 'Bau',
    'stand' => 'Stand',
    _ => rolle,
  };
}
