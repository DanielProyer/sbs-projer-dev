class MaterialArtikel {
  final String id;
  final String userId;
  final String? kategorieId;
  final String dboNr;
  final String name;
  final String? beschreibung;
  final String einheit;
  final String? fotoStoragePath;
  final DateTime? gueltigAb;
  final bool istAuslaufartikel;
  final DateTime? auslaufDatum;
  final String? nachfolgerId;
  final bool istAktiv;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MaterialArtikel({
    required this.id,
    required this.userId,
    this.kategorieId,
    required this.dboNr,
    required this.name,
    this.beschreibung,
    this.einheit = 'Stück',
    this.fotoStoragePath,
    this.gueltigAb,
    this.istAuslaufartikel = false,
    this.auslaufDatum,
    this.nachfolgerId,
    this.istAktiv = true,
    this.createdAt,
    this.updatedAt,
  });

  factory MaterialArtikel.fromJson(Map<String, dynamic> json) {
    return MaterialArtikel(
      id: json['id'],
      userId: json['user_id'],
      kategorieId: json['kategorie_id'],
      dboNr: json['dbo_nr'],
      name: json['name'],
      beschreibung: json['beschreibung'],
      einheit: json['einheit'] ?? 'Stück',
      fotoStoragePath: json['foto_storage_path'],
      gueltigAb: json['gueltig_ab'] != null ? DateTime.parse(json['gueltig_ab']) : null,
      istAuslaufartikel: json['ist_auslaufartikel'] ?? false,
      auslaufDatum: json['auslauf_datum'] != null ? DateTime.parse(json['auslauf_datum']) : null,
      nachfolgerId: json['nachfolger_id'],
      istAktiv: json['ist_aktiv'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'kategorie_id': kategorieId,
      'dbo_nr': dboNr,
      'name': name,
      'beschreibung': beschreibung,
      'einheit': einheit,
      'foto_storage_path': fotoStoragePath,
      'gueltig_ab': gueltigAb?.toIso8601String().split('T').first,
      'ist_auslaufartikel': istAuslaufartikel,
      'auslauf_datum': auslaufDatum?.toIso8601String().split('T').first,
      'nachfolger_id': nachfolgerId,
      'ist_aktiv': istAktiv,
    };
  }
}
