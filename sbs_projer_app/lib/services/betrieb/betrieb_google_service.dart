import 'package:sbs_projer_app/data/models/google_betrieb_daten.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ruft die Edge-Function `betrieb-google-lookup` und normalisiert das
/// Resultat zu [GoogleBetriebDaten].
class BetriebGoogleService {
  /// Sucht einen Betrieb. [query] z.B. "‹Name› ‹PLZ Ort›".
  /// Wirft [BetriebGoogleException] bei Fehler / keinem Treffer.
  static Future<GoogleBetriebDaten> lookup(String query) async {
    final response = await SupabaseService.client.functions.invoke(
      'betrieb-google-lookup',
      body: {'query': query},
    );

    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final msg = data is Map ? data['error'] : 'Unbekannter Fehler';
      throw BetriebGoogleException(msg?.toString() ?? 'Unbekannter Fehler');
    }
    if (data['error'] == 'no_result') {
      throw BetriebGoogleException('Kein Google-Treffer gefunden.');
    }
    if (data['error'] != null) {
      throw BetriebGoogleException(data['error'].toString());
    }
    final place = data['place'];
    if (place is! Map) {
      throw BetriebGoogleException('Ungültige Antwort von Google.');
    }
    return betriebAusGooglePlace(place);
  }

  /// Liest Öffnungszeiten + Ruhetage von der Betriebs-Website via AI
  /// (Edge-Function `parse-oeffnungszeiten`). Gibt [GoogleBetriebDaten] mit
  /// nur Öffnungszeiten/Ruhetage. Wirft [BetriebGoogleException] bei Fehler.
  static Future<GoogleBetriebDaten> oeffnungszeitenVonWebsite(
    String url, {
    String? name,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'parse-oeffnungszeiten',
      body: {
        'url': url,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final msg = data is Map ? data['error'] : 'Unbekannter Fehler';
      throw BetriebGoogleException(msg?.toString() ?? 'Unbekannter Fehler');
    }
    if (data['error'] != null) {
      throw BetriebGoogleException(data['error'].toString());
    }
    return oeffnungszeitenAusWebsiteJson(data);
  }
}

class BetriebGoogleException implements Exception {
  final String message;
  BetriebGoogleException(this.message);
  @override
  String toString() => message;
}
