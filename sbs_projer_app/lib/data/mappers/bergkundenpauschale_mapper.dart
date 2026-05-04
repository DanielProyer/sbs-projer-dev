import 'package:sbs_projer_app/data/local/bergkundenpauschale_local_export.dart';
import 'package:sbs_projer_app/data/models/bergkundenpauschale.dart';

class BergkundenpauschaleMapper {
  static BergkundenpauschaleLocal fromDto(Bergkundenpauschale dto,
      {BergkundenpauschaleLocal? existing}) {
    final local = existing ?? BergkundenpauschaleLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.reinigungId = dto.reinigungId;
    local.datum = dto.datum;
    local.betrag = dto.betrag;
    local.notizen = dto.notizen;
    local.abgerechnet = dto.abgerechnet;
    local.abrechnungsMonat = dto.abrechnungsMonat;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(BergkundenpauschaleLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'reinigung_id': local.reinigungId,
      'datum': local.datum.toIso8601String().split('T').first,
      'betrag': local.betrag,
      'notizen': local.notizen,
      'abgerechnet': local.abgerechnet,
      'abrechnungs_monat':
          local.abrechnungsMonat?.toIso8601String().split('T').first,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
