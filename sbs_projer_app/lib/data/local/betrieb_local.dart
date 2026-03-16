import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'betrieb_local.g.dart';

@collection
class BetriebLocal {
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
  late String name;
  String? strasse;
  String? nr;
  String? plz;
  String? ort;
  String? telefon;
  String? regionId;
  String? email;
  String? website;
  String? zugangNotizen;
  String? betriebNr;
  String status = 'aktiv';
  bool istMeinKunde = true;
  bool istBergkunde = false;
  bool istSaisonbetrieb = false;
  bool winterSaisonAktiv = false;
  DateTime? winterStartDatum;
  DateTime? winterEndeDatum;
  bool sommerSaisonAktiv = false;
  DateTime? sommerStartDatum;
  DateTime? sommerEndeDatum;
  List<String> ruhetage = [];
  List<String> zapfsysteme = [];
  String rechnungsstellung = 'rechnung_mail';
  double? latitude;
  double? longitude;
  DateTime? ferienStart;
  DateTime? ferienEnde;
  DateTime? ferien2Start;
  DateTime? ferien2Ende;
  DateTime? ferien3Start;
  DateTime? ferien3Ende;
  bool keineBetriebsferien = false;
  String? oeffnungMorgenVon;
  String? oeffnungMorgenBis;
  String? oeffnungNachmittagVon;
  String? oeffnungNachmittagBis;
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
