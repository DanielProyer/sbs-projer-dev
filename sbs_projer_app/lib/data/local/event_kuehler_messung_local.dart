import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'event_kuehler_messung_local.g.dart';

@collection
class EventKuehlerMessungLocal {
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
  late String geraetId;
  late DateTime gemessenAm;
  late double temperatur;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
