import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/models/anlage.dart';

class AnlageMapper {
  static AnlageLocal fromDto(Anlage dto, {AnlageLocal? existing}) {
    final local = existing ?? AnlageLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.bezeichnung = dto.bezeichnung;
    local.seriennummer = dto.seriennummer;
    local.typAnlage = dto.typAnlage;
    local.typSaeule = dto.typSaeule;
    local.anzahlHaehne = dto.anzahlHaehne;
    local.backpython = dto.backpython;
    local.booster = dto.booster;
    local.vorkuehler = dto.vorkuehler;
    local.durchlaufkuehler = dto.durchlaufkuehler;
    local.letzterWasserwechsel = dto.letzterWasserwechsel;
    local.gasTyp1 = dto.gasTyp1;
    local.gasTyp2 = dto.gasTyp2;
    local.hauptdruckBar = dto.hauptdruckBar;
    local.hatNiederdruck = dto.hatNiederdruck;
    local.servicezeitMorgenAb = dto.servicezeitMorgenAb;
    local.servicezeitMorgenBis = dto.servicezeitMorgenBis;
    local.servicezeitNachmittagAb = dto.servicezeitNachmittagAb;
    local.servicezeitNachmittagBis = dto.servicezeitNachmittagBis;
    local.reinigungRhythmus = dto.reinigungRhythmus;
    local.letzteReinigung = dto.letzteReinigung;
    local.naechsteReinigung = dto.naechsteReinigung;
    local.status = dto.status;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(AnlageLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'bezeichnung': local.bezeichnung,
      'seriennummer': local.seriennummer,
      'typ_anlage': local.typAnlage,
      'typ_saeule': local.typSaeule,
      'anzahl_haehne': local.anzahlHaehne,
      'backpython': local.backpython,
      'booster': local.booster,
      'vorkuehler': local.vorkuehler,
      'durchlaufkuehler': local.durchlaufkuehler,
      'letzter_wasserwechsel': local.letzterWasserwechsel?.toIso8601String().split('T').first,
      'gas_typ_1': local.gasTyp1,
      'gas_typ_2': local.gasTyp2,
      'hauptdruck_bar': local.hauptdruckBar,
      'hat_niederdruck': local.hatNiederdruck,
      'servicezeit_morgen_ab': local.servicezeitMorgenAb,
      'servicezeit_morgen_bis': local.servicezeitMorgenBis,
      'servicezeit_nachmittag_ab': local.servicezeitNachmittagAb,
      'servicezeit_nachmittag_bis': local.servicezeitNachmittagBis,
      'reinigung_rhythmus': local.reinigungRhythmus,
      'status': local.status,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
