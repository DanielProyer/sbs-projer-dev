import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_aufwand_local.g.dart';

@collection
class EventAufwandLocal {
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
  late DateTime datum;
  late String kategorie;
  String? notiz;
  late double stunden;
  DateTime? createdAt;
  DateTime? updatedAt;
}
