import 'package:isar/isar.dart';

part 'betrieb_kontakt_local.g.dart';

@collection
class BetriebKontaktLocal {
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
  late String vorname;
  String? nachname;
  String? funktion;
  String? telefon;
  String? email;
  String? telefonNormalized;
  String? phoneContactId;
  String kontaktMethode = 'telefon';
  bool istHauptkontakt = false;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
