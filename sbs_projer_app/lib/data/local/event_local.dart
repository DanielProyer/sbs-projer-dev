import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_local.g.dart';

@collection
class EventLocal {
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
  late String betriebId;
  late int jahr;
  DateTime? terminVon;
  DateTime? terminBis;
  String? notizen;
  String? lageplanPfad;
  // JSON-String (Isar kann keine Maps) -- Web-Stub identisch.
  String? lageplanPunkteJson;
  DateTime? createdAt;
  DateTime? updatedAt;
}
