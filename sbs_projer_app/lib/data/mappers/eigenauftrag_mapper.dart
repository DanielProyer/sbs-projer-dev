import 'package:sbs_projer_app/data/local/eigenauftrag_local.dart';
import 'package:sbs_projer_app/data/models/eigenauftrag.dart';

class EigenauftragMapper {
  static EigenauftragLocal fromDto(Eigenauftrag dto, {EigenauftragLocal? existing}) {
    final local = existing ?? EigenauftragLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.anlageId = dto.anlageId;
    local.betriebId = dto.betriebId;
    local.stoerungsnummer = dto.stoerungsnummer;
    local.referenzNr = dto.referenzNr;
    local.datum = dto.datum;
    local.uhrzeit = dto.uhrzeit;
    local.entdecktBeiServiceId = dto.entdecktBeiServiceId;
    local.problemBeschreibung = dto.problemBeschreibung;
    local.loesungBeschreibung = dto.loesungBeschreibung;
    local.status = dto.status;
    local.preislisteId = dto.preislisteId;
    local.pauschale = dto.pauschale;
    local.abrechnungsMonat = dto.abrechnungsMonat;
    local.abgerechnet = dto.abgerechnet;
    local.material1Id = dto.material1Id;
    local.material1Menge = dto.material1Menge;
    local.material2Id = dto.material2Id;
    local.material2Menge = dto.material2Menge;
    local.material3Id = dto.material3Id;
    local.material3Menge = dto.material3Menge;
    local.material4Id = dto.material4Id;
    local.material4Menge = dto.material4Menge;
    local.material5Id = dto.material5Id;
    local.material5Menge = dto.material5Menge;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EigenauftragLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'anlage_id': local.anlageId,
      'betrieb_id': local.betriebId,
      'stoerungsnummer': local.stoerungsnummer,
      'referenz_nr': local.referenzNr,
      'datum': local.datum.toIso8601String().split('T').first,
      'uhrzeit': local.uhrzeit,
      'entdeckt_bei_service_id': local.entdecktBeiServiceId,
      'problem_beschreibung': local.problemBeschreibung,
      'loesung_beschreibung': local.loesungBeschreibung,
      'status': local.status,
      'preisliste_id': local.preislisteId,
      'pauschale': local.pauschale,
      'abrechnungs_monat': local.abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': local.abgerechnet,
      'material_1_id': local.material1Id,
      'material_1_menge': local.material1Menge,
      'material_2_id': local.material2Id,
      'material_2_menge': local.material2Menge,
      'material_3_id': local.material3Id,
      'material_3_menge': local.material3Menge,
      'material_4_id': local.material4Id,
      'material_4_menge': local.material4Menge,
      'material_5_id': local.material5Id,
      'material_5_menge': local.material5Menge,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
