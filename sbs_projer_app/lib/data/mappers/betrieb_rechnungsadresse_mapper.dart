import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';

class BetriebRechnungsadresseMapper {
  static BetriebRechnungsadresseLocal fromDto(BetriebRechnungsadresse dto, {BetriebRechnungsadresseLocal? existing}) {
    final local = existing ?? BetriebRechnungsadresseLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.firma = dto.firma;
    local.vorname = dto.vorname;
    local.nachname = dto.nachname;
    local.strasse = dto.strasse;
    local.nr = dto.nr;
    local.plz = dto.plz;
    local.ort = dto.ort;
    local.email = dto.email;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(BetriebRechnungsadresseLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'firma': local.firma,
      'vorname': local.vorname,
      'nachname': local.nachname,
      'strasse': local.strasse,
      'nr': local.nr,
      'plz': local.plz,
      'ort': local.ort,
      'email': local.email,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
