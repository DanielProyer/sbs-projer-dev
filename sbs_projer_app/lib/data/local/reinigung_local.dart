import 'package:isar/isar.dart';

part 'reinigung_local.g.dart';

@collection
class ReinigungLocal {
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
  late String betriebId;
  late DateTime datum;
  String? uhrzeitStart;
  String? uhrzeitEnde;

  // Checkliste (17 Punkte)
  bool hatDurchlaufkuehler = false;
  bool hatBuffetanstich = false;
  bool hatKuehlkeller = false;
  bool hatFasskuehler = false;
  bool begleitkuehlungKontrolliert = false;
  bool installationAllgemeinKontrolliert = false;
  bool aligalAnschluesseKontrolliert = false;
  bool durchlaufkuehlerAusgeblasen = false;
  bool wasserstandKontrolliert = false;
  bool wasserGewechselt = false;
  bool leitungWasserVorgespuelt = false;
  bool leitungsreinigungReinigungsmittel = false;
  bool foerderdruckKontrolliert = false;
  bool zapfhahnZerlegtGereinigt = false;
  bool zapfkopfZerlegtGereinigt = false;
  bool servicekarteAusgefuellt = false;

  // Unterschriften (Base64)
  String? unterschriftTechniker;
  String? unterschriftKunde;
  String? unterschriftKundeName;

  String? notizen;

  // Preis
  String? serviceTyp;
  int anzahlHaehneEigen = 0;
  int anzahlHaehneOrion = 0;
  int anzahlHaehneFremd = 0;
  int anzahlHaehneWein = 0;
  int anzahlHaehneAndererStandort = 0;
  bool istBergkunde = false;
  double? preisGrundtarif;
  double? preisZusatzHaehne;
  double? bergkundenZuschlag;
  double? preisNetto;
  double? mwstSatz;
  double? preisMwst;
  double? preisBrutto;

  String status = 'offen';
  DateTime? createdAt;
  DateTime? updatedAt;
}
