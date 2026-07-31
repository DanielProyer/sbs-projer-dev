import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ein noch nicht ausgewertetes Diktat — Rohtext, wie ihn Daniel
/// eingesprochen hat, plus Zeitpunkt der Erfassung.
class EinsatzDiktatEntwurf {
  final String id;
  final String text;
  final DateTime erfasstAm;

  const EinsatzDiktatEntwurf({
    required this.id,
    required this.text,
    required this.erfasstAm,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'erfasst_am': erfasstAm.toIso8601String(),
  };

  factory EinsatzDiktatEntwurf.fromJson(Map<String, dynamic> json) =>
      EinsatzDiktatEntwurf(
        id: json['id'] as String,
        text: json['text'] as String,
        erfasstAm:
            DateTime.tryParse(json['erfasst_am'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Lokale Ablage für Diktate, deren Auswertung (Edge-Function
/// `parse-einsatz`) fehlgeschlagen ist — typischerweise, weil Daniel gerade
/// in einem Funkloch unterwegs ist. Das ist der Kern der ganzen Diktier-
/// Funktion: **das Diktat darf unter keinen Umständen verloren gehen**, egal
/// wie unzuverlässig die Verbindung gerade ist.
///
/// `shared_preferences` statt Isar: Der Rohtext ist reines Übergangsmaterial
/// (wird nach erfolgreicher Auswertung sofort wieder gelöscht), keine
/// dauerhafte fachliche Entität — dafür lohnt sich kein eigenes
/// Isar-Collection/Sync-Gerüst.
///
/// Jeder Eintrag steht als eigener JSON-String in der Liste — ein defektes
/// Einzelelement (z.B. durch eine abgebrochene Schreiboperation) reisst
/// dadurch nicht die ganze Warteschlange mit sich (siehe [laden]).
class EinsatzDiktatEntwurfSpeicher {
  static const _key = 'einsatz_diktat_entwuerfe';

  /// Alle wartenden Entwürfe, älteste zuerst. Ein einzelner kaputter Eintrag
  /// wird übersprungen statt die ganze Liste zu verwerfen.
  static Future<List<EinsatzDiktatEntwurf>> laden() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final entwuerfe = <EinsatzDiktatEntwurf>[];
    for (final s in raw) {
      try {
        entwuerfe.add(
          EinsatzDiktatEntwurf.fromJson(jsonDecode(s) as Map<String, dynamic>),
        );
      } catch (_) {
        // Einzelner kaputter Eintrag — überspringen, nicht die ganze
        // Warteschlange verlieren.
      }
    }
    entwuerfe.sort((a, b) => a.erfasstAm.compareTo(b.erfasstAm));
    return entwuerfe;
  }

  /// Legt [text] als neuen Entwurf ab. Wird aufgerufen, sobald die
  /// Auswertung fehlschlägt — bevor irgendetwas anderes passiert.
  static Future<EinsatzDiktatEntwurf> hinzufuegen(String text) async {
    final entwurf = EinsatzDiktatEntwurf(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      text: text,
      erfasstAm: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [...raw, jsonEncode(entwurf.toJson())]);
    return entwurf;
  }

  /// Entfernt einen Entwurf (nach erfolgreicher Auswertung oder wenn Daniel
  /// ihn bewusst verwirft).
  static Future<void> entfernen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final rest = raw.where((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['id'] != id;
      } catch (_) {
        // Kaputter Eintrag: gleich mit aufräumen.
        return false;
      }
    }).toList();
    await prefs.setStringList(_key, rest);
  }
}
