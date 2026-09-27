import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/arbeitstag_auswertung.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

// Monatsdaten der Arbeitstag-Auswertung. Lagen bis 27.09.2026 im Screen
// (`arbeitstag_auswertung_screen.dart`, der sie weiter exportiert); seit
// «Fahrten aus der Kette» braucht sie auch `fahrten_providers.dart` — und
// Provider importieren keine Screens.

/// Monats-Schlüssel der Auswertung. Record statt DateTime, damit zwei
/// Aufrufe desselben Monats garantiert denselben Provider treffen — ein
/// DateTime mit abweichender Uhrzeit wäre ein anderer family-Schlüssel und
/// würde denselben Monat ein zweites Mal laden.
typedef AuswertungsMonat = ({int jahr, int monat});

/// Roh erfasster Arbeitstag-Rahmen aus `tagesplaene`.
///
/// [startPosition]/[endPosition]: GPS beim Arbeitsbeginn bzw. Feierabend
/// (`start_lat/lng`, `end_lat/lng`) — daraus wählt «Fahrten aus der Kette»
/// den Startort (Domat/Ems oder Chur).
typedef ArbeitstagRohdaten = ({
  DateTime datum,
  String? beginn,
  String? ende,
  int? kmStart,
  int? kmEnde,
  ({double lat, double lng})? startPosition,
  ({double lat, double lng})? endPosition,
});

String _datumStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Position aus zwei numeric-Spalten; `null`, sobald eine fehlt.
({double lat, double lng})? _position(Object? lat, Object? lng) {
  double? zahl(Object? v) => switch (v) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };
  final la = zahl(lat), ln = zahl(lng);
  return (la == null || ln == null) ? null : (lat: la, lng: ln);
}

/// Alle erfassten Arbeitstag-Rahmen eines Monats.
///
/// Eigener Provider statt `gespeicherterTagesplanProvider` je Tag: für eine
/// Monatsauswertung wären das bis zu 31 Einzelabfragen. Die Einträge
/// (`eintraege`) bleiben bewusst aussen vor — geplant ist nicht gearbeitet,
/// die Besuchszahl kommt aus den abgeschlossenen Reinigungen.
final arbeitstageProvider =
    FutureProvider.family<List<ArbeitstagRohdaten>, AuswertungsMonat>((
      ref,
      m,
    ) async {
      final von = DateTime(m.jahr, m.monat, 1);
      final bis = DateTime(
        m.jahr,
        m.monat + 1,
        1,
      ); // Monat 13 → Januar Folgejahr
      final rows = await SupabaseService.client
          .from('tagesplaene')
          .select(
            'datum, arbeitsbeginn, arbeitsende, km_start, km_stand, '
            'start_lat, start_lng, end_lat, end_lng',
          )
          .gte('datum', _datumStr(von))
          .lt('datum', _datumStr(bis))
          .order('datum');
      return [
        for (final r in rows)
          (
            datum: DateTime.parse(r['datum'] as String),
            beginn: r['arbeitsbeginn'] as String?,
            ende: r['arbeitsende'] as String?,
            kmStart: (r['km_start'] as num?)?.toInt(),
            kmEnde: (r['km_stand'] as num?)?.toInt(),
            startPosition: _position(r['start_lat'], r['start_lng']),
            endPosition: _position(r['end_lat'], r['end_lng']),
          ),
      ];
    });

/// Besuche je Tag des Monats (Betrieb + Tag = ein Besuch).
///
/// Eigene Monatsabfrage statt des allgemeinen Reinigungs-Providers: der lädt
/// auf Web zuerst die ganze Historie (~8'500 Zeilen / ~4,8 MB). Solange das
/// lief, stand hier still «0 Besuche» — ununterscheidbar von einer echten
/// Null (Befund 06.08.2026). Ein Monat sind rund 130 Zeilen.
final besucheImMonatProvider =
    FutureProvider.family<Map<DateTime, int>, AuswertungsMonat>((ref, m) async {
      final rows = await ReinigungRepository.getBesucheImMonat(m.jahr, m.monat);
      return besucheJeTag(rows);
    });
