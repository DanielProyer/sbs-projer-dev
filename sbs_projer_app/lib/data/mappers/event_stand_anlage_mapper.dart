import 'package:sbs_projer_app/data/local/event_stand_anlage_local_export.dart';
import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';

class EventStandAnlageMapper {
  static EventStandAnlageLocal fromDto(EventStandAnlage dto, {EventStandAnlageLocal? existing}) {
    final local = existing ?? EventStandAnlageLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.standId = dto.standId;
    local.typ = dto.typ;
    local.anzahl = dto.anzahl;
    local.sortierung = dto.sortierung;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventStandAnlageLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'stand_id': local.standId,
      'typ': local.typ,
      'anzahl': local.anzahl,
      'sortierung': local.sortierung,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
