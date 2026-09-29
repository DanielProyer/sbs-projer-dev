import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sbs_projer_app/data/models/dokument_scan_ergebnis.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Erkennung, wie sie der Upload-Dialog aufruft — als Funktionstyp, damit
/// Widget-Tests einen Fake einspeisen können (kein Supabase nötig).
typedef DokumentErkenner =
    Future<DokumentScanErgebnis?> Function({
      required Uint8List bytes,
      required String mediaType,
      required String bereichVorgabe,
    });

/// Endung, die zum MIME-Typ passt (`pdf`, `png`, sonst `jpg`).
String dokumentEndung(String mime) => switch (mime) {
  'application/pdf' => 'pdf',
  'image/png' => 'png',
  _ => 'jpg',
};

/// Längster Dateiname (inklusive Endung), den der Upload speichert.
const kMaxDateinameLaenge = 150;

/// Dateiname für den Upload: die Eingabe aus dem Feld «Dateiname» (leer →
/// [original]) mit der Endung, die zum [mime] passt. Eine falsche bekannte
/// Endung wird ersetzt, eine fehlende ergänzt — sonst öffnet der Download ein
/// JPG als «.pdf».
///
/// Pfadteile und unter Windows verbotene Zeichen (`\ / : * ? " < > |`,
/// Steuerzeichen) werden zu `_`, `..` fällt weg: Der Name landet im
/// Download und — bereinigt — im Storage-Pfad. Höchstens
/// [kMaxDateinameLaenge] Zeichen.
String dokumentDateiname(
  String eingabe, {
  required String original,
  required String mime,
}) {
  final ext = dokumentEndung(mime);
  String bereinigt(String s) => s
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'\.{2,}'), '')
      .trim();
  var name = bereinigt(eingabe);
  if (name.isEmpty) name = bereinigt(original);
  final passend =
      (ext == 'jpg'
              ? RegExp(r'\.jpe?g$', caseSensitive: false)
              : RegExp('\\.$ext\$', caseSensitive: false))
          .firstMatch(name);
  final endung = passend?.group(0) ?? '.$ext';
  final randpunkte = RegExp(r'^[.\s]+|[.\s]+$');
  var basis = name
      .replaceAll(RegExp(r'\.(pdf|jpe?g|png)$', caseSensitive: false), '')
      .replaceAll(randpunkte, '');
  final platz = kMaxDateinameLaenge - endung.length;
  if (basis.length > platz) {
    basis = basis.substring(0, platz).replaceAll(randpunkte, '');
  }
  return '${basis.isEmpty ? 'dokument' : basis}$endung';
}

/// Ruft die Edge Function `parse-dokument` auf (Claude), die ein Dokument
/// für die Ablage einordnet. Nie blockierend: jeder Fehler wird zu `null`
/// (plus `debugPrint`), der Dialog zeigt dann «Nicht erkannt».
class DokumentScanService {
  /// Grösstes PDF für die Erkennung: base64 bläht um ein Drittel auf, die
  /// Messages API nimmt höchstens 32 MB je Anfrage.
  static const maxBytes = 15 * 1024 * 1024;

  /// Grösstes Bild für die Erkennung (3.7 MB): Ein Bild nimmt die Messages
  /// API nur bis 5 MB base64 an — das sind 3.75 MB Rohdaten, der Rest ist
  /// Reserve.
  static const maxBildBytes = 37 * 1024 * 1024 ~/ 10;

  static const mediaTypen = {'application/pdf', 'image/jpeg', 'image/png'};

  /// Warum eine Datei NICHT zur Erkennung geht — `null`, wenn sie geht.
  /// Der Dialog zeigt den Text als Statuszeile.
  static String? hinderungsgrund(String mediaType, int groesse) {
    if (!mediaTypen.contains(mediaType) || groesse <= 0) {
      return 'Keine Erkennung für diesen Dateityp — Felder von Hand';
    }
    if (mediaType == 'application/pdf') {
      return groesse > maxBytes
          ? 'PDF zu gross für die Erkennung (max. 15 MB) — Felder von Hand'
          : null;
    }
    return groesse > maxBildBytes
        ? 'Bild zu gross für die Erkennung (max. 3.7 MB) — Felder von Hand'
        : null;
  }

  static bool erkennbar(String mediaType, int groesse) =>
      hinderungsgrund(mediaType, groesse) == null;

  /// Die erlaubten Werte aus `dokument_pfad.dart`. Die Function prüft die
  /// Modellantwort dagegen — so braucht eine neue Typ-Art keinen Deploy.
  static Map<String, Object> katalog() {
    final labels = <String, String>{...dokumentBereiche};
    final typen = <String, List<String>>{};
    final kategorien = <String, List<String>>{};
    for (final b in dokumentBereiche.keys) {
      typen[b] = dokumentTypen(b);
      for (final t in typen[b]!) {
        labels[t] = dokumentTypLabel(t);
      }
      if (dokumentKategorien(b) case final kat?) {
        kategorien[b] = kat.keys.toList();
        labels.addAll(kat);
      }
    }
    return {
      'bereiche': dokumentBereiche.keys.toList(),
      'typen': typen,
      'kategorien': kategorien,
      'labels': labels,
    };
  }

  static Future<DokumentScanErgebnis?> erkennen({
    required Uint8List bytes,
    required String mediaType,
    required String bereichVorgabe,
  }) async {
    if (!erkennbar(mediaType, bytes.length)) return null;
    try {
      final client = SupabaseService.client;
      // `functions.invoke('…'` zusammenhängend lassen — der Deno-Wächter
      // (supabase/functions/_waechter_test.ts) findet den Aufruf daran.
      final aufruf = client.functions.invoke(
        'parse-dokument',
        body: {
          'datei_base64': base64Encode(bytes),
          'media_type': mediaType,
          'bereich_vorgabe': bereichVorgabe,
          ...katalog(),
        },
      );
      // Die Function bricht nach 55 s selbst ab; das hier fängt nur ein
      // hängendes Netz ab, damit der Dialog nicht ewig «erkennt».
      final response = await aufruf.timeout(const Duration(seconds: 75));
      final data = response.data;
      if (data is Map && data['ok'] == true && data['ergebnis'] is Map) {
        return DokumentScanErgebnis.fromJson(
          Map<String, dynamic>.from(data['ergebnis'] as Map),
        );
      }
      debugPrint(
        'parse-dokument: unerwartete Antwort (${response.status}): $data',
      );
      return null;
    } catch (e) {
      // FunctionException (4xx/5xx), Timeout, Netz — alles «nicht erkannt».
      debugPrint('parse-dokument fehlgeschlagen: $e');
      return null;
    }
  }
}
