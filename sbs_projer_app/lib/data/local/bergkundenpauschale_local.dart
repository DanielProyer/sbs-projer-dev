import 'package:isar/isar.dart';

part 'bergkundenpauschale_local.g.dart';

@collection
class BergkundenpauschaleLocal {
  Id id = Isar.autoIncrement;

  String get routeId => id.toString();

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  String userId = '';
  @Index()
  String betriebId = '';
  String? reinigungId;
  @Index()
  DateTime datum = DateTime.now();
  double betrag = 180.0;
  String? notizen;
  bool abgerechnet = false;
  DateTime? abrechnungsMonat;
  DateTime? createdAt;
  DateTime? updatedAt;
}
