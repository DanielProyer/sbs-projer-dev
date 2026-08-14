import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/local/event_dokument_local_export.dart';
import 'package:sbs_projer_app/data/local/event_einsatz_local_export.dart';
import 'package:sbs_projer_app/data/local/event_aufwand_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_einsatz_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_aufwand_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_geraet_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_leitung_repository.dart';

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

/// Einsätze eines Event-Jahres (neueste zuerst).
final eventEinsaetzeProvider =
    FutureProvider.family<List<EventEinsatzLocal>, String>((ref, eventId) async {
  final list = await EventEinsatzRepository.getByEvent(eventId);
  list.sort((a, b) => b.zeitpunkt.compareTo(a.zeitpunkt)); // neueste zuerst
  return list;
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

/// Zeit-/Spesen-Zeilen eines Event-Jahres (nach Datum aufsteigend).
final eventAufwaendeProvider =
    FutureProvider.family<List<EventAufwandLocal>, String>((ref, eventId) async {
  final list = await EventAufwandRepository.getByEvent(eventId);
  list.sort((a, b) => a.datum.compareTo(b.datum));
  return list;
});

/// Technik-Geräte eines Event-Jahres (Anstiche + Durchlaufkühler).
final eventGeraeteProvider =
    FutureProvider.family<List<EventGeraetLocal>, String>((ref, eventId) async {
  return EventGeraetRepository.getByEvent(eventId);
});

/// Leitungen eines Event-Jahres.
final eventLeitungenProvider =
    FutureProvider.family<List<EventLeitungLocal>, String>((ref, eventId) async {
  return EventLeitungRepository.getByEvent(eventId);
});
