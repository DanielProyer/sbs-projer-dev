import 'package:sbs_projer_app/data/local/event_dokument_local_export.dart';
import 'package:sbs_projer_app/data/models/event_dokument.dart';

class EventDokumentMapper {
  static EventDokumentLocal fromDto(EventDokument dto, {EventDokumentLocal? existing}) {
    final local = existing ?? EventDokumentLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.bezeichnung = dto.bezeichnung;
    local.dateiPfad = dto.dateiPfad;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventDokumentLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'bezeichnung': local.bezeichnung,
      'datei_pfad': local.dateiPfad,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
