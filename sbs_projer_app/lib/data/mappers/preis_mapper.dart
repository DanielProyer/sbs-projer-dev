import 'package:sbs_projer_app/data/local/preis_local.dart';
import 'package:sbs_projer_app/data/models/preis.dart';

class PreisMapper {
  static PreisLocal fromDto(Preis dto, {PreisLocal? existing}) {
    final local = existing ?? PreisLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.gueltigAb = dto.gueltigAb;
    local.gueltigBis = dto.gueltigBis;
    local.mwstSatz = dto.mwstSatz;
    local.bergkundenZuschlag = dto.bergkundenZuschlag;
    local.grundtarifReinigungBier = dto.grundtarifReinigungBier;
    local.grundtarifReinigungOrion = dto.grundtarifReinigungOrion;
    local.grundtarifHeigenie = dto.grundtarifHeigenie;
    local.grundtarifReinigungFremd = dto.grundtarifReinigungFremd;
    local.grundtarifWein = dto.grundtarifWein;
    local.zusatzHahnEigen = dto.zusatzHahnEigen;
    local.zusatzHahnOrion = dto.zusatzHahnOrion;
    local.zusatzHahnFremd = dto.zusatzHahnFremd;
    local.zusatzHahnWein = dto.zusatzHahnWein;
    local.zusatzHahnAndererStandort = dto.zusatzHahnAndererStandort;
    local.eigenauftragPauschale = dto.eigenauftragPauschale;
    local.montageStundensatz = dto.montageStundensatz;
    local.pikettPauschale = dto.pikettPauschale;
    local.pikettFeiertagZuschlag = dto.pikettFeiertagZuschlag;
    local.eroeffnungPreisNormal = dto.eroeffnungPreisNormal;
    local.eroeffnungPreisBergkunde = dto.eroeffnungPreisBergkunde;
    local.stoerung1Normal = dto.stoerung1Normal;
    local.stoerung1Bergkunde = dto.stoerung1Bergkunde;
    local.stoerung2Normal = dto.stoerung2Normal;
    local.stoerung2Bergkunde = dto.stoerung2Bergkunde;
    local.stoerung3Normal = dto.stoerung3Normal;
    local.stoerung3Bergkunde = dto.stoerung3Bergkunde;
    local.stoerung4Normal = dto.stoerung4Normal;
    local.stoerung4Bergkunde = dto.stoerung4Bergkunde;
    local.stoerung5Normal = dto.stoerung5Normal;
    local.stoerung5Bergkunde = dto.stoerung5Bergkunde;
    local.stoerungAnfahrtPauschale = dto.stoerungAnfahrtPauschale;
    local.stoerungAnfahrtKmGrenze = dto.stoerungAnfahrtKmGrenze;
    local.stoerungAnfahrtKmSatz = dto.stoerungAnfahrtKmSatz;
    local.stoerungWochenendeZuschlag = dto.stoerungWochenendeZuschlag;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(PreisLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'gueltig_ab': local.gueltigAb.toIso8601String().split('T').first,
      'gueltig_bis': local.gueltigBis?.toIso8601String().split('T').first,
      'mwst_satz': local.mwstSatz,
      'bergkunden_zuschlag': local.bergkundenZuschlag,
      'grundtarif_reinigung_bier': local.grundtarifReinigungBier,
      'grundtarif_reinigung_orion': local.grundtarifReinigungOrion,
      'grundtarif_heigenie': local.grundtarifHeigenie,
      'grundtarif_reinigung_fremd': local.grundtarifReinigungFremd,
      'grundtarif_wein': local.grundtarifWein,
      'zusatz_hahn_eigen': local.zusatzHahnEigen,
      'zusatz_hahn_orion': local.zusatzHahnOrion,
      'zusatz_hahn_fremd': local.zusatzHahnFremd,
      'zusatz_hahn_wein': local.zusatzHahnWein,
      'zusatz_hahn_anderer_standort': local.zusatzHahnAndererStandort,
      'eigenauftrag_pauschale': local.eigenauftragPauschale,
      'montage_stundensatz': local.montageStundensatz,
      'pikett_pauschale': local.pikettPauschale,
      'pikett_feiertag_zuschlag': local.pikettFeiertagZuschlag,
      'eroeffnung_preis_normal': local.eroeffnungPreisNormal,
      'eroeffnung_preis_bergkunde': local.eroeffnungPreisBergkunde,
      'stoerung_1_normal': local.stoerung1Normal,
      'stoerung_1_bergkunde': local.stoerung1Bergkunde,
      'stoerung_2_normal': local.stoerung2Normal,
      'stoerung_2_bergkunde': local.stoerung2Bergkunde,
      'stoerung_3_normal': local.stoerung3Normal,
      'stoerung_3_bergkunde': local.stoerung3Bergkunde,
      'stoerung_4_normal': local.stoerung4Normal,
      'stoerung_4_bergkunde': local.stoerung4Bergkunde,
      'stoerung_5_normal': local.stoerung5Normal,
      'stoerung_5_bergkunde': local.stoerung5Bergkunde,
      'stoerung_anfahrt_pauschale': local.stoerungAnfahrtPauschale,
      'stoerung_anfahrt_km_grenze': local.stoerungAnfahrtKmGrenze,
      'stoerung_anfahrt_km_satz': local.stoerungAnfahrtKmSatz,
      'stoerung_wochenende_zuschlag': local.stoerungWochenendeZuschlag,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
