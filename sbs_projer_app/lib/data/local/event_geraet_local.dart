import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_geraet_local.g.dart';

@collection
class EventGeraetLocal {
  Id id = Isar.autoIncrement;

  @ignore
  String get routeId => kIsWeb ? serverId! : id.toString();

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  @Index()
  late String eventId;
  late String typ;
  late String bezeichnung;
  int? anzahlTanks;
  String? standortNotiz;
  double? latitude;
  double? longitude;
  String? positionQuelle;
  String? positionGenauigkeit;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
