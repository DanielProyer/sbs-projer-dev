import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Steuerzahlungen = Buchungen mit 8900/2208 im Soll oder Haben sowie
/// ESTV-Zahlungen über 2202 gegen Bank/Kasse.
class SteuerzahlungRepository {
  static String get _userId => SupabaseService.dataUserId;

  /// Die Konten, auf denen Steuern geführt werden — Einzelquelle für den
  /// Query-Filter unten und für Aufrufer, die dieselbe Liste brauchen.
  static const steuerKonten = [8900, 2208, 2202];
  static final _steuerKontenListe = steuerKonten.join(',');

  /// Geldkonten (Bank/Kasse) — dieselben wie in `view_steuerjahr_zahlungen`.
  static const _geldKonten = {1000, 1020};

  static Future<List<Buchung>> _lade({int? steuerjahr, bool nurOhneJahr = false}) async {
    // Umfang identisch mit view_steuerjahr_zahlungen: nicht storniert UND
    // keine Gegenbuchung (Storno-Gegenbuchungen tragen storno_von_id und
    // haben selbst ist_storniert=false — ohne diesen Filter zählte das
    // Repository Zeilen, die die View ausschliesst).
    var q = SupabaseService.client
        .from('buchungen')
        .select()
        .eq('user_id', _userId)
        .eq('ist_storniert', false)
        .isFilter('storno_von_id', null)
        .or('soll_konto.in.($_steuerKontenListe),'
            'haben_konto.in.($_steuerKontenListe)');
    if (steuerjahr != null) q = q.eq('steuerjahr', steuerjahr);
    if (nurOhneJahr) q = q.isFilter('steuerjahr', null);
    // < 100 Zeilen erwartet, bewusst einseitig (keine Pagination-Schleife).
    final rows = await q.order('datum', ascending: false).order('id').range(0, 999);
    // 2202-Umsatzsteuer-Saldierungen (2200 an 2202 usw.) sind keine Zahlungen:
    // nur Zeilen gegen Bank/Kasse behalten, ausser sie sind schon zugeordnet.
    // Bei `getByJahr` greift der Geld-Filter nie (steuerjahr gesetzt → immer
    // true), damit auch Rückstellungs-/Umbuchungszeilen des Jahres sichtbar
    // bleiben; bei `getNichtZugeordnet` bleiben nur Zahlungen gegen Bank/Kasse.
    return rows.map((r) => Buchung.fromJson(r)).where((b) {
      if (b.steuerjahr != null) return true;
      return _geldKonten.contains(b.sollKonto) ||
          _geldKonten.contains(b.habenKonto);
    }).toList();
  }

  static Future<List<Buchung>> getByJahr(int jahr) => _lade(steuerjahr: jahr);
  static Future<List<Buchung>> getNichtZugeordnet() => _lade(nurOhneJahr: true);

  static Future<void> zuordnen(String buchungId,
      {required int steuerjahr, required String steuerart}) async {
    await SupabaseService.client
        .from('buchungen')
        .update({'steuerjahr': steuerjahr, 'steuerart': steuerart})
        .eq('id', buchungId);
  }

  /// Bezahlt je (jahr, steuerart) aus der View.
  ///
  /// Zeilen ohne `steuerart` laufen unter `'unbekannt'` — sie einer echten
  /// Steuerart zuzuschlagen würde einen falschen Bezahlt-Stand vortäuschen.
  /// Die Beträge werden je Schlüssel summiert, damit mehrere Gruppen der
  /// View sich nicht gegenseitig überschreiben.
  static Future<Map<(int, String), double>> bezahltJeJahr() async {
    final rows = await SupabaseService.client
        .from('view_steuerjahr_zahlungen')
        .select()
        .eq('user_id', _userId);
    final m = <(int, String), double>{};
    for (final r in rows) {
      final k = (r['steuerjahr'] as int, (r['steuerart'] as String?) ?? 'unbekannt');
      m[k] = (m[k] ?? 0) + (double.tryParse(r['bezahlt'].toString()) ?? 0);
    }
    return m;
  }
}
