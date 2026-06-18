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
  // Offene native Rechnungen: in Dart filtern (robust gegen PostgREST-in-Syntax).
  final rgRows = await SupabaseService.client
      .from('rechnungen')
      .select('betrag_brutto, zahlungsstatus');
  const erledigt = {'bezahlt', 'abgeschrieben'};
  final nativeOffen = (rgRows as List)
      .where((r) => !erledigt.contains(r['zahlungsstatus']))
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

/// Zeitraum-Key für Erfolgsrechnungs-Provider (Wert-Gleichheit via Record).
typedef Zeitraum = ({DateTime von, DateTime bis});

/// Bilanz per beliebigem Stichtag (Datum-normalisiert vom Aufrufer).
final bilanzStichtagProvider =
    FutureProvider.family<BilanzDaten, DateTime>((ref, stichtag) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final infos = konten
      .map((k) => KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ))
      .toList();
  return BilanzService.erstelle(_toSaldoInput(buchungen), infos, stichtag);
});

/// Erfolgsrechnung (Stufengliederung) über einen Zeitraum.
final erfolgsrechnungZeitraumProvider =
    FutureProvider.family<ErfolgsrechnungDaten, Zeitraum>((ref, z) async {
  final buchungen = await BuchungRepository.getAll();
  return ErfolgsrechnungService.berechne(
    _toSaldoInput(buchungen),
    von: z.von,
    bis: z.bis,
  );
});

/// Konten-Aufstellung (Klassen + Konten) über einen Zeitraum, mit Bezeichnung.
/// Enthält ALLE Konten der Klassen 3–8 aus dem Kontenrahmen — auch ohne
/// Bewegung (Saldo 0), damit „Alle Konten" wirklich vollständig ist.
final erKontenAufstellungProvider =
    FutureProvider.family<ErKontenAufstellung, Zeitraum>((ref, z) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final namen = {for (final k in konten) k.kontonummer: k.bezeichnung};

  // Salden (vorzeichenkorrigiert) nur der bebuchten Konten, Nr → Summe.
  final roh = ErfolgsrechnungService.kontenAufstellung(
      _toSaldoInput(buchungen), von: z.von, bis: z.bis);
  final summeProKonto = <int, double>{
    for (final kl in roh.klassen)
      for (final kt in kl.konten) kt.nr: kt.summe,
  };

  // Alle Kontonummern der Klassen 3–8: Kontenrahmen ∪ bebuchte Konten.
  final nrsProKlasse = <int, Set<int>>{};
  void erfasse(int nr) {
    final cls = nr ~/ 1000;
    if (cls < 3 || cls > 8) return;
    (nrsProKlasse[cls] ??= <int>{}).add(nr);
  }

  for (final k in konten) {
    erfasse(k.kontonummer);
  }
  summeProKonto.keys.forEach(erfasse);

  final klassen = <ErKlasse>[];
  for (final cls in [3, 4, 5, 6, 7, 8]) {
    final nrs = nrsProKlasse[cls];
    if (nrs == null || nrs.isEmpty) continue;
    final sortiert = nrs.toList()..sort();
    klassen.add(ErKlasse(cls, [
      for (final nr in sortiert)
        ErKonto(nr, summeProKonto[nr] ?? 0, bezeichnung: namen[nr] ?? '—'),
    ]));
  }
  return ErKontenAufstellung(klassen);
});
