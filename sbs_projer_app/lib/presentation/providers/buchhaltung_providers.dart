import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/konto_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/audit_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Erfolgsrechnung aus DB-View (monatlich/jährlich).
final erfolgsrechnungProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, jahr) async {
  final rows = await SupabaseService.client
      .from('view_erfolgsrechnung')
      .select()
      .eq('geschaeftsjahr', jahr)
      .order('monat');
  return List<Map<String, dynamic>>.from(rows);
});

/// MwSt-Abrechnung aus DB-View (quartalsweise).
final mwstAbrechnungProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, jahr) async {
  final rows = await SupabaseService.client
      .from('view_mwst_abrechnung')
      .select()
      .eq('geschaeftsjahr', jahr)
      .order('quartal');
  return List<Map<String, dynamic>>.from(rows);
});

/// MwSt-Quartaldetails mit Umsatz + ESTV-Ziffern.
final mwstQuartalDetailProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, jahr) async {
  // Alle Buchungen des Geschäftsjahres laden
  final rows = await SupabaseService.client
      .from('buchungen')
      .select('quartal, soll_konto, haben_konto, betrag_brutto, mwst_betrag')
      .eq('geschaeftsjahr', jahr);

  final buchungen = List<Map<String, dynamic>>.from(rows);

  // Pro Quartal berechnen
  final result = <Map<String, dynamic>>[];
  for (int q = 1; q <= 4; q++) {
    final qBuchungen = buchungen.where((b) => b['quartal'] == q).toList();

    // Umsatz = Konto 3400 Dienstleistungserlöse (Ertragskonto: Haben - Soll → positiv)
    double umsatz = 0;
    for (final b in qBuchungen) {
      final betrag = _toDouble(b['betrag_brutto']);
      if (b['haben_konto'] == 3400) umsatz += betrag;
      if (b['soll_konto'] == 3400) umsatz -= betrag;
    }

    // Umsatzsteuer = Summe mwst_betrag wo haben_konto = 3400 (Erlös-Buchungen)
    double umsatzsteuer = 0;
    for (final b in qBuchungen) {
      if (b['haben_konto'] == 3400) {
        umsatzsteuer += _toDouble(b['mwst_betrag']);
      }
    }

    // Vorsteuer Material = Konto 1170 Saldo (Aktivkonto: Soll - Haben)
    double vorsteuerMaterial = 0;
    for (final b in qBuchungen) {
      final betrag = _toDouble(b['betrag_brutto']);
      if (b['soll_konto'] == 1170) vorsteuerMaterial += betrag;
      if (b['haben_konto'] == 1170) vorsteuerMaterial -= betrag;
    }

    // Vorsteuer Betrieb = Konto 1171 Saldo (Aktivkonto: Soll - Haben)
    double vorsteuerBetrieb = 0;
    for (final b in qBuchungen) {
      final betrag = _toDouble(b['betrag_brutto']);
      if (b['soll_konto'] == 1171) vorsteuerBetrieb += betrag;
      if (b['haben_konto'] == 1171) vorsteuerBetrieb -= betrag;
    }

    final nettoSchuld = umsatzsteuer - vorsteuerMaterial - vorsteuerBetrieb;

    result.add({
      'quartal': q,
      'umsatz': umsatz,
      'umsatzsteuer': umsatzsteuer,
      'vorsteuer_material': vorsteuerMaterial,
      'vorsteuer_betrieb': vorsteuerBetrieb,
      'netto_mwst_schuld': nettoSchuld,
    });
  }

  return result;
});

double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

List<BuchungSaldo> _toSaldoInput(List<Buchung> buchungen) => buchungen
    .map((b) => BuchungSaldo(
          sollKonto: b.sollKonto,
          habenKonto: b.habenKonto,
          betrag: b.betragBrutto,
          datum: b.datum,
          storniert: b.istStorniert,
          mwstKonto: b.mwstKonto,
          betragNetto: b.betragNetto,
          mwstBetrag: b.mwstBetrag,
        ))
    .toList();

/// Bilanz per 31.12. des gewählten Geschäftsjahrs.
final bilanzProvider = FutureProvider.family<BilanzDaten, int>((ref, jahr) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final saldi = BilanzService.saldiPerStichtag(
    _toSaldoInput(buchungen),
    DateTime(jahr, 12, 31),
  );
  final kontoInfos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return BilanzService.gruppiere(saldi, kontoInfos);
});

/// Erfolgsrechnung (Stufengliederung) für ein Geschäftsjahr.
final erfolgsrechnungStufenProvider =
    FutureProvider.family<ErfolgsrechnungDaten, int>((ref, jahr) async {
  final buchungen = await BuchungRepository.getAll();
  return ErfolgsrechnungService.berechne(
    _toSaldoInput(buchungen),
    von: DateTime(jahr, 1, 1),
    bis: DateTime(jahr, 12, 31),
  );
});

/// Offene Rechnungen aus DB-View.
final offeneRechnungenViewProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from('view_offene_rechnungen')
      .select()
      .order('faelligkeitsdatum');
  return List<Map<String, dynamic>>.from(rows);
});

/// Audit-Befunde: verdächtige Salden / fehlende Buchungen.
final auditBefundeProvider = FutureProvider<List<AuditBefund>>((ref) async {
  final saldi = await BuchungService.getAllSaldi();
  final konten = await KontoRepository.getAll();
  final infos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return AuditService.befunde(saldi, infos);
});
