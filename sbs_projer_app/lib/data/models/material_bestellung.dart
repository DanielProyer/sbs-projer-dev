class MaterialBestellung {
  final String id;
  final String userId;
  final String bestellNr;
  final DateTime datum;
  final String? empfaengerName;
  final String? empfaengerEmail;
  final String status;
  final String? pdfStoragePath;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MaterialBestellposition> positionen;

  MaterialBestellung({
    required this.id,
    required this.userId,
    required this.bestellNr,
    required this.datum,
    this.empfaengerName,
    this.empfaengerEmail,
    this.status = 'entwurf',
    this.pdfStoragePath,
    this.notizen,
    this.createdAt,
    this.updatedAt,
    this.positionen = const [],
  });

  factory MaterialBestellung.fromJson(Map<String, dynamic> json) {
    return MaterialBestellung(
      id: json['id'],
      userId: json['user_id'],
      bestellNr: json['bestell_nr'],
      datum: DateTime.parse(json['datum']),
      empfaengerName: json['empfaenger_name'],
      empfaengerEmail: json['empfaenger_email'],
      status: json['status'] ?? 'entwurf',
      pdfStoragePath: json['pdf_storage_path'],
      notizen: json['notizen'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bestell_nr': bestellNr,
      'datum': datum.toIso8601String().substring(0, 10),
      'empfaenger_name': empfaengerName,
      'empfaenger_email': empfaengerEmail,
      'status': status,
      'pdf_storage_path': pdfStoragePath,
      'notizen': notizen,
    };
  }
}

class MaterialBestellposition {
  final String id;
  final String bestellungId;
  final String? lagerId;
  final String? dboNr;
  final String? sapNr;
  final String name;
  final String einheit;
  final double menge;
  final double? bestandAktuell;
  final double? bestandOptimal;
  final String? kategorieName;
  final int sortierung;

  MaterialBestellposition({
    required this.id,
    required this.bestellungId,
    this.lagerId,
    this.dboNr,
    this.sapNr,
    required this.name,
    this.einheit = 'Stück',
    this.menge = 1,
    this.bestandAktuell,
    this.bestandOptimal,
    this.kategorieName,
    this.sortierung = 0,
  });

  factory MaterialBestellposition.fromJson(Map<String, dynamic> json) {
    return MaterialBestellposition(
      id: json['id'],
      bestellungId: json['bestellung_id'],
      lagerId: json['lager_id'],
      dboNr: json['dbo_nr'],
      sapNr: json['sap_nr'],
      name: json['name'],
      einheit: json['einheit'] ?? 'Stück',
      menge: double.tryParse(json['menge'].toString()) ?? 1,
      bestandAktuell: json['bestand_aktuell'] != null
          ? double.tryParse(json['bestand_aktuell'].toString())
          : null,
      bestandOptimal: json['bestand_optimal'] != null
          ? double.tryParse(json['bestand_optimal'].toString())
          : null,
      kategorieName: json['kategorie_name'],
      sortierung: json['sortierung'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bestellung_id': bestellungId,
      'lager_id': lagerId,
      'dbo_nr': dboNr,
      'sap_nr': sapNr,
      'name': name,
      'einheit': einheit,
      'menge': menge,
      'bestand_aktuell': bestandAktuell,
      'bestand_optimal': bestandOptimal,
      'kategorie_name': kategorieName,
      'sortierung': sortierung,
    };
  }
}
