import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/kontakt.dart';

class KontaktMapper {
  static KontaktLocal fromDto(Kontakt dto, {KontaktLocal? existing}) {
    final local = existing ?? KontaktLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.vorname = dto.vorname;
    local.nachname = dto.nachname;
    local.funktion = dto.funktion;
    local.kategorie = dto.kategorie;
    local.rolle = dto.rolle;
    local.telefon = dto.telefon;
    local.email = dto.email;
    local.telefonNormalized = dto.telefonNormalized;
    local.kontaktMethode = dto.kontaktMethode;
    local.istHauptkontakt = dto.istHauptkontakt;
    local.istDuAnrede = dto.istDuAnrede;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(KontaktLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'vorname': local.vorname,
      'nachname': local.nachname,
      'funktion': local.funktion,
      'kategorie': local.kategorie,
      'rolle': local.rolle,
      'telefon': local.telefon,
      'email': local.email,
      'telefon_normalized': local.telefonNormalized,
      'kontakt_methode': local.kontaktMethode,
      'ist_hauptkontakt': local.istHauptkontakt,
      'ist_du_anrede': local.istDuAnrede,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
