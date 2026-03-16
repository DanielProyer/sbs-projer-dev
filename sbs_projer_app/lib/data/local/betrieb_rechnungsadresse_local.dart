import 'package:isar/isar.dart';

part 'betrieb_rechnungsadresse_local.g.dart';

@collection
class BetriebRechnungsadresseLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  late String betriebId;
  String? firma;
  String? vorname;
  late String nachname;
  late String strasse;
  String? nr;
  late String plz;
  late String ort;
  String? email;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
