class UserProfile {
  final String id;
  final String vorname;
  final String nachname;
  final String? telefon;
  final String? email;
  final String firmaName;
  final String? firmaStrasse;
  final String? firmaNr;
  final String? firmaPlz;
  final String? firmaOrt;
  final String? uidNummer;
  final String? mwstNummer;
  final String? iban;
  final String? heinekenPoNummer;
  final String? defaultRegionId;
  final String sprache;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.vorname,
    required this.nachname,
    this.telefon,
    this.email,
    required this.firmaName,
    this.firmaStrasse,
    this.firmaNr,
    this.firmaPlz,
    this.firmaOrt,
    this.uidNummer,
    this.mwstNummer,
    this.iban,
    this.heinekenPoNummer,
    this.defaultRegionId,
    this.sprache = 'de',
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      vorname: json['vorname'],
      nachname: json['nachname'],
      telefon: json['telefon'],
      email: json['email'],
      firmaName: json['firma_name'],
      firmaStrasse: json['firma_strasse'],
      firmaNr: json['firma_nr'],
      firmaPlz: json['firma_plz'],
      firmaOrt: json['firma_ort'],
      uidNummer: json['uid_nummer'],
      mwstNummer: json['mwst_nummer'],
      iban: json['iban'],
      heinekenPoNummer: json['heineken_po_nummer'],
      defaultRegionId: json['default_region_id'],
      sprache: json['sprache'] ?? 'de',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vorname': vorname,
      'nachname': nachname,
      'telefon': telefon,
      'email': email,
      'firma_name': firmaName,
      'firma_strasse': firmaStrasse,
      'firma_nr': firmaNr,
      'firma_plz': firmaPlz,
      'firma_ort': firmaOrt,
      'uid_nummer': uidNummer,
      'mwst_nummer': mwstNummer,
      'iban': iban,
      'heineken_po_nummer': heinekenPoNummer,
      'default_region_id': defaultRegionId,
      'sprache': sprache,
    };
  }

  String get vollerName => '$vorname $nachname';

  String get firmaAdresse {
    final parts = <String>[];
    parts.add(firmaName);
    if (firmaStrasse != null) {
      parts.add('$firmaStrasse${firmaNr != null ? " $firmaNr" : ""}');
    }
    if (firmaPlz != null && firmaOrt != null) {
      parts.add('$firmaPlz $firmaOrt');
    }
    return parts.join(', ');
  }
}
