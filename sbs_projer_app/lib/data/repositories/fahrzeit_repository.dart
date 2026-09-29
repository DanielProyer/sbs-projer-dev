import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:sbs_projer_app/core/util/fahrzeit.dart';
import 'package:sbs_projer_app/core/util/routen_punkt_key.dart';
import 'package:sbs_projer_app/core/util/routen_warteschlange.dart';
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
    final rows = await _alleZeilen(
      'fahrzeiten',
      'id, von_betrieb_id, nach_betrieb_id, minuten, quelle, '
          'distanz_km, distanz_quelle',
    );

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

  /// Geroutete Strecken zwischen Punkten (`routen_punkte`, Migration 213):
  /// `'<vonKey>><nachKey>'` → km, Schlüssel wie `punktRoutenSchluessel`
  /// (`'b:<uuid>'` / `'p:<lat>,<lng>'`). Richtung wie gespeichert — der
  /// Nachschlag (`kmNachschlagAus`) prüft auch die Gegenrichtung. Gefüllt
  /// nur von der Edge Function `fahrzeit-route`.
  ///
  /// Seitenweise mit `.order('id')` wie [ladeAlle]: Die Tabelle wächst mit
  /// jedem Tag, der unterwegs beginnt oder endet.
  static Future<Map<String, double>> ladePunktRouten() async {
    final rows = await _alleZeilen(
      'routen_punkte',
      'id, von_key, nach_key, distanz_km',
    );
    final map = <String, double>{};
    for (final r in rows) {
      final km = _zahl(r['distanz_km']);
      if (km == null) continue;
      final von = r['von_key'] as String, nach = r['nach_key'] as String;
      map[punktRoutenSchluessel(von, nach)] = km;
    }
    return map;
  }

  /// Alle Zeilen einer Tabelle, seitenweise (PostgREST schneidet bei 1000
  /// ab) — sortiert nach `id`, damit keine Zeile zwischen zwei Seiten
  /// verloren geht. Folgeseiten in Wellen zu vier parallel (Muster der
  /// Repositories).
  static Future<List<Map<String, dynamic>>> _alleZeilen(
    String tabelle,
    String spalten,
  ) async {
    const seite = 1000;
    Future<List<Map<String, dynamic>>> holeSeite(int nr) => SupabaseService
        .client
        .from(tabelle)
        .select(spalten)
        .order('id')
        .range(nr * seite, (nr + 1) * seite - 1)
        .then((rows) => List<Map<String, dynamic>>.from(rows));

    final rows = <Map<String, dynamic>>[];
    final erste = await holeSeite(0);
    rows.addAll(erste);
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
    return rows;
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

  /// EINE Schlange für alle Aufrufer (Tourenplan und «Fahrten aus der
  /// Kette»): Der OSRM-Demo-Server hinter `fahrzeit-route` erlaubt höchstens
  /// eine Anfrage pro Sekunde — parallele Läufe erzeugten 3 Anfragen/s
  /// (Logs 27.09.2026).
  static final _routenSchlange = RoutenWarteschlange();

  /// Fordert eine geroutete Fahrzeit zwischen zwei BETRIEBEN von der
  /// Edge-Function `fahrzeit-route` an (OSRM-Proxy mit Cache `fahrzeiten`)
  /// — der Tourenplan. Kurzform von [routeAnfordernEnden].
  static Future<FahrzeitEintrag?> routeAnfordern(String vonId, String nachId) =>
      routeAnfordernEnden(
        (betriebId: vonId, lat: null, lng: null),
        (betriebId: nachId, lat: null, lng: null),
      );

  /// Fordert eine geroutete Strecke von der Edge-Function `fahrzeit-route`
  /// an. Jedes Ende ist ein Betrieb (`betriebId`) oder — seit Migration 213
  /// — ein Punkt (`lat`/`lng`: Startort, GPS-Position); die Function legt
  /// Betrieb→Betrieb in `fahrzeiten` ab, alles andere in `routen_punkte`
  /// ([ladePunktRouten]).
  ///
  /// Fire-and-forget aus Sicht der Aufrufer: Fehler/Timeouts liefern still
  /// `null` zurueck — ein Provider stoesst den Aufruf an und invalidiert bei
  /// Erfolg.
  ///
  /// Läuft durch [_routenSchlange]: nacheinander, mit mindestens
  /// `kRoutenAbstand` Pause. Wer mehrere Paare auf einmal aufruft (ohne
  /// dazwischen zu warten), reiht sie als Block ein.
  static Future<FahrzeitEintrag?> routeAnfordernEnden(
    RoutenEnde von,
    RoutenEnde nach,
  ) => _routenSchlange.einreihen(() => _routeJetztAnfordern(von, nach));

  /// Body für `fahrzeit-route`: `{von: {...}, nach: {...}}`, je Ende nur die
  /// gesetzten Felder (die Function lehnt Betrieb UND Punkt zugleich ab).
  ///
  /// Betrieb → Betrieb zusätzlich im Format vor Migration 213
  /// (`vonBetriebId`/`nachBetriebId`): So läuft diese App auch gegen die
  /// alte Function, falls sie im Rollout-Fenster noch live ist — der
  /// Tourenplan fällt dann nicht aus. Die neue Function liest `von`/`nach`
  /// und weist einen Widerspruch zum alten Format ab (`anfrage.ts`).
  @visibleForTesting
  static Map<String, Object> anfrageBody(RoutenEnde von, RoutenEnde nach) {
    Map<String, Object> ende(RoutenEnde e) => {
      if (e.betriebId case final id?) 'betriebId': id,
      if (e.lat case final lat?) 'lat': lat,
      if (e.lng case final lng?) 'lng': lng,
    };
    return {
      'von': ende(von),
      'nach': ende(nach),
      // Betrieb → Betrieb auch im Format vor 213 (alte Function im
      // Rollout-Fenster).
      if (von.betriebId != null && nach.betriebId != null) ...{
        'vonBetriebId': von.betriebId!,
        'nachBetriebId': nach.betriebId!,
      },
    };
  }

  static Future<FahrzeitEintrag?> _routeJetztAnfordern(
    RoutenEnde von,
    RoutenEnde nach,
  ) async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        'fahrzeit-route',
        body: anfrageBody(von, nach),
      );
      final data = res.data;
      if (data is Map && data['ok'] == true) {
        final distanzKm = _zahl(data['distanzKm']);
        return (
          minuten: (data['minuten'] as num).toInt(),
          quelle: data['quelle'] as String,
          distanzKm: distanzKm,
          // Die Edge Function routet nur über OSRM (Migration 210/213).
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
