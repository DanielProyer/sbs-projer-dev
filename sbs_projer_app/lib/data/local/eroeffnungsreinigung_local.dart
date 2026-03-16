import 'package:isar/isar.dart';

part 'eroeffnungsreinigung_local.g.dart';

@collection
class EroeffnungsreinigungLocal {
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
  String? betriebId;
  String stoerungsnummer = '';
  DateTime datum = DateTime.now();
  bool istBergkunde = false;
  double? preis;
  DateTime? abrechnungsMonat;
  bool abgerechnet = false;
  DateTime? createdAt;
  DateTime? updatedAt;
}
