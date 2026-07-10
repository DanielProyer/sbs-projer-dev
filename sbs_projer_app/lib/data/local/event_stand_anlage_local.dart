import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_stand_anlage_local.g.dart';

@collection
class EventStandAnlageLocal {
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
  late String standId;
  late String typ;
  int anzahl = 1;
  int sortierung = 0;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  DateTime? createdAt;
  DateTime? updatedAt;
}
