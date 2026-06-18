// lib/services/buchhaltung/geschaeft_mapping.dart
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

class GeschaeftMapping {
  /// Arbeitgeber-Felder für den Lohnausweis aus dem Geschäft.
  static ({String name, String adresse, String plzOrt}) arbeitgeber(GeschaeftEinstellungen g) =>
      (name: g.firma, adresse: g.adresseStrasse, plzOrt: g.adressePlzOrt);

  /// Vollständiger Arbeitnehmer-Snapshot aus dem Geschäft (GF = einziger AN).
  static ({
    String? name,
    String? vorname,
    String? adresse,
    String? plzOrt,
    String? ahvNr,
    DateTime? geburtsdatum,
    int geburtsjahr,
  }) arbeitnehmer(GeschaeftEinstellungen g) => (
        name: g.gfName,
        vorname: g.gfVorname,
        adresse: g.adresseStrasse,
        plzOrt: g.adressePlzOrt,
        ahvNr: g.gfAhvNr,
        geburtsdatum: g.gfGeburtsdatum,
        geburtsjahr: g.gfGeburtsjahr,
      );
}
