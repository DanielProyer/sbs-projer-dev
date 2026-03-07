import 'package:sbs_projer_app/data/local/betrieb_local.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';

class BetriebMapper {
  static BetriebLocal fromDto(Betrieb dto, {BetriebLocal? existing}) {
    final local = existing ?? BetriebLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.name = dto.name;
    local.strasse = dto.strasse;
    local.nr = dto.nr;
    local.plz = dto.plz;
    local.ort = dto.ort;
    local.regionId = dto.regionId;
    local.email = dto.email;
    local.website = dto.website;
    local.zugangNotizen = dto.zugangNotizen;
    local.heinekenNr = dto.heinekenNr;
    local.status = dto.status;
    local.istMeinKunde = dto.istMeinKunde;
    local.istBergkunde = dto.istBergkunde;
    local.istSaisonbetrieb = dto.istSaisonbetrieb;
    local.winterSaisonAktiv = dto.winterSaisonAktiv;
    local.winterStartMonat = dto.winterStartMonat;
    local.winterEndeMonat = dto.winterEndeMonat;
    local.sommerSaisonAktiv = dto.sommerSaisonAktiv;
    local.sommerStartMonat = dto.sommerStartMonat;
    local.sommerEndeMonat = dto.sommerEndeMonat;
    local.ruhetage = dto.ruhetage;
    local.rechnungsstellung = dto.rechnungsstellung;
    local.latitude = dto.latitude;
    local.longitude = dto.longitude;
    local.ferienStart = dto.ferienStart;
    local.ferienEnde = dto.ferienEnde;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(BetriebLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'name': local.name,
      'strasse': local.strasse,
      'nr': local.nr,
      'plz': local.plz,
      'ort': local.ort,
      'region_id': local.regionId,
      'email': local.email,
      'website': local.website,
      'zugang_notizen': local.zugangNotizen,
      'heineken_nr': local.heinekenNr,
      'status': local.status,
      'ist_mein_kunde': local.istMeinKunde,
      'ist_bergkunde': local.istBergkunde,
      'ist_saisonbetrieb': local.istSaisonbetrieb,
      'winter_saison_aktiv': local.winterSaisonAktiv,
      'winter_start_monat': local.winterStartMonat,
      'winter_ende_monat': local.winterEndeMonat,
      'sommer_saison_aktiv': local.sommerSaisonAktiv,
      'sommer_start_monat': local.sommerStartMonat,
      'sommer_ende_monat': local.sommerEndeMonat,
      'ruhetage': local.ruhetage,
      'rechnungsstellung': local.rechnungsstellung,
      'latitude': local.latitude,
      'longitude': local.longitude,
      'ferien_start': local.ferienStart?.toIso8601String().split('T').first,
      'ferien_ende': local.ferienEnde?.toIso8601String().split('T').first,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
