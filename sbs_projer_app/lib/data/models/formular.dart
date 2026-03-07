class Formular {
  final String id;
  final String userId;
  final String formularTyp;
  final String serviceTyp;
  final String serviceId;
  final String? referenzNr;
  final String? rechnungId;
  final DateTime? abrechnungsMonat;
  final String? pdfStoragePath;
  final DateTime? pdfGeneriertAt;
  final String pdfStatus;
  final String? pdfFehler;
  final Map<String, dynamic>? formularDaten;
  final String? notizen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Formular({
    required this.id,
    required this.userId,
    required this.formularTyp,
    required this.serviceTyp,
    required this.serviceId,
    this.referenzNr,
    this.rechnungId,
    this.abrechnungsMonat,
    this.pdfStoragePath,
    this.pdfGeneriertAt,
    this.pdfStatus = 'ausstehend',
    this.pdfFehler,
    this.formularDaten,
    this.notizen,
    this.createdAt,
    this.updatedAt,
  });

  factory Formular.fromJson(Map<String, dynamic> json) {
    return Formular(
      id: json['id'],
      userId: json['user_id'],
      formularTyp: json['formular_typ'],
      serviceTyp: json['service_typ'],
      serviceId: json['service_id'],
      referenzNr: json['referenz_nr'],
      rechnungId: json['rechnung_id'],
      abrechnungsMonat: json['abrechnungs_monat'] != null
          ? DateTime.parse(json['abrechnungs_monat'])
          : null,
      pdfStoragePath: json['pdf_storage_path'],
      pdfGeneriertAt: json['pdf_generiert_at'] != null
          ? DateTime.parse(json['pdf_generiert_at'])
          : null,
      pdfStatus: json['pdf_status'] ?? 'ausstehend',
      pdfFehler: json['pdf_fehler'],
      formularDaten: json['formular_daten'] != null
          ? Map<String, dynamic>.from(json['formular_daten'])
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
      'formular_typ': formularTyp,
      'service_typ': serviceTyp,
      'service_id': serviceId,
      'referenz_nr': referenzNr,
      'rechnung_id': rechnungId,
      'abrechnungs_monat': abrechnungsMonat?.toIso8601String().split('T').first,
      'pdf_storage_path': pdfStoragePath,
      'pdf_status': pdfStatus,
      'formular_daten': formularDaten,
      'notizen': notizen,
    };
  }
}
