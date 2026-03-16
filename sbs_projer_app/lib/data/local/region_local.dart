import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'region_local.g.dart';

@collection
class RegionLocal {
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
  late String name;
  DateTime? createdAt;
  DateTime? updatedAt;
}
