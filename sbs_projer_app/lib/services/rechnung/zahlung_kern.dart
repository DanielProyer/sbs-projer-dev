import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart'
    show ZahlungWeg, MehrzahlungZiel, mehrzahlungStandard;

/// Die DB hat abgelehnt (Sperre) — Text ist nutzerlesbar (aus RAISE EXCEPTION).
class ZahlungGesperrt implements Exception {
  final String text;
  const ZahlungGesperrt(this.text);
  @override
  String toString() => text;
}

class ZahlungErgebnis {
  final String gruppeId;
  final ZahlungKernPlan plan;
  const ZahlungErgebnis(this.gruppeId, this.plan);
}

/// DER Zahlungsweg (Runde 3). Plant in Dart (`zahlungKernPlan`, getestet),
/// schreibt atomar per RPC `zahlung_erfassen` (Migration 209). Bis v0.141.0
/// gab es sieben Wege mit je eigener Sperre, eigenem zahlung_betrag und
/// eigenem Rückweg — Analyse 25.09.2026 §3 Befund E.
class ZahlungKern {
  static const _sperrTexte = [
    'Nicht zahlbar',
    'inzwischen geändert',
    'nicht freigegeben',
    'abgeschlossenem Geschäftsjahr',
    'nicht mehr «bezahlt»',
    'bereits zurückgenommen',
    'Keine aktive Zahlung',
    'storniert',
  ];

  static Future<ZahlungErgebnis> erfassen({
    required List<Rechnung> rechnungen,
    required double betrag,
    required DateTime datum,
    required ZahlungWeg weg,
    Map<String, DateTime> datumProRechnung = const {},
    Map<String, String> camtTxKeyProRechnung = const {},
    String? camtTxKey,
    MehrzahlungZiel? mehrzahlung,
  }) async {
    final plan = zahlungKernPlan(
      rechnungen: rechnungen,
      betrag: betrag,
      datum: datum,
      weg: weg,
      datumProRechnung: datumProRechnung,
      camtTxKeyProRechnung: camtTxKeyProRechnung,
      camtTxKey: camtTxKey,
      mehrzahlung: mehrzahlung,
    );
    try {
      final res = await SupabaseService.client.rpc('zahlung_erfassen', params: {
        'p_weg': weg.name,
        'p_betrag': betrag,
        'p_datum': datum.toIso8601String().split('T').first,
        'p_rechnung_ids': rechnungen.map((r) => r.id).toList(),
        'p_buchungen': plan.buchungen,
        'p_updates': plan.updates,
        'p_vorher': plan.vorher,
        'p_erwartet': plan.erwartet,
        'p_camt_tx_keys': plan.camtTxKeys,
      });
      return ZahlungErgebnis(res as String, plan);
    } on PostgrestException catch (e) {
      if (_sperrTexte.any(e.message.contains)) throw ZahlungGesperrt(e.message);
      rethrow;
    }
  }

  /// Nimmt die Zahlung zurück, an der [rechnungId] hängt — die ganze Gruppe.
  /// Liefert die Zahl gelöschter Buchungen.
  static Future<int> zuruecknehmen(String rechnungId) async {
    try {
      final res = await SupabaseService.client
          .rpc('zahlung_zuruecknehmen', params: {'p_rechnung': rechnungId});
      return (res as num).toInt();
    } on PostgrestException catch (e) {
      if (_sperrTexte.any(e.message.contains)) throw ZahlungGesperrt(e.message);
      rethrow;
    }
  }

  /// Nutzerlesbarer Text: eigene Sperren voll, alles andere gekürzt.
  static String meldung(Object e) =>
      e is ZahlungGesperrt ? e.text : kurzeFehlermeldung(e);
}
