import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_einsatz_local.g.dart';

@collection
class EventEinsatzLocal {
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
  String? standId;
  late DateTime zeitpunkt;
  late String beschreibung;
  String? material;
  DateTime? createdAt;
  DateTime? updatedAt;
}
