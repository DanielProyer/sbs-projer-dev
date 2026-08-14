import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_leitung_local.g.dart';

@collection
class EventLeitungLocal {
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
  late String nummer;
  @Index()
  late String quelleId;
  String? kuehlerId;
  String? standId;
  String? standAnlageId;
  bool inBetrieb = false;
  DateTime? inBetriebAm;
  int sortierung = 0;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
