import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/event_kontakt.dart';

class EventKontaktMapper {
  static EventKontaktLocal fromDto(EventKontakt dto, {EventKontaktLocal? existing}) {
    final local = existing ?? EventKontaktLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.kontaktId = dto.kontaktId;
    local.rolle = dto.rolle;
    local.bemerkung = dto.bemerkung;
    local.standId = dto.standId;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventKontaktLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'kontakt_id': local.kontaktId,
      'rolle': local.rolle,
      'bemerkung': local.bemerkung,
      'stand_id': local.standId,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
