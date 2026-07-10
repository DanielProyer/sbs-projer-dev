import 'package:sbs_projer_app/data/local/event_aufwand_local_export.dart';
import 'package:sbs_projer_app/data/models/event_aufwand.dart';

class EventAufwandMapper {
  static EventAufwandLocal fromDto(EventAufwand dto, {EventAufwandLocal? existing}) {
    final local = existing ?? EventAufwandLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.datum = dto.datum;
    local.kategorie = dto.kategorie;
    local.notiz = dto.notiz;
    local.stunden = dto.stunden;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventAufwandLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'datum': local.datum.toIso8601String().substring(0, 10),
      'kategorie': local.kategorie,
      'notiz': local.notiz,
      'stunden': local.stunden,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
