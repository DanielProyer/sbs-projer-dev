// lib/services/buchhaltung/geschaeft_mapping.dart
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';

/// Arbeitnehmer-Namens-/Adressfelder (für Prefill).
typedef AnFelder = ({String? name, String? vorname, String? adresse, String? plzOrt});

class GeschaeftMapping {
  /// Arbeitgeber-Felder für den Lohnausweis aus dem Geschäft.
  static ({String name, String adresse, String plzOrt}) arbeitgeber(GeschaeftEinstellungen g) =>
      (name: g.firma, adresse: g.adresseStrasse, plzOrt: g.adressePlzOrt);

  /// Vorbefüllung: leere Arbeitnehmer-Felder werden aus dem Geschäft gefüllt,
  /// bereits gesetzte bleiben unverändert.
  static AnFelder arbeitnehmerPrefill(AnFelder current, GeschaeftEinstellungen g) {
    String? pick(String? cur, String fallback) {
      if (cur != null && cur.trim().isNotEmpty) return cur;
      return fallback.trim().isEmpty ? null : fallback;
    }

    return (
      name: pick(current.name, g.gfName ?? ''),
      vorname: pick(current.vorname, g.gfVorname ?? ''),
      adresse: pick(current.adresse, g.adresseStrasse),
      plzOrt: pick(current.plzOrt, g.adressePlzOrt),
    );
  }
}
