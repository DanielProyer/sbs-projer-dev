import 'dart:convert';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/reinigung.dart';

class ReinigungMapper {
  static ReinigungLocal fromDto(Reinigung dto, {ReinigungLocal? existing}) {
    final local = existing ?? ReinigungLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.anlageId = dto.anlageId;
    local.betriebId = dto.betriebId;
    local.datum = dto.datum;
    local.uhrzeitStart = dto.uhrzeitStart;
    local.uhrzeitEnde = dto.uhrzeitEnde;
    // dauerMinuten is GENERATED, not stored locally
    local.hatDurchlaufkuehler = dto.hatDurchlaufkuehler;
    local.hatBuffetanstich = dto.hatBuffetanstich;
    local.hatKuehlkeller = dto.hatKuehlkeller;
    local.hatFasskuehler = dto.hatFasskuehler;
    local.begleitkuehlungKontrolliert = dto.begleitkuehlungKontrolliert;
    local.installationAllgemeinKontrolliert = dto.installationAllgemeinKontrolliert;
    local.aligalAnschluesseKontrolliert = dto.aligalAnschluesseKontrolliert;
    local.durchlaufkuehlerAusgeblasen = dto.durchlaufkuehlerAusgeblasen;
    local.wasserstandKontrolliert = dto.wasserstandKontrolliert;
    local.wasserGewechselt = dto.wasserGewechselt;
    local.leitungWasserVorgespuelt = dto.leitungWasserVorgespuelt;
    local.leitungsreinigungReinigungsmittel = dto.leitungsreinigungReinigungsmittel;
    local.foerderdruckKontrolliert = dto.foerderdruckKontrolliert;
    local.zapfhahnZerlegtGereinigt = dto.zapfhahnZerlegtGereinigt;
    local.zapfkopfZerlegtGereinigt = dto.zapfkopfZerlegtGereinigt;
    local.servicekarteAusgefuellt = dto.servicekarteAusgefuellt;
    local.checklisteNotizenJson = dto.checklisteNotizen.isNotEmpty
        ? jsonEncode(dto.checklisteNotizen)
        : null;
    local.unterschriftTechniker = dto.unterschriftTechniker;
    local.unterschriftKunde = dto.unterschriftKunde;
    local.unterschriftKundeName = dto.unterschriftKundeName;
    local.notizen = dto.notizen;
    // preislisteId exists only in DTO, not in Local
    local.serviceTyp = dto.serviceTyp;
    local.anzahlHaehneEigen = dto.anzahlHaehneEigen;
    local.anzahlHaehneOrion = dto.anzahlHaehneOrion;
    local.anzahlHaehneFremd = dto.anzahlHaehneFremd;
    local.anzahlHaehneWein = dto.anzahlHaehneWein;
    local.anzahlHaehneAndererStandort = dto.anzahlHaehneAndererStandort;
    local.istBergkunde = dto.istBergkunde;
    local.preisGrundtarif = dto.preisGrundtarif;
    local.preisZusatzHaehne = dto.preisZusatzHaehne;
    local.bergkundenZuschlag = dto.bergkundenZuschlag;
    local.preisNetto = dto.preisNetto;
    local.mwstSatz = dto.mwstSatz;
    local.preisMwst = dto.preisMwst;
    local.preisBrutto = dto.preisBrutto;
    local.status = dto.status;
    // dto.istSynced is NOT mapped to local.isSynced (different purpose)
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(ReinigungLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'anlage_id': local.anlageId,
      'betrieb_id': local.betriebId,
      'datum': local.datum.toIso8601String().split('T').first,
      'uhrzeit_start': local.uhrzeitStart,
      'uhrzeit_ende': local.uhrzeitEnde,
      // dauerMinuten is GENERATED, not included
      'hat_durchlaufkuehler': local.hatDurchlaufkuehler,
      'hat_buffetanstich': local.hatBuffetanstich,
      'hat_kuehlkeller': local.hatKuehlkeller,
      'hat_fasskuehler': local.hatFasskuehler,
      'begleitkuehlung_kontrolliert': local.begleitkuehlungKontrolliert,
      'installation_allgemein_kontrolliert': local.installationAllgemeinKontrolliert,
      'aligal_anschluesse_kontrolliert': local.aligalAnschluesseKontrolliert,
      'durchlaufkuehler_ausgeblasen': local.durchlaufkuehlerAusgeblasen,
      'wasserstand_kontrolliert': local.wasserstandKontrolliert,
      'wasser_gewechselt': local.wasserGewechselt,
      'leitung_wasser_vorgespuelt': local.leitungWasserVorgespuelt,
      'leitungsreinigung_reinigungsmittel': local.leitungsreinigungReinigungsmittel,
      'foerderdruck_kontrolliert': local.foerderdruckKontrolliert,
      'zapfhahn_zerlegt_gereinigt': local.zapfhahnZerlegtGereinigt,
      'zapfkopf_zerlegt_gereinigt': local.zapfkopfZerlegtGereinigt,
      'servicekarte_ausgefuellt': local.servicekarteAusgefuellt,
      'checkliste_notizen': local.checklisteNotizenJson != null
          ? jsonDecode(local.checklisteNotizenJson!)
          : {},
      'unterschrift_techniker': local.unterschriftTechniker,
      'unterschrift_kunde': local.unterschriftKunde,
      'unterschrift_kunde_name': local.unterschriftKundeName,
      'notizen': local.notizen,
      'service_typ': local.serviceTyp,
      'anzahl_haehne_eigen': local.anzahlHaehneEigen,
      'anzahl_haehne_orion': local.anzahlHaehneOrion,
      'anzahl_haehne_fremd': local.anzahlHaehneFremd,
      'anzahl_haehne_wein': local.anzahlHaehneWein,
      'anzahl_haehne_anderer_standort': local.anzahlHaehneAndererStandort,
      'ist_bergkunde': local.istBergkunde,
      'preis_grundtarif': local.preisGrundtarif,
      'preis_zusatz_haehne': local.preisZusatzHaehne,
      'bergkunden_zuschlag': local.bergkundenZuschlag,
      'preis_netto': local.preisNetto,
      'mwst_satz': local.mwstSatz,
      'preis_mwst': local.preisMwst,
      'preis_brutto': local.preisBrutto,
      'status': local.status,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
