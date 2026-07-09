import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';

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
