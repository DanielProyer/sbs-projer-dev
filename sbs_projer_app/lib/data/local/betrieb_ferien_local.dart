import 'package:isar/isar.dart';

part 'betrieb_ferien_local.g.dart';

@collection
class BetriebFerienLocal {
  Id id = Isar.autoIncrement;

  @ignore
  String get routeId => id.toString();

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  @Index()
  late String betriebId;
  late DateTime von;
  late DateTime bis;
  String quelle = 'kunde';
  DateTime? bestaetigtAm;
  String? notiz;
  DateTime? createdAt;
  DateTime? updatedAt;
}
