/// Protokollzeile eines Mahnlaufs (Migration 200/201, v0.134.0) — je
/// versendetem/gedrucktem Sammel-Mahnschreiben EIN Eintrag. Grundlage für
/// «Mahnung zurücknehmen»: [vorher] hält den Zustand jeder betroffenen
/// Rechnung fest, wie er VOR diesem Schreiben war.
class Mahnschreiben {
  final String id;
  final String userId;
  final String betriebId;

  /// Höchste Stufe unter den enthaltenen Rechnungen (`MahnStufe.wert`).
  final int stufe;
  final List<String> rechnungIds;

  /// 'mail' | 'druck' | 'mail_und_druck'.
  final String kanal;

  /// Tatsächliche Empfängeradresse (Kunde) — null bei reiner Druck-Variante.
  final String? empfaenger;

  /// true = Testmodus (an Daniel statt an den Kunden gegangen).
  final bool test;
  final DateTime fristBis;
  final String? pdfPfad;

  /// Zustand jeder Rechnung VOR dem Schreiben:
  /// `{"(rechnungId)": {zahlungsstatus, mahnung_stufe, letzte_mahnung_am,
  ///   erinnerung_am, mahnung_1_am, mahnung_2_am, mahn_frist_bis}}`.
  final Map<String, dynamic> vorher;
  final DateTime erstelltAm;
  final DateTime? zurueckgenommenAm;

  Mahnschreiben({
    required this.id,
    required this.userId,
    required this.betriebId,
    required this.stufe,
    required this.rechnungIds,
    required this.kanal,
    this.empfaenger,
    required this.test,
    required this.fristBis,
    this.pdfPfad,
    required this.vorher,
    required this.erstelltAm,
    this.zurueckgenommenAm,
  });

  bool get zurueckgenommen => zurueckgenommenAm != null;

  factory Mahnschreiben.fromJson(Map<String, dynamic> json) {
    return Mahnschreiben(
      id: json['id'],
      userId: json['user_id'],
      betriebId: json['betrieb_id'],
      stufe: json['stufe'],
      rechnungIds: List<String>.from(json['rechnung_ids'] as List),
      kanal: json['kanal'],
      empfaenger: json['empfaenger'],
      test: json['test'] ?? true,
      fristBis: DateTime.parse(json['frist_bis']),
      pdfPfad: json['pdf_pfad'],
      vorher: json['vorher'] is Map
          ? Map<String, dynamic>.from(json['vorher'])
          : <String, dynamic>{},
      erstelltAm: DateTime.parse(json['erstellt_am']),
      zurueckgenommenAm: json['zurueckgenommen_am'] != null
          ? DateTime.parse(json['zurueckgenommen_am'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'betrieb_id': betriebId,
      'stufe': stufe,
      'rechnung_ids': rechnungIds,
      'kanal': kanal,
      'empfaenger': empfaenger,
      'test': test,
      'frist_bis': fristBis.toIso8601String().split('T').first,
      'pdf_pfad': pdfPfad,
      'vorher': vorher,
    };
  }
}
