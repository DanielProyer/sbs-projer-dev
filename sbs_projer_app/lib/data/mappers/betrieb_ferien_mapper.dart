import 'package:sbs_projer_app/data/local/betrieb_ferien_local_export.dart';
import 'package:sbs_projer_app/data/models/betrieb_ferien.dart';

class BetriebFerienMapper {
  static BetriebFerienLocal fromDto(
    BetriebFerienDto dto, {
    BetriebFerienLocal? existing,
  }) {
    final local = existing ?? BetriebFerienLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.von = dto.von;
    local.bis = dto.bis;
    local.quelle = dto.quelle;
    local.bestaetigtAm = dto.bestaetigtAm;
    local.notiz = dto.notiz;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(BetriebFerienLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'von': local.von.toIso8601String().split('T').first,
      'bis': local.bis.toIso8601String().split('T').first,
      'quelle': local.quelle,
      'bestaetigt_am': local.bestaetigtAm?.toIso8601String(),
      'notiz': local.notiz,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
