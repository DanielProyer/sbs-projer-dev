import 'dart:convert';

import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';

class EventGeraetMapper {
  static EventGeraetLocal fromDto(EventGeraet dto, {EventGeraetLocal? existing}) {
    final local = existing ?? EventGeraetLocal();
    local.serverId = dto.id;
    local.userId = dto.userId;
    local.eventId = dto.eventId;
    local.typ = dto.typ;
    local.bezeichnung = dto.bezeichnung;
    local.anzahlTanks = dto.anzahlTanks;
    local.standortNotiz = dto.standortNotiz;
    local.latitude = dto.latitude;
    local.longitude = dto.longitude;
    local.positionQuelle = dto.positionQuelle;
    local.positionGenauigkeit = dto.positionGenauigkeit;
    local.inBetrieb = dto.inBetrieb;
    local.inBetriebAm = dto.inBetriebAm;
    local.sortierung = dto.sortierung;
    local.notizen = dto.notizen;
    local.kuehlerTyp = dto.kuehlerTyp;
    local.pumpeTyp = dto.pumpeTyp;
    local.typenschildKuehlerPfad = dto.typenschildKuehlerPfad;
    local.typenschildPumpePfad = dto.typenschildPumpePfad;
    local.typenschildErkennungJson = dto.typenschildErkennung == null
        ? null
        : jsonEncode(dto.typenschildErkennung);
    local.sollMinCelsius = dto.sollMinCelsius;
    local.sollMaxCelsius = dto.sollMaxCelsius;
    local.createdAt = dto.createdAt;
    local.updatedAt = dto.updatedAt;
    local.isSynced = true;
    local.lastModifiedAt = dto.updatedAt ?? dto.createdAt ?? DateTime.now();
    return local;
  }

  static Map<String, dynamic> toJson(EventGeraetLocal local) {
    final json = <String, dynamic>{
      'user_id': local.userId,
      'event_id': local.eventId,
      'typ': local.typ,
      'bezeichnung': local.bezeichnung,
      'anzahl_tanks': local.anzahlTanks,
      'standort_notiz': local.standortNotiz,
      'latitude': local.latitude,
      'longitude': local.longitude,
      'position_quelle': local.positionQuelle,
      'position_genauigkeit': local.positionGenauigkeit,
      'in_betrieb': local.inBetrieb,
      // Isar liest DateTime in Lokalzeit zurück — ohne toUtc() ginge der Zeitstempel beim Re-Push ohne «Z» raus und Postgres läse ihn als UTC (2 h Versatz).
      'in_betrieb_am': local.inBetriebAm?.toUtc().toIso8601String(),
      'sortierung': local.sortierung,
      'notizen': local.notizen,
      'kuehler_typ': local.kuehlerTyp,
      'pumpe_typ': local.pumpeTyp,
      'typenschild_kuehler_pfad': local.typenschildKuehlerPfad,
      'typenschild_pumpe_pfad': local.typenschildPumpePfad,
      'typenschild_erkennung': _erkennungDecode(local.typenschildErkennungJson),
      'soll_min_celsius': local.sollMinCelsius,
      'soll_max_celsius': local.sollMaxCelsius,
    };
    if (local.serverId != null) json['id'] = local.serverId;
    return json;
  }

  /// Defekter Alt-Inhalt darf das Speichern nie verhindern — ein
  /// unlesbares JSON würde sonst jeden Push des Geräts mit einer
  /// FormatException abbrechen.
  static dynamic _erkennungDecode(String? json) {
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }
}
