import 'package:sbs_projer_app/data/local/event_einsatz_local_export.dart';
import 'package:sbs_projer_app/data/models/event_einsatz.dart';

class EventEinsatzMapper {
  static EventEinsatzLocal fromDto(EventEinsatz dto, {EventEinsatzLocal? existing}) {
    final local = existing ?? EventEinsatzLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.standId = dto.standId;
    local.zeitpunkt = dto.zeitpunkt;
    local.beschreibung = dto.beschreibung;
    local.material = dto.material;
    local.materialId = dto.materialId;
    local.materialMenge = dto.materialMenge;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventEinsatzLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'stand_id': local.standId,
      'zeitpunkt': local.zeitpunkt.toIso8601String(),
      'beschreibung': local.beschreibung,
      'material': local.material,
      'material_id': local.materialId,
      'material_menge': local.materialMenge,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
