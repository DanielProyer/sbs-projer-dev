import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'package:sbs_projer_app/core/util/stand_position.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_anlage_local_export.dart';
import 'package:sbs_projer_app/data/models/event_stand.dart';
import 'package:sbs_projer_app/data/mappers/event_stand_mapper.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_anlage_repository.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class EventStandRepository {
  static String get _userId => SupabaseService.dataUserId;

  static Future<List<EventStandLocal>> getByEvent(String eventId) async {
    if (kIsWeb) {
      final rows = await SupabaseService.client
          .from('event_staende').select()
          .eq('user_id', _userId)
          .eq('event_id', eventId)
          .order('sortierung')
          .order('name');
      return rows
          .map((r) => EventStandMapper.fromDto(EventStand.fromJson(r)))
          .toList();
    }
    return IsarService.eventStandFindByEvent(eventId);
  }

  static Future<void> save(EventStandLocal stand) async {
    stand.userId = _userId;
    stand.serverId ??= const Uuid().v4();
    if (kIsWeb) {
      final json = EventStandMapper.toJson(stand);
      await SupabaseService.client.from('event_staende').upsert(json);
      return;
    }
    stand.isSynced = false;
    stand.lastModifiedAt = DateTime.now().toUtc();
    await IsarService.eventStandPut(stand);
  }

  static Future<void> delete(String id) async {
    if (kIsWeb) {
      // Anlagen räumt DB-CASCADE ab.
      await SupabaseService.client.from('event_staende').delete().eq('id', id);
      return;
    }
    // Native: zuerst serverseitig löschen (CASCADE räumt Anlagen ab),
    // dann Isar aufräumen — Anlagen lokal separat entfernen.
    final isarId = int.parse(id);
    final local = await IsarService.eventStandGet(isarId);
    if (local?.serverId != null) {
      final anlagen =
          await EventStandAnlageRepository.getByStand(local!.serverId!);
      for (final a in anlagen) {
        await EventStandAnlageRepository.delete(a.routeId);
      }
      await SupabaseService.client
          .from('event_staende').delete().eq('id', local.serverId!);
    }
    await IsarService.eventStandDelete(isarId);
  }

  /// Stände aus [quelle], deren name (case-insensitive, getrimmt) in [ziel] fehlt.
  static List<EventStandLocal> fehlendeStaende(
      List<EventStandLocal> quelle, List<EventStandLocal> ziel) {
    String norm(String s) => s.trim().toLowerCase();
    final vorhanden = ziel.map((z) => norm(z.name)).toSet();
    return quelle.where((q) => !vorhanden.contains(norm(q.name))).toList();
  }

  /// Übernimmt Stände (inkl. Anlagen) aus dem Vorjahres-Event [vonEventId]
  /// in [zuEventId]. Rückgabe: Anzahl übernommener Stände.
  ///
  /// Die **Position wandert mit** (Entscheid Daniel 11.08.2026: der gemessene
  /// Standort gilt und ist im Folgejahr die Vorlage), zählt dort aber wieder
  /// als *geplant* — gemessen ist sie im neuen Jahr ja nicht. So kommt beim
  /// «Standort erfassen» vor Ort die Rückfrage mit dem Abstand, und eine
  /// Standverschiebung fällt sofort auf.
  ///
  /// **Nicht** übernommen wird der Inbetriebnahme-Status: `inBetrieb` ist
  /// jahresspezifisch — vorher kopierte ihn diese Methode mit, wodurch ein
  /// frisch angelegtes Event-Jahr sofort als vollständig in Betrieb galt.
  static Future<int> uebernehmeVon(String vonEventId, String zuEventId) async {
    final quelle = await getByEvent(vonEventId);
    final ziel = await getByEvent(zuEventId);
    final neu = fehlendeStaende(quelle, ziel);
    for (final q in neu) {
      final hatPosition = q.latitude != null && q.longitude != null;
      final s = EventStandLocal()
        ..eventId = zuEventId
        ..name = q.name
        ..standnummer = q.standnummer
        ..sortierung = q.sortierung
        ..notizen = q.notizen
        ..latitude = q.latitude
        ..longitude = q.longitude
        ..positionQuelle = hatPosition ? quelleKarte : null
        ..positionErfasstAm = hatPosition ? DateTime.now() : null;
      await save(s);
      // Anlagen des Quell-Stands kopieren — ohne Inbetriebnahme-Status.
      final quellAnlagen =
          await EventStandAnlageRepository.getByStand(q.serverId!);
      for (final qa in quellAnlagen) {
        final a = EventStandAnlageLocal()
          ..standId = s.serverId!
          ..typ = qa.typ
          ..anzahl = qa.anzahl
          ..sortierung = qa.sortierung
          ..inBetrieb = false
          ..inBetriebAm = null;
        await EventStandAnlageRepository.save(a);
      }
    }
    return neu.length;
  }
}
