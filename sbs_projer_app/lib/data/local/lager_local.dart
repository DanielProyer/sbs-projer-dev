import 'package:isar/isar.dart';

part 'lager_local.g.dart';

@collection
class LagerLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  String? kategorieId;
  String? materialId;
  String? dboNr;
  late String name;
  String? beschreibung;
  String einheit = 'Stück';
  double bestandAktuell = 0;
  double bestandMindest = 5;
  double bestandOptimal = 10;
  String? lieferant;
  String? lieferantenArtikelNr;
  double? preisEinkauf;
  bool istAktiv = true;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
