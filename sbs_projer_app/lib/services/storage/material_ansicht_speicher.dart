import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MaterialAnsicht { liste, karten }

/// Ansicht und letzte Kategorie des Material-Screens — nur in diesem Browser.
/// Lesen/Schreiben im try/catch (privater Modus, voller Speicher): der Screen
/// darf an den Prefs nie scheitern.
class MaterialAnsichtSpeicher {
  static const schluesselAnsicht = 'material_ansicht'; // 'liste' | 'karten'
  static const schluesselKategorie =
      'material_kategorie'; // Kategorie-ID oder 'ohne'

  static Future<({MaterialAnsicht ansicht, String? kategorieId})>
  lade() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[MaterialAnsicht] Prefs nicht erreichbar: $e');
      return (ansicht: MaterialAnsicht.liste, kategorieId: null);
    }
    // Jeder Wert einzeln abgesichert: Ein unlesbarer Eintrag soll nicht
    // auch den anderen, intakten mitreissen.
    var ansicht = MaterialAnsicht.liste;
    try {
      final roh = prefs.getString(schluesselAnsicht);
      ansicht = MaterialAnsicht.values.firstWhere(
        (a) => a.name == roh,
        orElse: () => MaterialAnsicht.liste,
      );
    } catch (_) {}
    String? kategorieId;
    try {
      kategorieId = prefs.getString(schluesselKategorie);
    } catch (_) {}
    return (ansicht: ansicht, kategorieId: kategorieId);
  }

  static Future<void> speichereAnsicht(MaterialAnsicht a) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(schluesselAnsicht, a.name);
    } catch (e) {
      debugPrint('[MaterialAnsicht] Ansicht nicht gespeichert: $e');
    }
  }

  /// null → Schlüssel entfernen (= «Alle»).
  static Future<void> speichereKategorie(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(schluesselKategorie);
      } else {
        await prefs.setString(schluesselKategorie, id);
      }
    } catch (e) {
      debugPrint('[MaterialAnsicht] Kategorie nicht gespeichert: $e');
    }
  }
}
