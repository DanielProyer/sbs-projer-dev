import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/bank_waechter.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/konto_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerjahr_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerzahlung_repository.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/buchung_nachhol_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/saldo_expansion.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';
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
  // Seitenweise — ein Geschäftsjahr kann >1000 Buchungen haben (PostgREST-Cap).
  final buchungen = <Map<String, dynamic>>[];
  for (int from = 0;; from += 1000) {
    final page = await SupabaseService.client
        .from('buchungen')
        .select('quartal, soll_konto, haben_konto, mwst_konto, betrag_netto, mwst_betrag, betrag_brutto, ist_storniert, storno_von_id')
        .eq('user_id', SupabaseService.dataUserId)
        .eq('geschaeftsjahr', jahr)
        .order('id') // eindeutig sortieren, sonst verliert die Pagination Zeilen
        .range(from, from + 999);
    buchungen.addAll(List<Map<String, dynamic>>.from(page));
    if (page.length < 1000) break;
  }
  final result = <Map<String, dynamic>>[];

  for (int q = 1; q <= 4; q++) {
    final saldi = <int, double>{};
    for (final b in buchungen) {
      if (b['quartal'] != q) continue;
      // Ausschluss-Modell: stornierte Originale UND Gegenbuchungen zählen nicht.
      if (!zaehltFuerSaldo(
          istStorniert: b['ist_storniert'] == true,
          stornoVonId: b['storno_von_id'] as String?)) {
        continue;
      }
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

/// Buchungen → Saldo-Input für Bilanz/Erfolgsrechnung.
/// Öffentlich, weil auch die Steuern-Provider die ER je Jahr rechnen.
List<BuchungSaldo> toSaldoInput(List<Buchung> buchungen) => buchungen
    .map((b) => BuchungSaldo(
          sollKonto: b.sollKonto,
          habenKonto: b.habenKonto,
          betrag: b.betragBrutto,
          datum: b.datum,
          storniert: b.istStorniert,
          istGegenbuchung: b.stornoVonId != null,
          mwstKonto: b.mwstKonto,
          betragNetto: b.betragNetto,
          mwstBetrag: b.mwstBetrag,
        ))
    .toList();

/// Bank-Wächter fürs Dashboard: Journal 1020 gegen den letzten
/// Bank-Schlusssaldo + Soll-Überhänge auf Verbindlichkeitskonten
/// («Tilgung ohne Aufbau» — zweimal am 01.09.2026 gefunden: Franchise
/// Januar und Lohn August).
final bankWaechterProvider = FutureProvider<BankWaechterStand>((ref) async {
  // Nach jeder Buchung neu rechnen (gleicher Auslöser wie die Kennzahlen).
  ref.watch(buchungenStreamProvider);
  final saldi = await BuchungService.getAllSaldi();
  final verbindlichkeiten = BankWaechter.verbindlichkeitsWarnungen(saldi);

  SaldoCheck? schluss;
  DateTime? per;
  final dateien = await CamtDateiRepository.getAll();
  CamtDatei? letzte;
  for (final d in dateien) {
    if (d.schlusssaldo == null || d.zeitraumBis == null) continue;
    if (letzte == null || d.zeitraumBis!.isAfter(letzte.zeitraumBis!)) {
      letzte = d;
    }
  }
  if (letzte != null) {
    per = letzte.zeitraumBis;
    final journal = await BuchungService.bankSaldoPer(per!);
    schluss = BankWaechter.pruefeSchluss(
        clbd: letzte.schlusssaldo!, journal: journal);
  }
  return BankWaechterStand(
      schluss: schluss, per: per, verbindlichkeiten: verbindlichkeiten);
});

class BankWaechterStand {
  final SaldoCheck? schluss;
  final DateTime? per;
  final List<String> verbindlichkeiten;
  const BankWaechterStand(
      {this.schluss, this.per, required this.verbindlichkeiten});

  bool get allesImLot =>
      verbindlichkeiten.isEmpty && (schluss?.ok ?? true);
}

/// Abschlussprüfung je Jahr (15 Regeln, Spec 02.09.2026 Abschnitt 4).
/// Lädt alles vorab, damit die Regeln rein bleiben; rechnet nach jeder
/// Buchung neu.
/// `autoDispose`, weil jedes einmal gewählte Jahr sonst dauerhaft mitrechnet:
/// bei jeder Buchung würde jede je besuchte Jahres-Instanz sechs Requests
/// nachladen.
final abschlussPruefungProvider =
    FutureProvider.autoDispose.family<List<Pruefbefund>, int>((ref, jahr) async {
  // Buchungen aus dem laufenden Stream — nicht zusätzlich per Repository
  // laden, das wäre derselbe Datensatz ein zweites Mal.
  final buchungen = await ref.watch(buchungenStreamProvider.future);
  // Voneinander unabhängig — parallel laden, sonst summieren sich sechs
  // Roundtrips zur Wartezeit.
  final (konten, dateien, offene, ohneJahr, docs, steuerjahre, unverbucht) =
      await (
    KontoRepository.getAll(),
    CamtDateiRepository.getAll(),
    RechnungRepository.getOffene(),
    SteuerzahlungRepository.getNichtZugeordnet(),
    DokumentRepository.getAll(bereich: 'steuern', jahr: jahr),
    SteuerjahrRepository.getAll(),
    BuchungNachholService.fuerAbschluss(),
  ).wait;
  final statusListe =
      steuerjahre.where((s) => s.jahr == jahr).map((s) => s.status).toList();
  // Rechnung steht auf «offen», obwohl der Zahlungseingang (Haben 1100) auf
  // sie gebucht ist. Erst die SUMME aller Eingänge zählt — eine Teilzahlung
  // oder eine Skonto-Differenz ist kein falscher Status. Stornierte Buchungen
  // und Storno-Gegenbuchungen zählen nicht mit (`zaehltFuerSaldo`).
  final bruttoJeRechnung = {for (final r in offene) r.id: r.betragBrutto};
  final gezahlt = <String, double>{};
  for (final b in buchungen) {
    if (!zaehltFuerSaldo(
        istStorniert: b.istStorniert, stornoVonId: b.stornoVonId)) {
      continue;
    }
    if (b.habenKonto != 1100) continue;
    final id = b.belegId;
    if (id == null || !bruttoJeRechnung.containsKey(id)) continue;
    gezahlt[id] = (gezahlt[id] ?? 0) + b.betragBrutto;
  }
  final mitZahlung = {
    for (final e in gezahlt.entries)
      // 5 Rappen Toleranz: gerundete Kundenrechnungen treffen den Brutto-
      // betrag nicht auf den Rappen genau.
      if (e.value >= bruttoJeRechnung[e.key]! - 0.05) e.key,
  };
  return AbschlussPruefService.pruefe(AbschlussKontext(
    jahr: jahr,
    heute: DateTime.now(),
    buchungen: toSaldoInput(buchungen),
    konten: konten
        .map((k) => KontoInfo(
              kontonummer: k.kontonummer,
              bezeichnung: k.bezeichnung,
              kategorie: k.kategorie ?? '—',
            ))
        .toList(),
    camtDateien: [
      for (final d in dateien)
        if (d.zeitraumVon != null && d.zeitraumBis != null)
          CamtDateiInfo(
            von: d.zeitraumVon!,
            bis: d.zeitraumBis!,
            anfangssaldo: d.anfangssaldo,
            schlusssaldo: d.schlusssaldo,
          ),
    ],
    offeneRechnungen: offene
        .map((r) => OffeneRechnungInfo(
              id: r.id,
              datum: r.rechnungsdatum,
              brutto: r.betragBrutto,
            ))
        .toList(),
    steuerbuchungenOhneJahr: ohneJahr.length,
    dokumentTypen: docs.map((d) => d.typ).toSet(),
    steuerjahrStatus: statusListe.isEmpty ? 'offen' : statusListe.first,
    offeneRechnungenMitZahlung: mitZahlung,
    unverbuchteReinigungen: unverbucht,
  ));
});

/// Debitoren-Übersicht: Gesamtsaldo 1100, native offene Rechnungen,
/// historischer Aggregat und Delkredere (1109).
final debitorenUebersichtProvider = FutureProvider<Map<String, double>>((ref) async {
  final saldi = await BuchungService.getAllSaldi();
  // Offene native Rechnungen: in Dart filtern (robust gegen PostgREST-in-Syntax).
  // Seitenweise — PostgREST deckelt sonst bei 1000 Rechnungen.
  final rgRows = <Map<String, dynamic>>[];
  for (int from = 0;; from += 1000) {
    final page = await SupabaseService.client
        .from('rechnungen')
        .select('betrag_brutto, zahlungsstatus')
        .order('id') // eindeutig sortieren, sonst verliert die Pagination Zeilen
        .range(from, from + 999);
    rgRows.addAll(List<Map<String, dynamic>>.from(page));
    if (page.length < 1000) break;
  }
  const erledigt = {'bezahlt', 'abgeschrieben'};
  final nativeOffen = rgRows
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
  return BilanzService.erstelle(toSaldoInput(buchungen), infos, stichtag);
});

/// Erfolgsrechnung (Stufengliederung) über einen Zeitraum.
final erfolgsrechnungZeitraumProvider =
    FutureProvider.family<ErfolgsrechnungDaten, Zeitraum>((ref, z) async {
  final buchungen = await BuchungRepository.getAll();
  return ErfolgsrechnungService.berechne(
    toSaldoInput(buchungen),
    von: z.von,
    bis: z.bis,
  );
});

/// Konten-Aufstellung (Klassen + bebuchte Konten) über einen Zeitraum, mit
/// Bezeichnung. Nur Konten mit Bewegung im Zeitraum.
final erKontenAufstellungProvider =
    FutureProvider.family<ErKontenAufstellung, Zeitraum>((ref, z) async {
  final buchungen = await BuchungRepository.getAll();
  final konten = await KontoRepository.getAll();
  final namen = {for (final k in konten) k.kontonummer: k.bezeichnung};
  final roh = ErfolgsrechnungService.kontenAufstellung(
      toSaldoInput(buchungen), von: z.von, bis: z.bis);
  final klassen = roh.klassen
      .map((kl) => ErKlasse(
            kl.klasse,
            kl.konten
                .map((kt) => kt.withBezeichnung(namen[kt.nr] ?? '—'))
                .toList(),
          ))
      .toList();
  return ErKontenAufstellung(klassen);
});
