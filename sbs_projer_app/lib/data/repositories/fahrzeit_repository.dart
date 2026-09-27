import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sbs_projer_app/core/util/fahrzeit.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Ein Fahrzeit-Eintrag der Tabelle `fahrzeiten` (Kaskade: beobachtet > route
/// > Heuristik, s. `lib/core/util/fahrzeit.dart`). Supabase-only (kein Isar) —
/// die Heuristik deckt den Offline-Fall ab.
///
/// [distanzKm]/[distanzQuelle] (Migration 210, 27.09.2026): geroutete Strecke
/// des Paars für «Fahrten aus der Kette»; `null`, solange die Edge Function
/// `fahrzeit-route` sie noch nicht nachgetragen hat.
typedef FahrzeitEintrag = ({
  int minuten,
  String quelle,
  double? distanzKm,
  String? distanzQuelle,
});

/// Kaskaden-Repository fuer gelernte/gecachte Fahrzeiten zwischen Betrieben
/// (Spec 2026-07-29 Tourenplan-Zeitachse §3).
class FahrzeitRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Laedt ALLE Fahrzeiten des Users (kein N+1) — Aufruf beim Screen-Start
  /// des Tourenplans und fuer «Fahrten aus der Kette». Key `'$von>$nach'`
  /// (Richtung wie gespeichert; Gegenrichtung siehe [ausMap]).
  ///
  /// Seitenweise mit `.order('id')`: Die Tabelle hat laengst mehr als die
  /// 1000 Zeilen, bei denen PostgREST eine einzelne Abfrage abschneidet
  /// (3594 am 27.09.2026) — ohne Seiten fehlte still der Grossteil der Paare.
  static Future<Map<String, FahrzeitEintrag>> ladeAlle() async {
    const seite = 1000;
    Future<List<Map<String, dynamic>>> holeSeite(int nr) => SupabaseService
        .client
        .from('fahrzeiten')
        .select(
          'id, von_betrieb_id, nach_betrieb_id, minuten, quelle, '
          'distanz_km, distanz_quelle',
        )
        .order('id')
        .range(nr * seite, (nr + 1) * seite - 1)
        .then((rows) => List<Map<String, dynamic>>.from(rows));

    final rows = <Map<String, dynamic>>[];
    final erste = await holeSeite(0);
    rows.addAll(erste);
    // Folgeseiten in Wellen zu vier parallel (Muster der Repositories).
    var naechste = 1;
    var letzteVoll = erste.length == seite;
    while (letzteVoll) {
      final wellen = await Future.wait([
        for (var i = 0; i < 4; i++) holeSeite(naechste + i),
      ]);
      for (final w in wellen) {
        rows.addAll(w);
      }
      letzteVoll = wellen.last.length == seite;
      naechste += 4;
    }

    final map = <String, FahrzeitEintrag>{};
    for (final r in rows) {
      final von = r['von_betrieb_id'] as String;
      final nach = r['nach_betrieb_id'] as String;
      map['$von>$nach'] = (
        minuten: (r['minuten'] as num).toInt(),
        quelle: r['quelle'] as String,
        // numeric kommt je nach Wert als num oder String zurück.
        distanzKm: _zahl(r['distanz_km']),
        distanzQuelle: r['distanz_quelle'] as String?,
      );
    }
    return map;
  }

  static double? _zahl(Object? v) => switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };

  /// Liest [vonId]->[nachId] aus der geladenen Map, prueft erst die
  /// gespeicherte Richtung, dann die Gegenrichtung (Fahrzeiten sind
  /// richtungsabhaengig gespeichert, aber meist symmetrisch nutzbar).
  static FahrzeitEintrag? ausMap(
    Map<String, FahrzeitEintrag> map,
    String vonId,
    String nachId,
  ) {
    return map['$vonId>$nachId'] ?? map['$nachId>$vonId'];
  }

  /// Lässt die Anfahrtszeiten von beiden Startorten (Domat/Ems, Chur) zu
  /// EINEM Betrieb berechnen und speichern — Aufruf nach dem Anlegen eines
  /// Betriebs mit Koordinaten (Daniel 31.07.2026: «bei aus Google übernehmen
  /// auch die Anfahrtszeiten ermitteln»).
  ///
  /// Fire-and-forget: Die Edge-Function holt OSRM (immer) und Google (sobald
  /// die Routes API freigeschaltet ist). Fehler werden still geloggt — ohne
  /// gespeicherten Wert rechnet die Zeitachse weiter mit der Heuristik.
  static Future<void> anfahrtBerechnen(String betriebId) async {
    try {
      await SupabaseService.client.functions.invoke(
        'anfahrt-google',
        body: {'betriebId': betriebId},
      );
    } catch (e) {
      debugPrint('[FahrzeitRepository] anfahrtBerechnen fehlgeschlagen: $e');
    }
  }

  /// Fordert eine geroutete Fahrzeit von der Edge-Function `fahrzeit-route`
  /// an (OSRM-Proxy mit Cache). Fire-and-forget aus Sicht der Aufrufer:
  /// Fehler/Timeouts liefern still `null` zurueck — die App zeigt derweil die
  /// Heuristik, ein Provider stoesst den Aufruf an und invalidiert bei Erfolg.
  static Future<FahrzeitEintrag?> routeAnfordern(
    String vonId,
    String nachId,
  ) async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        'fahrzeit-route',
        body: {'vonBetriebId': vonId, 'nachBetriebId': nachId},
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) {
        final distanzKm = _zahl(data['distanzKm']);
        return (
          minuten: (data['minuten'] as num).toInt(),
          quelle: data['quelle'] as String,
          distanzKm: distanzKm,
          // Die Edge Function routet nur über OSRM (Migration 210).
          distanzQuelle: distanzKm == null ? null : 'osrm',
        );
      }
      return null;
    } catch (e) {
      debugPrint('[FahrzeitRepository] routeAnfordern fehlgeschlagen: $e');
      return null;
    }
  }

  /// Fuehrt eine Beobachtung nach (Spec §3.1: «wird mit der Zeit genauer»).
  /// Bestehender Eintrag `quelle=='beobachtet'` (exakte Richtung) -> gleitender
  /// Mittelwert ueber `anzahl`; Eintrag `route` oder fehlend -> ueberschreiben
  /// mit `quelle='beobachtet', anzahl=1` (Beobachtung schlaegt Route immer).
  /// Werte ausserhalb 3-120 min werden NICHT geschrieben (gleiche
  /// Gueltigkeitsregel wie der Backfill in Migration 152). Fehler werden still
  /// geloggt — die Nachfuehrung darf das Speichern einer Reinigung nie stoeren.
  static Future<void> beobachtungNachfuehren({
    required String vonBetriebId,
    required String nachBetriebId,
    required int minuten,
  }) async {
    if (minuten < 3 || minuten > 120) return;
    try {
      final bestehend = await SupabaseService.client
          .from('fahrzeiten')
          .select('minuten, quelle, anzahl, referenz_minuten')
          .eq('user_id', _userId)
          .eq('von_betrieb_id', vonBetriebId)
          .eq('nach_betrieb_id', nachBetriebId)
          .maybeSingle();

      // Plausibilitäts-Riegel (Daniel 30.07.2026): Liegt die gemessene Lücke
      // weit neben der tatsächlichen Route, war eine Störung, eine Pause oder
      // eine Terminwartezeit dazwischen — dann NICHT lernen. Kostet keine
      // zusätzliche Eingabe und hätte 652 verdorbene Altwerte verhindert.
      final referenz = (bestehend?['referenz_minuten'] as num?)?.toInt();
      if (!lueckePlausibel(lueckeMinuten: minuten, referenzMinuten: referenz)) {
        debugPrint(
          '[FahrzeitRepository] Lücke $minuten min verworfen '
          '(Route $referenz min) — vermutlich Störung/Pause dazwischen',
        );
        return;
      }

      if (bestehend != null && bestehend['quelle'] == 'beobachtet') {
        final alt = bestehend['minuten'] as int;
        final anzahl = bestehend['anzahl'] as int;
        final neuMinuten = ((alt * anzahl + minuten) / (anzahl + 1)).round();
        await SupabaseService.client
            .from('fahrzeiten')
            .update({'minuten': neuMinuten, 'anzahl': anzahl + 1})
            .eq('user_id', _userId)
            .eq('von_betrieb_id', vonBetriebId)
            .eq('nach_betrieb_id', nachBetriebId);
        return;
      }

      await SupabaseService.client.from('fahrzeiten').upsert({
        'user_id': _userId,
        'von_betrieb_id': vonBetriebId,
        'nach_betrieb_id': nachBetriebId,
        'minuten': minuten,
        'quelle': 'beobachtet',
        'anzahl': 1,
      }, onConflict: 'user_id,von_betrieb_id,nach_betrieb_id');
    } catch (e) {
      debugPrint(
        '[FahrzeitRepository] beobachtungNachfuehren fehlgeschlagen: $e',
      );
    }
  }
}
