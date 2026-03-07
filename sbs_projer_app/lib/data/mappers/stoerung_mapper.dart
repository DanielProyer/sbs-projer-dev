import 'package:sbs_projer_app/data/local/stoerung_local.dart';
import 'package:sbs_projer_app/data/models/stoerung.dart';

class StoerungMapper {
  static StoerungLocal fromDto(Stoerung dto, {StoerungLocal? existing}) {
    final local = existing ?? StoerungLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.anlageId = dto.anlageId;
    local.betriebId = dto.betriebId;
    local.stoerungsnummer = dto.stoerungsnummer;
    local.referenzNr = dto.referenzNr;
    local.datum = dto.datum;
    local.uhrzeitStart = dto.uhrzeitStart;
    local.uhrzeitEnde = dto.uhrzeitEnde;
    // dauerMinuten is GENERATED, not stored locally
    local.anlageTyp = dto.anlageTyp;
    local.problemBeschreibung = dto.problemBeschreibung;
    local.loesungBeschreibung = dto.loesungBeschreibung;
    local.istPikettEinsatz = dto.istPikettEinsatz;
    local.status = dto.status;
    local.stoerungBereich = dto.stoerungBereich;
    local.preislisteId = dto.preislisteId;
    local.istBergkunde = dto.istBergkunde;
    local.anfahrtKm = dto.anfahrtKm;
    local.istWochenende = dto.istWochenende;
    local.komplexitaetZuschlag = dto.komplexitaetZuschlag;
    local.preisBasis = dto.preisBasis;
    local.preisAnfahrt = dto.preisAnfahrt;
    local.preisWochenende = dto.preisWochenende;
    local.preisNetto = dto.preisNetto;
    local.mwstSatz = dto.mwstSatz;
    local.preisMwst = dto.preisMwst;
    local.preisBrutto = dto.preisBrutto;
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
    local.abrechnungsMonat = dto.abrechnungsMonat;
    local.abgerechnet = dto.abgerechnet;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(StoerungLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'anlage_id': local.anlageId,
      'betrieb_id': local.betriebId,
      'stoerungsnummer': local.stoerungsnummer,
      'referenz_nr': local.referenzNr,
      'datum': local.datum.toIso8601String().split('T').first,
      'uhrzeit_start': local.uhrzeitStart,
      'uhrzeit_ende': local.uhrzeitEnde,
      // dauerMinuten is GENERATED, not included
      'anlage_typ': local.anlageTyp,
      'problem_beschreibung': local.problemBeschreibung,
      'loesung_beschreibung': local.loesungBeschreibung,
      'ist_pikett_einsatz': local.istPikettEinsatz,
      'status': local.status,
      'stoerung_bereich': local.stoerungBereich,
      'preisliste_id': local.preislisteId,
      'ist_bergkunde': local.istBergkunde,
      'anfahrt_km': local.anfahrtKm,
      'ist_wochenende': local.istWochenende,
      'komplexitaet_zuschlag': local.komplexitaetZuschlag,
      'preis_basis': local.preisBasis,
      'preis_anfahrt': local.preisAnfahrt,
      'preis_wochenende': local.preisWochenende,
      'preis_netto': local.preisNetto,
      'mwst_satz': local.mwstSatz,
      'preis_mwst': local.preisMwst,
      'preis_brutto': local.preisBrutto,
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
      'abrechnungs_monat': local.abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': local.abgerechnet,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
