import 'package:sbs_projer_app/data/local/pikett_dienst_local.dart';
import 'package:sbs_projer_app/data/models/pikett_dienst.dart';

class PikettDienstMapper {
  static PikettDienstLocal fromDto(PikettDienst dto, {PikettDienstLocal? existing}) {
    final local = existing ?? PikettDienstLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.datumStart = dto.datumStart;
    local.datumEnde = dto.datumEnde;
    local.referenzNr = dto.referenzNr;
    local.istAktiv = dto.istAktiv;
    local.preislisteId = dto.preislisteId;
    local.pauschale = dto.pauschale;
    local.anzahlFeiertage = dto.anzahlFeiertage;
    local.feiertagZuschlag = dto.feiertagZuschlag;
    local.pauschaleGesamt = dto.pauschaleGesamt;
    local.abrechnungsMonat = dto.abrechnungsMonat;
    local.abgerechnet = dto.abgerechnet;
    local.googleCalendarEventId = dto.googleCalendarEventId;
    local.kalenderSyncStatus = dto.kalenderSyncStatus;
    // kalenderSyncFehler and kalenderSyncAt exist only in DTO, not in Local
    local.notizen = dto.notizen;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(PikettDienstLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'datum_start': local.datumStart.toIso8601String().split('T').first,
      'datum_ende': local.datumEnde.toIso8601String().split('T').first,
      'referenz_nr': local.referenzNr,
      'ist_aktiv': local.istAktiv,
      'preisliste_id': local.preislisteId,
      'pauschale': local.pauschale,
      'anzahl_feiertage': local.anzahlFeiertage,
      'feiertag_zuschlag': local.feiertagZuschlag,
      'pauschale_gesamt': local.pauschaleGesamt,
      'abrechnungs_monat': local.abrechnungsMonat?.toIso8601String().split('T').first,
      'abgerechnet': local.abgerechnet,
      'google_calendar_event_id': local.googleCalendarEventId,
      'kalender_sync_status': local.kalenderSyncStatus,
      'notizen': local.notizen,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }
}
