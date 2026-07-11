import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'termin_local.g.dart';

@collection
class TerminLocal {
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
  late String betriebId;
  late DateTime datum;
  String? uhrzeitVon;
  String? uhrzeitBis;
  String typ = 'sonstiges';
  String anlass = 'manuell';
  late String titel;
  String? notizen;
  String status = 'geplant';
  int erinnerungTage = 3;
  bool erinnerungAktiv = false;
  int erinnerungVorlaufMinuten = 1440;
  String erinnerungenJson = '[]';
  DateTime? createdAt;
  DateTime? updatedAt;
}
