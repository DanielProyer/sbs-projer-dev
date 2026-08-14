import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

/// Ruft die Supabase Edge Function "typenschild-lesen" auf, die Claude
/// Sonnet 5 zum Auslesen eines Geraete-Typenschilds (Kuehler, Pumpe, ...)
/// verwendet. Port aus Projekt Heineken (foto-erkennen, Bildart
/// "typenschild"), hier im request/response-Muster von parse-beleg.
class TypenschildService {
  /// Analysiert ein Foto eines Typenschilds und gibt strukturierte Daten
  /// zurueck. Wirft eine Exception bei Netzwerk-/Serverfehlern — die
  /// Fehlermeldung kommt direkt von der Edge Function.
  static Future<TypenschildErgebnis> lesen(
    Uint8List bytes, {
    required String mediaType,
  }) async {
    final base64 = base64Encode(bytes);

    try {
      final response = await SupabaseService.client.functions.invoke(
        'typenschild-lesen',
        body: {
          'image_base64': base64,
          'media_type': mediaType,
        },
      );
      return TypenschildErgebnis.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FunctionException catch (e) {
      // functions_client wirft bei jedem Nicht-2xx eine FunctionException —
      // ein Status-Check auf response.status waere hier toter Code.
      final msg = e.details is Map ? (e.details as Map)['error'] : null;
      throw Exception(
        'Typenschild-Analyse fehlgeschlagen: ${msg ?? e.reasonPhrase ?? e.status}',
      );
    }
  }
}

/// Ergebnis der Typenschild-Erkennung. Felder, die auf dem Schild nicht
/// sicher lesbar waren, kommen als null zurueck und stehen zusaetzlich in
/// [unsicherBei] — ein stiller Fehlgriff waere teurer als ein gemeldeter
/// Zweifel (gleiche Logik wie beim Feldfoto-Reader in Projekt Heineken).
class TypenschildErgebnis {
  final String? hersteller;
  final String? typBezeichnung;
  final String? seriennummer;

  /// Vierstellig, nur wenn auf dem Schild wirklich aufgedruckt.
  final int? baujahr;

  /// Namen aller Felder, bei denen sich das Modell nicht sicher war.
  final List<String> unsicherBei;

  /// 'hoch', 'mittel' oder 'tief'.
  final String sicherheit;

  const TypenschildErgebnis({
    this.hersteller,
    this.typBezeichnung,
    this.seriennummer,
    this.baujahr,
    this.unsicherBei = const [],
    this.sicherheit = 'tief',
  });

  factory TypenschildErgebnis.fromJson(Map<String, dynamic> json) {
    return TypenschildErgebnis(
      hersteller: _text(json['hersteller']),
      typBezeichnung: _text(json['typ_bezeichnung']),
      seriennummer: _text(json['seriennummer']),
      baujahr: _baujahr(json['baujahr']),
      unsicherBei: List.unmodifiable(
        (json['unsicher_bei'] as List?)?.whereType<String>() ?? const <String>[],
      ),
      sicherheit: json['sicherheit'] as String? ?? 'tief',
    );
  }

  Map<String, dynamic> toJson() => {
        'hersteller': hersteller,
        'typ_bezeichnung': typBezeichnung,
        'seriennummer': seriennummer,
        'baujahr': baujahr,
        'unsicher_bei': unsicherBei,
        'sicherheit': sicherheit,
      };

  /// Vorschlag fuer kuehler_typ/pumpe_typ: Hersteller + Typbezeichnung,
  /// nur die tatsaechlich erkannten Teile, oder null wenn nichts lesbar war.
  String? vorschlagTyp() {
    final vorschlag = [hersteller, typBezeichnung].whereType<String>().join(' ').trim();
    return vorschlag.isEmpty ? null : vorschlag;
  }

  static int? _baujahr(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// Das Tool-Schema ist nicht strikt typisiert — eine Seriennummer aus
  /// Ziffern (der Normalfall auf Typenschildern) kommt als JSON-Zahl an.
  /// `as String?` wuerde dabei crashen, deshalb ueber toString() lesen.
  static String? _text(dynamic value) => value?.toString();
}
