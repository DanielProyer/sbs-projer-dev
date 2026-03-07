import 'package:isar/isar.dart';

part 'bierleitung_local.g.dart';

@collection
class BierleitungLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  late String anlageId;
  late int leitungsNummer;
  String? biersorte;
  String? hahnTyp;
  double? niederdruckBar;
  bool hatFobStop = false;
}
