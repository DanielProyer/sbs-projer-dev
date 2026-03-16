import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

part 'anlage_local.g.dart';

@collection
class AnlageLocal {
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
  String? bezeichnung;
  String? seriennummer;
  late String typAnlage; // Warmanstich, Kaltanstich, Buffetanstich, Orion
  String? typSaeule;
  int anzahlHaehne = 1;
  bool backpython = false;
  bool booster = false;
  String vorkuehler = 'keiner';
  String? durchlaufkuehler;
  DateTime? letzterWasserwechsel;
  String? gasTyp1;
  String? gasTyp2;
  double? hauptdruckBar;
  bool hatNiederdruck = false;
  String? servicezeitMorgenAb;
  String? servicezeitMorgenBis;
  String? servicezeitNachmittagAb;
  String? servicezeitNachmittagBis;
  String reinigungRhythmus = '4-Wochen';
  DateTime? letzteReinigung;
  DateTime? naechsteReinigung;
  String status = 'aktiv';
  String? notizen;
  DateTime? createdAt;
  DateTime? updatedAt;
}
