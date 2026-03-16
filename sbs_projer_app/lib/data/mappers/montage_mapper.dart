import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/models/montage.dart';

class MontageMapper {
  static MontageLocal fromDto(Montage dto, {MontageLocal? existing}) {
    final local = existing ?? MontageLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.anlageId = dto.anlageId;
    local.betriebId = dto.betriebId;
    local.montageTyp = dto.montageTyp;
    local.beschreibung = dto.beschreibung;
    local.referenzNr = dto.referenzNr;
    local.datum = dto.datum;
    local.uhrzeitStart = dto.uhrzeitStart;
    local.uhrzeitEnde = dto.uhrzeitEnde;
    // dauerMinuten is GENERATED, not stored locally
    local.status = dto.status;
    local.preislisteId = dto.preislisteId;
    local.stundensatz = dto.stundensatz;
    local.dauerStunden = dto.dauerStunden;
    local.kostenArbeit = dto.kostenArbeit;
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
    local.material6Id = dto.material6Id;
    local.material6Menge = dto.material6Menge;
    local.material7Id = dto.material7Id;
    local.material7Menge = dto.material7Menge;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(MontageLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'anlage_id': local.anlageId,
      'betrieb_id': local.betriebId,
      'montage_typ': local.montageTyp,
      'beschreibung': local.beschreibung,
      'referenz_nr': local.referenzNr,
      'datum': local.datum.toIso8601String().split('T').first,
      'uhrzeit_start': local.uhrzeitStart,
      'uhrzeit_ende': local.uhrzeitEnde,
      // dauerMinuten is GENERATED, not included
      'status': local.status,
      'preisliste_id': local.preislisteId,
      'stundensatz': local.stundensatz,
      'dauer_stunden': local.dauerStunden,
      'kosten_arbeit': local.kostenArbeit,
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
      'material_6_id': local.material6Id,
      'material_6_menge': local.material6Menge,
      'material_7_id': local.material7Id,
      'material_7_menge': local.material7Menge,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
