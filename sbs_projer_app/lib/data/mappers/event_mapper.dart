import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/models/event.dart';

class EventMapper {
  static EventLocal fromDto(Event dto, {EventLocal? existing}) {
    final local = existing ?? EventLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.jahr = dto.jahr;
    local.terminVon = dto.terminVon;
    local.terminBis = dto.terminBis;
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'jahr': local.jahr,
      'termin_von': local.terminVon?.toIso8601String().split('T').first,
      'termin_bis': local.terminBis?.toIso8601String().split('T').first,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
