import 'dart:convert';
import 'dart:typed_data';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

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

    final response = await SupabaseService.client.functions.invoke(
      'typenschild-lesen',
      body: {
        'image_base64': base64,
        'media_type': mediaType,
      },
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unbekannter Fehler';
      throw Exception('Typenschild-Analyse fehlgeschlagen: $error');
    }

    final data = response.data as Map<String, dynamic>;
    return TypenschildErgebnis.fromJson(data);
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
      hersteller: json['hersteller'] as String?,
      typBezeichnung: json['typ_bezeichnung'] as String?,
      seriennummer: json['seriennummer'] as String?,
      baujahr: _baujahr(json['baujahr']),
      unsicherBei: (json['unsicher_bei'] as List?)?.whereType<String>().toList() ?? const [],
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
}
