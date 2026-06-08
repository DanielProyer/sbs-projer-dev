class CamtRegel {
  final String? id;
  final String bezeichnung;
  final String? matchName;
  final String? matchIban;
  final String buchungsVorlageId;
  final int prioritaet;
  final bool istAktiv;

  CamtRegel({
    this.id,
    required this.bezeichnung,
    this.matchName,
    this.matchIban,
    required this.buchungsVorlageId,
    this.prioritaet = 0,
    this.istAktiv = true,
  });

  factory CamtRegel.fromJson(Map<String, dynamic> j) => CamtRegel(
        id: j['id'],
        bezeichnung: j['bezeichnung'],
        matchName: j['match_name'],
        matchIban: j['match_iban'],
        buchungsVorlageId: j['buchungs_vorlage_id'],
        prioritaet: j['prioritaet'] ?? 0,
        istAktiv: j['ist_aktiv'] ?? true,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'bezeichnung': bezeichnung,
        'match_name': matchName,
        'match_iban': matchIban,
        'buchungs_vorlage_id': buchungsVorlageId,
        'prioritaet': prioritaet,
        'ist_aktiv': istAktiv,
      };
}
