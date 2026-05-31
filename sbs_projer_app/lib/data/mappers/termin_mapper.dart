import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';

class TerminMapper {
  static TerminLocal fromDto(Termin dto, {TerminLocal? existing}) {
    final local = existing ?? TerminLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.betriebId = dto.betriebId;
    local.datum = dto.datum;
    local.uhrzeitVon = dto.uhrzeitVon;
    local.uhrzeitBis = dto.uhrzeitBis;
    local.typ = dto.typ;
    local.anlass = dto.anlass;
    local.titel = dto.titel;
    local.notizen = dto.notizen;
    local.status = dto.status;
    local.erinnerungTage = dto.erinnerungTage;
    local.erinnerungAktiv = dto.erinnerungAktiv;
    local.erinnerungVorlaufMinuten = dto.erinnerungVorlaufMinuten;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(TerminLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'betrieb_id': local.betriebId,
      'datum': local.datum.toIso8601String().split('T').first,
      'uhrzeit_von': local.uhrzeitVon,
      'uhrzeit_bis': local.uhrzeitBis,
      'typ': local.typ,
      'anlass': local.anlass,
      'titel': local.titel,
      'notizen': local.notizen,
      'status': local.status,
      'erinnerung_tage': local.erinnerungTage,
      'erinnerung_aktiv': local.erinnerungAktiv,
      'erinnerung_vorlauf_minuten': local.erinnerungVorlaufMinuten,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
