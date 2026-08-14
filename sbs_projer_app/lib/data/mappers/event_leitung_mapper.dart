import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/models/event_leitung.dart';

class EventLeitungMapper {
  static EventLeitungLocal fromDto(EventLeitung dto, {EventLeitungLocal? existing}) {
    final local = existing ?? EventLeitungLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.nummer = dto.nummer;
    local.quelleId = dto.quelleId;
    local.kuehlerId = dto.kuehlerId;
    local.standId = dto.standId;
    local.standAnlageId = dto.standAnlageId;
    local.inBetrieb = dto.inBetrieb;
    local.inBetriebAm = dto.inBetriebAm;
    local.sortierung = dto.sortierung;
    local.notiz = dto.notiz;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventLeitungLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'nummer': local.nummer,
      'quelle_id': local.quelleId,
      'kuehler_id': local.kuehlerId,
      'stand_id': local.standId,
      'stand_anlage_id': local.standAnlageId,
      'in_betrieb': local.inBetrieb,
      'in_betrieb_am': local.inBetriebAm?.toIso8601String(),
      'sortierung': local.sortierung,
      'notiz': local.notiz,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
