import 'package:isar/isar.dart';

part 'betrieb_local.g.dart';

@collection
class BetriebLocal {
  Id id = Isar.autoIncrement;

  // Supabase Sync
  @Index()
  String? serverId;
  @Index()
  bool isSynced = false;
  DateTime? lastModifiedAt;

  // Felder
  late String userId;
  late String name;
  String? strasse;
  String? nr;
  String? plz;
  String? ort;
  String? regionId;
  String? email;
  String? website;
  String? zugangNotizen;
  String? heinekenNr;
  String status = 'aktiv';
  bool istMeinKunde = true;
  bool istBergkunde = false;
  bool istSaisonbetrieb = false;
  bool winterSaisonAktiv = false;
  int? winterStartMonat;
  int? winterEndeMonat;
  bool sommerSaisonAktiv = false;
  int? sommerStartMonat;
  int? sommerEndeMonat;
  List<String> ruhetage = [];
  String rechnungsstellung = 'rechnung_mail';
  double? latitude;
  double? longitude;
  DateTime? ferienStart;
  DateTime? ferienEnde;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
