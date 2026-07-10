import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_dokument_local.g.dart';

@collection
class EventDokumentLocal {
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
  late String bezeichnung;
  late String dateiPfad;
  DateTime? createdAt;
  DateTime? updatedAt;
}
