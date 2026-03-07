import 'package:isar/isar.dart';

part 'sync_meta_local.g.dart';

@collection
class SyncMetaLocal {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String entityName;

  DateTime? lastPullAt;
  DateTime? lastPushAt;
  bool isInitialSyncDone = false;
}
