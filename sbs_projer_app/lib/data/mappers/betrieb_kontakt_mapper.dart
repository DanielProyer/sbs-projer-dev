import 'package:sbs_projer_app/data/local/betrieb_kontakt_local.dart';
import 'package:sbs_projer_app/data/models/betrieb_kontakt.dart';

class BetriebKontaktMapper {
  static BetriebKontaktLocal fromDto(BetriebKontakt dto, {BetriebKontaktLocal? existing}) {
    final local = existing ?? BetriebKontaktLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.vorname = dto.vorname;
    local.nachname = dto.nachname;
    local.funktion = dto.funktion;
    local.telefon = dto.telefon;
    local.email = dto.email;
    local.telefonNormalized = dto.telefonNormalized;
    local.phoneContactId = dto.phoneContactId;
    // phoneLastSyncedAt exists only in DTO, not in Local
    local.kontaktMethode = dto.kontaktMethode;
    local.istHauptkontakt = dto.istHauptkontakt;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(BetriebKontaktLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'vorname': local.vorname,
      'nachname': local.nachname,
      'funktion': local.funktion,
      'telefon': local.telefon,
      'email': local.email,
      'telefon_normalized': local.telefonNormalized,
      'phone_contact_id': local.phoneContactId,
      'kontakt_methode': local.kontaktMethode,
      'ist_hauptkontakt': local.istHauptkontakt,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
