import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/models/event_stand.dart';

class EventStandMapper {
  static EventStandLocal fromDto(EventStand dto, {EventStandLocal? existing}) {
    final local = existing ?? EventStandLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.name = dto.name;
    local.standnummer = dto.standnummer;
    local.sortierung = dto.sortierung;
    local.notizen = dto.notizen;
    local.latitude = dto.latitude;
    local.longitude = dto.longitude;
    local.positionQuelle = dto.positionQuelle;
    local.positionErfasstAm = dto.positionErfasstAm;
    local.positionGenauigkeit = dto.positionGenauigkeit;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventStandLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'name': local.name,
      'standnummer': local.standnummer,
      'sortierung': local.sortierung,
      'notizen': local.notizen,
      'latitude': local.latitude,
      'longitude': local.longitude,
      'position_quelle': local.positionQuelle,
      'position_erfasst_am': local.positionErfasstAm?.toIso8601String(),
      'position_genauigkeit': local.positionGenauigkeit,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
