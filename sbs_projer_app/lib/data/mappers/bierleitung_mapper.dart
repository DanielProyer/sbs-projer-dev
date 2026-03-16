import 'package:sbs_projer_app/data/local/bierleitung_local_export.dart';
import 'package:sbs_projer_app/data/models/bierleitung.dart';

class BierleitungMapper {
  static BierleitungLocal fromDto(Bierleitung dto, {BierleitungLocal? existing}) {
    final local = existing ?? BierleitungLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.anlageId = dto.anlageId;
    local.leitungsNummer = dto.leitungsNummer;
    local.biersorte = dto.biersorte;
    local.hahnTyp = dto.hahnTyp;
    local.niederdruckBar = dto.niederdruckBar;
    local.hatFobStop = dto.hatFobStop;
    local.isSynced = true;
    local.lastModifiedAt = DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(BierleitungLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'anlage_id': local.anlageId,
      'leitungs_nummer': local.leitungsNummer,
      'biersorte': local.biersorte,
      'hahn_typ': local.hahnTyp,
      'niederdruck_bar': local.niederdruckBar,
      'hat_fob_stop': local.hatFobStop,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
