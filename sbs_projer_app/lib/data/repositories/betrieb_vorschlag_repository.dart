import 'package:sbs_projer_app/data/models/betrieb_vorschlag.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_ferien_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Felder, die beim Übernehmen eines `saison`-Vorschlags gesetzt werden
/// dürfen — nur diese vier Spalten, alles andere wird ignoriert.
const _kSaisonFelder = {
  'sommer_start_datum',
  'sommer_ende_datum',
  'winter_start_datum',
  'winter_ende_datum',
};

/// Zugriff auf die Prüfliste `betrieb_vorschlaege` (Migration 160).
///
/// Reines Server-Feature (kein Isar/Offline-Teil): Google und Website
/// laufen ausschliesslich online, ein Vorschlag, den Daniel offline nicht
/// sehen kann, wäre ohnehin wertlos — anders als z.B. eine Reinigung, die
/// er im Keller ohne Empfang erfassen muss.
///
/// Übernehmen schreibt NIE automatisch — jede Zeile hier entspricht einem
/// bewussten Klick von Daniel auf «Übernehmen» in der Prüfliste.
class BetriebVorschlagRepository {
  static String get _userId => SupabaseService.currentUser!.id;
  static const _table = 'betrieb_vorschlaege';
  static const _betriebeTable = 'betriebe';

  /// Alle offenen Vorschläge, neueste zuerst.
  static Future<List<BetriebVorschlagDto>> offene() async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', _userId)
        .eq('status', 'offen')
        .order('gefunden_am', ascending: false);
    return rows.map((r) => BetriebVorschlagDto.fromJson(r)).toList();
  }

  /// Markiert den Vorschlag als verworfen — keine Änderung am Betrieb.
  static Future<void> verwerfen(String id) async {
    await SupabaseService.client
        .from(_table)
        .update({'status': 'verworfen'})
        .eq('id', id);
  }

  /// Schreibt [v.neuWert] in den betroffenen Betrieb und markiert den
  /// Vorschlag als übernommen. Wirft [UnsupportedError] für `feld ==
  /// 'status'` — das ist nur ein Hinweis ("bei Google vorübergehend
  /// geschlossen") und wird bewusst nie ins Stammdatenfeld geschrieben, weil
  /// es kein 1:1-Gegenstück zu `betriebe.status` hat.
  static Future<void> uebernehmen(BetriebVorschlagDto v) async {
    switch (v.feld) {
      case 'ruhetage':
        await _uebernehmeRuhetage(v);
        break;
      case 'oeffnungszeiten':
        await _uebernehmeOeffnungszeiten(v);
        break;
      case 'ferien':
        await _uebernehmeFerien(v);
        break;
      case 'saison':
        await _uebernehmeSaison(v);
        break;
      case 'status':
        throw UnsupportedError(
          'Status-Vorschläge sind nur ein Hinweis und werden nicht '
          'automatisch übernommen.',
        );
      default:
        throw ArgumentError('Unbekanntes Vorschlag-Feld: ${v.feld}');
    }
    await SupabaseService.client
        .from(_table)
        .update({'status': 'uebernommen'})
        .eq('id', v.id);
  }

  static Future<void> _uebernehmeRuhetage(BetriebVorschlagDto v) async {
    final liste = (v.neuWert as List).map((e) => e.toString()).toList();
    await SupabaseService.client
        .from(_betriebeTable)
        .update({
          'ruhetage': liste,
          'ruhetage_bestaetigt_am': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', v.betriebId);
  }

  static Future<void> _uebernehmeOeffnungszeiten(BetriebVorschlagDto v) async {
    await SupabaseService.client
        .from(_betriebeTable)
        .update({
          'oeffnungszeiten': v.neuWert ?? {},
          'oeffnungszeiten_geprueft_am': DateTime.now()
              .toUtc()
              .toIso8601String(),
        })
        .eq('id', v.betriebId);
  }

  /// `neu_wert` ist eine Liste von Perioden ({'von','bis'}) — die
  /// Website-Extraktion kann mehrere Ferienzeiträume auf einmal liefern.
  /// `bestaetigt_am` bleibt in jedem Fall leer: eine Fremdquelle bestätigt
  /// nichts (siehe `BetriebFerienRepository`).
  static Future<void> _uebernehmeFerien(BetriebVorschlagDto v) async {
    final perioden = (v.neuWert as List).cast<Map<String, dynamic>>();
    final quelle = v.quelle == 'website' ? 'website' : 'google';
    for (final p in perioden) {
      await BetriebFerienRepository.periodeErfassen(
        betriebId: v.betriebId,
        von: DateTime.parse(p['von'] as String),
        bis: DateTime.parse(p['bis'] as String),
        quelle: quelle,
      );
    }
  }

  /// Übernimmt nur die in `neu_wert` tatsächlich vorhandenen Saisonfelder —
  /// üblicherweise nur Sommer ODER Winter, nicht beide.
  static Future<void> _uebernehmeSaison(BetriebVorschlagDto v) async {
    final neu = v.neuWert;
    if (neu is! Map) return;
    final patch = <String, dynamic>{
      for (final key in _kSaisonFelder)
        if (neu[key] != null) key: neu[key],
    };
    if (patch.isEmpty) return;
    await SupabaseService.client
        .from(_betriebeTable)
        .update(patch)
        .eq('id', v.betriebId);
  }

  /// Übernimmt alle offenen Vorschläge, bei denen Google und Website
  /// übereinstimmen (`quelle == 'google_website'`) — mit Ausnahme von
  /// `saison`: ein falscher Saisonstart nimmt einen Betrieb still für
  /// Monate aus der Fällig-Liste, weil `faelligkeitsAnker()` die
  /// Fälligkeits-Uhr erst bei der Wiedereröffnung startet. Saison wird
  /// deshalb immer einzeln bestätigt. Gibt die Anzahl übernommener
  /// Vorschläge zurück.
  static Future<int> alleUebereinstimmendenUebernehmen() async {
    final alle = await offene();
    final kandidaten = alle.where(
      (v) => v.quelle == 'google_website' && v.feld != 'saison',
    );
    var anzahl = 0;
    for (final v in kandidaten) {
      await uebernehmen(v);
      anzahl++;
    }
    return anzahl;
  }
}
