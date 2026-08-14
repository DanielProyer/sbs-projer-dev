import 'package:sbs_projer_app/data/local/event_kuehler_messung_local_export.dart';
import 'package:sbs_projer_app/data/models/event_kuehler_messung.dart';

class EventKuehlerMessungMapper {
  static EventKuehlerMessungLocal fromDto(
    EventKuehlerMessung dto, {
    EventKuehlerMessungLocal? existing,
  }) {
    final local = existing ?? EventKuehlerMessungLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.geraetId = dto.geraetId;
    local.gemessenAm = dto.gemessenAm;
    local.temperatur = dto.temperatur;
    local.notiz = dto.notiz;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventKuehlerMessungLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'geraet_id': local.geraetId,
      // Isar liest DateTime in Lokalzeit zurück — ohne toUtc() ginge der Zeitstempel beim Re-Push ohne «Z» raus und Postgres läse ihn als UTC (2 h Versatz).
      'gemessen_am': local.gemessenAm.toUtc().toIso8601String(),
      'temperatur': local.temperatur,
      'notiz': local.notiz,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
