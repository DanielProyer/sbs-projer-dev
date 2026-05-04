import 'package:isar/isar.dart';

part 'kontakt_local.g.dart';

@collection
class KontaktLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  String? betriebId;
  late String vorname;
  String? nachname;
  String? funktion;
  String kategorie = 'betrieb';
  String? rolle;
  String? telefon;
  String? email;
  String? telefonNormalized;
  String? phoneContactId;
  String kontaktMethode = 'telefon';
  bool istHauptkontakt = false;
  bool istDuAnrede = false;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
