import 'package:isar/isar.dart';

part 'region_local.g.dart';

@collection
class RegionLocal {
  Id id = Isar.autoIncrement;

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
