import 'package:sbs_projer_app/core/util/einsatz_betrieb_match.dart'
    show BetriebEintrag;
import 'package:sbs_projer_app/data/models/einsatz_diktat_ergebnis.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ruft die Supabase Edge Function `parse-einsatz` auf, die aus einem
/// diktierten Satz (Gboard-Mikrofon, keine eigene Spracherkennung) einen
/// strukturierten Einsatz-Vorschlag macht.
///
/// Jeder Fehler hier (kein Netz, Timeout, Server-Fehler) fliegt als
/// Exception nach oben — der Aufrufer (`diktat_sheet.dart`) fängt sie ab und
/// legt den Rohtext als lokalen Entwurf ab, damit das Diktat nie verloren
/// geht.
class EinsatzDiktatService {
  static Future<EinsatzDiktatErgebnis> parse({
    required String text,
    required List<BetriebEintrag> betriebe,
  }) async {
    final heute = DateTime.now();
    final heuteStr =
        '${heute.year.toString().padLeft(4, '0')}-${heute.month.toString().padLeft(2, '0')}-${heute.day.toString().padLeft(2, '0')}';

    final response = await SupabaseService.client.functions.invoke(
      'parse-einsatz',
      body: {
        'text': text,
        'heute': heuteStr,
        'betriebe': [
          for (final b in betriebe) {'id': b.id, 'name': b.name, 'ort': b.ort},
        ],
      },
    );

    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final msg = data is Map ? data['error'] : null;
      throw Exception(
        msg?.toString() ??
            'Diktat-Auswertung fehlgeschlagen (${response.status})',
      );
    }
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return EinsatzDiktatErgebnis.fromJson(Map<String, dynamic>.from(data));
  }
}
