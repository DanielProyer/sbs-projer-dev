import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/eroeffnungsreinigung.dart';

class EroeffnungsreinigungMapper {
  static EroeffnungsreinigungLocal fromDto(Eroeffnungsreinigung dto, {EroeffnungsreinigungLocal? existing}) {
    final local = existing ?? EroeffnungsreinigungLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.stoerungsnummer = dto.stoerungsnummer;
    local.datum = dto.datum;
    local.istBergkunde = dto.istBergkunde;
    local.preis = dto.preis;
    local.abrechnungsMonat = dto.abrechnungsMonat;
    local.abgerechnet = dto.abgerechnet;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EroeffnungsreinigungLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'stoerungsnummer': local.stoerungsnummer,
      'datum': local.datum.toIso8601String().split('T').first,
      'ist_bergkunde': local.istBergkunde,
      'preis': local.preis,
      'abrechnungs_monat': local.abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': local.abgerechnet,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
