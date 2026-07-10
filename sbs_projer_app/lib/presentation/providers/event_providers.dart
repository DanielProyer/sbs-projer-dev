import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/local/event_dokument_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_anlage_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_anlage_repository.dart';

/// Alle Event-Jahre des Users.
final eventsProvider = FutureProvider<List<EventLocal>>((ref) async {
  return EventRepository.getAll();
});

/// Ein Event-Jahr per routeId.
final eventByIdProvider =
    FutureProvider.family<EventLocal?, String>((ref, id) async {
  return EventRepository.getById(id);
});

/// Kontakt-Zuordnungen eines Event-Jahres.
final eventKontakteProvider =
    FutureProvider.family<List<EventKontaktLocal>, String>((ref, eventId) async {
  return EventKontaktRepository.getByEvent(eventId);
});

/// Dokumente eines Event-Jahres.
final eventDokumenteProvider =
    FutureProvider.family<List<EventDokumentLocal>, String>((ref, eventId) async {
  return EventDokumentRepository.getByEvent(eventId);
});

/// Stände eines Event-Jahres.
final eventStaendeProvider =
    FutureProvider.family<List<EventStandLocal>, String>((ref, eventId) async {
  return EventStandRepository.getByEvent(eventId);
});

/// Anlagen eines Stands.
final eventStandAnlagenProvider =
    FutureProvider.family<List<EventStandAnlageLocal>, String>((ref, standId) async {
  return EventStandAnlageRepository.getByStand(standId);
});
