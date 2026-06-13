import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/konto_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/audit_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/saldo_expansion.dart';
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
  final rows = await SupabaseService.client
      .from('buchungen')
      .select('quartal, soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto, ist_storniert')
      .eq('user_id', SupabaseService.dataUserId)
      .eq('geschaeftsjahr', jahr);

  final buchungen = List<Map<String, dynamic>>.from(rows);
  final result = <Map<String, dynamic>>[];

  for (int q = 1; q <= 4; q++) {
    final saldi = <int, double>{};
    for (final b in buchungen) {
      if (b['quartal'] != q || b['ist_storniert'] == true) continue;
      final brutto = _toDouble(b['betrag_brutto']);
      final netto = b['betrag_netto'] != null ? _toDouble(b['betrag_netto']) : brutto;
      final mwst = _toDouble(b['mwst_betrag']);
      SaldoExpansion.apply(
        saldi,
        sollKonto: b['soll_konto'] as int,
        habenKonto: b['haben_konto'] as int,
        mwstKonto: b['mwst_konto'] as int?,
        betragNetto: netto,
        mwstBetrag: mwst,
        betragBrutto: brutto,
      );
    }
    final umsatz = -(saldi[3400] ?? 0);
    final umsatzsteuer = -(saldi[2200] ?? 0);
    final vorsteuerMaterial = (saldi[1170] ?? 0);
    final vorsteuerBetrieb = (saldi[1171] ?? 0);
    final nettoSchuld = umsatzsteuer - vorsteuerMaterial - vorsteuerBetrieb;
    result.add({
      'quartal': q,
      'umsatz': (umsatz * 100).roundToDouble() / 100,
      'umsatzsteuer': (umsatzsteuer * 100).roundToDouble() / 100,
      'vorsteuer_material': (vorsteuerMaterial * 100).roundToDouble() / 100,
      'vorsteuer_betrieb': (vorsteuerBetrieb * 100).roundToDouble() / 100,
      'netto_mwst_schuld': (nettoSchuld * 100).roundToDouble() / 100,
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
/// Das Ergebnis wird berechnet (Klasse 3–8) und im Eigenkapital als
/// Gewinnvortrag (Vorjahre) + Jahresergebnis (laufendes Jahr) gezeigt.
final bilanzProvider = FutureProvider.family<BilanzDaten, int>((ref, jahr) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final input = _toSaldoInput(buchungen);

  final saldiBis = BilanzService.saldiPerStichtag(input, DateTime(jahr, 12, 31));
  final saldiVor =
      BilanzService.saldiPerStichtag(input, DateTime(jahr - 1, 12, 31));
  final resBis = BilanzService.kumuliertesErgebnis(saldiBis);
  final resVor = BilanzService.kumuliertesErgebnis(saldiVor);

  final kontoInfos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return BilanzService.gruppiere(
    saldiBis,
    kontoInfos,
    gewinnvortrag: resVor,
    jahresergebnis: resBis - resVor,
  );
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

/// Debitoren-Übersicht: Gesamtsaldo 1100, native offene Rechnungen,
/// historischer Aggregat und Delkredere (1109).
final debitorenUebersichtProvider = FutureProvider<Map<String, double>>((ref) async {
  final saldi = await BuchungService.getAllSaldi();
  final offeneRg = await SupabaseService.client
      .from('rechnungen')
      .select('betrag_brutto')
      .not('zahlungsstatus', 'in', '("bezahlt","abgeschrieben")');
  final nativeOffen = (offeneRg as List)
      .fold<double>(0, (s, r) => s + _toDouble(r['betrag_brutto']));
  final debitoren = saldi[1100] ?? 0;
  final delkredere = -(saldi[1109] ?? 0);
  return {
    'debitoren_total': (debitoren * 100).roundToDouble() / 100,
    'native_offen': (nativeOffen * 100).roundToDouble() / 100,
    'historisch_aggregat': ((debitoren - nativeOffen) * 100).roundToDouble() / 100,
    'delkredere': (delkredere * 100).roundToDouble() / 100,
  };
});
