import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_kontakt_local.g.dart';

@collection
class EventKontaktLocal {
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
  late String kontaktId;
  late String rolle;
  String? bemerkung;
  DateTime? createdAt;
  DateTime? updatedAt;
}
