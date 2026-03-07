import 'package:isar/isar.dart';

part 'pikett_dienst_local.g.dart';

@collection
class PikettDienstLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  late DateTime datumStart;
  late DateTime datumEnde;
  String? referenzNr;
  bool istAktiv = false;

  // Preis
  String? preislisteId;
  double? pauschale;
  int anzahlFeiertage = 0;
  double? feiertagZuschlag;
  double? pauschaleGesamt;

  DateTime? abrechnungsMonat;
  bool abgerechnet = false;

  // Google Calendar
  String? googleCalendarEventId;
  String kalenderSyncStatus = 'pending';

  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
