import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'bierleitung_local.g.dart';

@collection
class BierleitungLocal {
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
  late String anlageId;
  late int leitungsNummer;
  String? biersorte;
  String? hahnTyp;
  double? niederdruckBar;
  bool hatFobStop = false;
}
