import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/besuch_dauer.dart';
import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/core/util/einsatz_faellig.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';
import 'package:sbs_projer_app/data/repositories/fahrzeit_repository.dart';
import 'package:sbs_projer_app/data/repositories/region_repository.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

// FaelligkeitsStatus lebt seit 29.07.2026 in core/util/tour_filter.dart (der
// Tourfilter braucht ihn, ohne die Provider zu laden). Re-Export, damit die
// bestehenden Import-Stellen unverändert bleiben.
export 'package:sbs_projer_app/core/util/tour_filter.dart'
    show FaelligkeitsStatus, stoerungOffen, montageOffen;

// ─── Regionen ───

final regionenStreamProvider = StreamProvider<List<RegionLocal>>((ref) {
  return RegionRepository.watchAll();
});

final regionenProvider = Provider<List<RegionLocal>>((ref) {
  return ref.watch(regionenStreamProvider).valueOrNull ?? [];
});

// ─── Fälligkeits-Status ───

int? _rhythmusTage(String rhythmus) {
  switch (rhythmus) {
    case '4-Wochen':
      return 28;
    case '6-Wochen':
      return 42;
    case '2-Monate':
      return 60;
    case '3-Monate':
      return 90;
    case '6-Monate':
      return 180;
    case 'Jährlich':
      return 365;
    default:
      return null; // auf-Abruf, Selbstreiniger
  }
}

/// Baut eine Map: anlageId → serviceArt der letzten Reinigung
Map<String, String?> _buildLetzteServiceArtMap(
  List<ReinigungLocal> reinigungen,
) {
  final sorted = List.of(reinigungen)
    ..sort((a, b) => b.datum.compareTo(a.datum));
  final map = <String, String?>{};
  for (final r in sorted) {
    map.putIfAbsent(r.anlageId, () => r.serviceArt);
    for (final id in r.anlageIds) {
      map.putIfAbsent(id, () => r.serviceArt);
    }
  }
  return map;
}

// ─── Saisonale Fälligkeit ───

const _saisonVorlaufTage = 7; // 1 Woche

/// Prüft ob eine saisonale Fälligkeit vorliegt (Endreinigung / Eröffnung),
/// abgeleitet aus den Saison-/Ferien-Übergängen des Betriebs.
FaelligkeitsStatus? _getSaisonFaelligkeit(
  AnlageLocal anlage,
  DateTime datum,
  BetriebLocal betrieb,
  String? letzteServiceArt,
) {
  // --- Endreinigung: qualifizierte Schliessung im Vorlauf, noch nicht erledigt ---
  if (letzteServiceArt != 'endreinigung') {
    final s = qualifizierteSchliessung(betrieb, datum);
    if (s != null) {
      final tage = s.datum.difference(datum).inDays;
      if (tage >= 0 && tage <= _saisonVorlaufTage) {
        return FaelligkeitsStatus.endreinigungFaellig;
      }
    }
  }

  // --- Eröffnungsservice: Wiedereröffnung steht bevor (Fenster 7 Tage).
  // Nur solange in der Pause NICHT gereinigt wurde — auch die Endreinigung
  // selbst zählt als Pausen-Reinigung, wenn sie in der Schliessung lag
  // (Muloin 21.07.2026: Endreinigung 30.06. IN den Ferien 26.06.–27.07.).
  // NACH dem Start übernimmt die reguläre Uhr mit Anker = Wiedereröffnung
  // (faelligkeitsAnker) — das frühere ewige eroeffnungFaellig liess 17
  // offene Betriebe unsichtbar.
  if (letzteServiceArt == 'endreinigung' || letzteServiceArt == null) {
    final letzte = anlage.letzteReinigung;
    if (letzte != null && istInSchliessung(betrieb, letzte)) return null;
    final ab = letzte ?? datum.subtract(const Duration(days: 365));
    final oeffnung = oeffnungNach(betrieb, ab);
    if (oeffnung != null) {
      final tage = oeffnung.difference(datum).inDays;
      if (tage >= 0 && tage <= _saisonVorlaufTage) {
        return FaelligkeitsStatus.eroeffnungFaellig;
      }
    }
  }

  return null;
}

// ─── Fälligkeit berechnen ───

FaelligkeitsStatus getFaelligkeit(
  AnlageLocal anlage,
  DateTime datum, {
  BetriebLocal? betrieb,
  String? letzteServiceArt,
}) {
  // Saisonale Fälligkeit hat Vorrang
  if (betrieb != null) {
    final saison = _getSaisonFaelligkeit(
      anlage,
      datum,
      betrieb,
      letzteServiceArt,
    );
    if (saison != null) return saison;
  }

  // Regulärer Rhythmus
  final tage = _rhythmusTage(anlage.reinigungRhythmus);
  if (tage == null) return FaelligkeitsStatus.nichtFaellig;

  DateTime? naechste = anlage.naechsteReinigung;
  if (naechste == null && anlage.letzteReinigung != null) {
    naechste = anlage.letzteReinigung!.add(Duration(days: tage));
  }
  if (naechste == null) {
    return FaelligkeitsStatus.ueberfaellig;
  }

  // Uhr-Anker (Regel Daniel 17.07.2026): War der Betrieb nach der letzten
  // Reinigung geschlossen, zählt der Rhythmus ab der Wiedereröffnung — für
  // JEDE Service-Art (Endreinigung am Schluss, Eröffnungsreinigung vor dem
  // Start). Nur nach hinten korrigierend: ein überholtes naechsteReinigung
  // aus der Zeit vor der Pause (z.B. 27.04. bei Wiedereröffnung 06.06.) wird
  // überstimmt. Anker == null (Saisondaten fehlen) meldet die Warnleiste im
  // Tourenplan (Task 3).
  if (betrieb != null && anlage.letzteReinigung != null) {
    final anker = faelligkeitsAnker(betrieb, anlage.letzteReinigung!);
    if (anker != null) {
      final abAnker = anker.add(Duration(days: tage));
      if (abAnker.isAfter(naechste)) naechste = abAnker;
    }
  }

  // Fälligkeitsstufen relativ zum Soll-Termin (naechste):
  //   ab Soll        (z.B. 4 Wochen bei 4-Wochen-Rhythmus) → bald fällig
  //   ab Soll + 1 W  (5 Wochen)                            → fällig
  //   ab Soll + 2 W  (6 Wochen)                            → überfällig
  final diff = datum.difference(naechste).inDays;
  if (diff >= 14) return FaelligkeitsStatus.ueberfaellig;
  if (diff >= 7) return FaelligkeitsStatus.faellig;
  if (diff >= 0) return FaelligkeitsStatus.baldFaellig;
  return FaelligkeitsStatus.nichtFaellig;
}

// ─── Betrieb "offen" Check ───

/// Betrieb an diesem Tag betrieblich offen (aktiv, keine Ferien, in Saison,
/// kein Ruhetag). Delegiert an den kanonischen Helfer in touren_saison.
bool isBetriebOffen(BetriebLocal b, DateTime datum) => istOffenerTag(b, datum);

// ─── Betrieb "aktiv" Check (ohne Ruhetag, für Fällig-Tab) ───

bool _isBetriebAktiv(BetriebLocal b, DateTime datum) {
  if (b.status != 'aktiv') return false;

  // Ferien-Check
  if (istInFerien(b, datum)) return false;

  // Saison-Check — dieselbe Definition wie in touren_saison.dart. Die Logik
  // lag hier früher ein zweites Mal und lief auseinander: sie verlangte beide
  // Datumsangaben, sodass ein Betrieb mit laufender, noch offener Saison
  // (Ende leer) still aus dem Tourenplan fiel — Fall Grischa Davos.
  //
  // Saisonpause → nicht aktiv für reguläre Fälligkeit. Eröffnungs-/
  // Endreinigung wird über _getSaisonFaelligkeit gesteuert und bypassed
  // diesen Filter.
  if (!istInAktiverSaison(b, datum)) return false;

  return true;
}

// ─── Fällige Anlagen Provider ───

/// Anlagen für die Tourenplanung, sortiert nach Dringlichkeit.
///
/// [mitNichtFaelligen] nimmt auch Anlagen mit, deren nächste Reinigung noch
/// aussteht — das braucht der Filter «Alle» im Tourenplan, etwa um eine
/// Anlage mitzunehmen, weil man ohnehin in der Region ist. Sie landen durch
/// die Sortierung nach [FaelligkeitsStatus.index] am Ende der Liste.
List<AnlageLocal> _anlagenFuerTour(
  Ref ref,
  DateTime datum, {
  required bool mitNichtFaelligen,
}) {
  final anlagen = ref.watch(anlagenProvider);
  final betriebe = ref.watch(betriebeProvider);
  final reinigungen = ref.watch(reinigungenProvider);

  // Betrieb-Lookup: serverId/routeId → BetriebLocal
  final betriebMap = <String, BetriebLocal>{};
  for (final b in betriebe) {
    betriebMap[b.routeId] = b;
    if (b.serverId != null) betriebMap[b.serverId!] = b;
  }

  final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);

  return anlagen.where((a) {
    if (a.status != 'aktiv') return false;
    final betrieb = betriebMap[a.betriebId];
    final serviceArt = a.serverId != null ? serviceArtMap[a.serverId!] : null;
    final faelligkeit = getFaelligkeit(
      a,
      datum,
      betrieb: betrieb,
      letzteServiceArt: serviceArt,
    );
    if (faelligkeit == FaelligkeitsStatus.nichtFaellig && !mitNichtFaelligen) {
      return false;
    }

    // Saisonale Einträge immer anzeigen (auch wenn Betrieb in Pause)
    if (faelligkeit == FaelligkeitsStatus.endreinigungFaellig ||
        faelligkeit == FaelligkeitsStatus.eroeffnungFaellig) {
      return true;
    }

    // Betrieb aktiv? (ohne Ruhetag-Check)
    if (betrieb != null && !_isBetriebAktiv(betrieb, datum)) return false;

    return true;
  }).toList()..sort((a, b) {
    // Überfällig zuerst
    final betriebA = betriebMap[a.betriebId];
    final betriebB = betriebMap[b.betriebId];
    final saA = a.serverId != null ? serviceArtMap[a.serverId!] : null;
    final saB = b.serverId != null ? serviceArtMap[b.serverId!] : null;
    final fa = getFaelligkeit(
      a,
      datum,
      betrieb: betriebA,
      letzteServiceArt: saA,
    ).index;
    final fb = getFaelligkeit(
      b,
      datum,
      betrieb: betriebB,
      letzteServiceArt: saB,
    ).index;
    return fa.compareTo(fb);
  });
}

/// Fällige Anlagen — Grundlage für den Dashboard-Zähler.
final faelligeAnlagenProvider = Provider.family<List<AnlageLocal>, DateTime>(
  (ref, datum) => _anlagenFuerTour(ref, datum, mitNichtFaelligen: false),
);

/// Wie [faelligeAnlagenProvider], nur schaltbar um die nicht fälligen Anlagen.
final tourAnlagenProvider =
    Provider.family<List<AnlageLocal>, ({DateTime datum, bool alle})>(
      (ref, k) => _anlagenFuerTour(ref, k.datum, mitNichtFaelligen: k.alle),
    );

// ─── Ableitungen aus fälligen Anlagen (Besuchs-Bündelung, Plan-Übernahme) ───
//
// Review 29.07.2026: Besuchs-Bündelung und Plan-Übernahme (Task 7) dürfen
// NICHT die (gefilterte) Fällig-Eintragsliste als Fälligkeits-Quelle nehmen
// — seit v0.54.17 lässt der «Alle»-Filter dort auch nicht fällige Anlagen
// durch. `faelligeAnlagenProvider` schliesst nicht fällige Anlagen dagegen
// hart aus (`mitNichtFaelligen: false`), unabhängig vom UI-Filterstand.
// Reine Funktionen, damit sie ohne Provider-Verdrahtung testbar sind.

/// RouteIds der fälligen Anlagen eines Betriebs — Grundlage dafür, welche
/// Geschwister-Anlagen ein neuer Besuchs-Block automatisch mitnimmt.
List<String> faelligeAnlagenRouteIdsFuerBetrieb(
  List<AnlageLocal> faelligeAnlagen,
  String betriebId,
) => [
  for (final a in faelligeAnlagen)
    if (a.betriebId == betriebId) a.routeId,
];

/// BetriebIds mit mindestens einer fälligen Anlage — Grundlage für die
/// „übernommen"-Markierung bei der Plan-Übernahme von einem anderen Datum.
Set<String> faelligeBetriebIds(List<AnlageLocal> faelligeAnlagen) => {
  for (final a in faelligeAnlagen) a.betriebId,
};

// ─── Tour-Vorschlag Provider (Reinigungen von vor ~28 Tagen) ───

final tourVorschlagProvider = Provider.family<List<ReinigungLocal>, DateTime>((
  ref,
  datum,
) {
  final reinigungen = ref.watch(reinigungenProvider);
  final referenz = datum.subtract(const Duration(days: 28));
  final von = referenz.subtract(const Duration(days: 2));
  final bis = referenz.add(const Duration(days: 2));

  return reinigungen.where((r) {
    return r.datum.isAfter(von) && r.datum.isBefore(bis);
  }).toList()..sort((a, b) => a.datum.compareTo(b.datum));
});

// ─── Fällige Anlagen Count ───

final faelligeAnlagenCountProvider = Provider<int>((ref) {
  final heute = DateTime.now();
  final datum = DateTime(heute.year, heute.month, heute.day);
  return ref.watch(faelligeAnlagenProvider(datum)).length;
});

// ─── TourEintrag (UI-only Wrapper für alle planbaren Typen) ───

enum TourEintragTyp { reinigung, stoerung, montage, heigenie }

/// Sentinel für `copyWith` auf nullable Feldern: unterscheidet „Parameter
/// nicht angegeben" (Feld bleibt unverändert) von „Parameter explizit auf
/// null gesetzt" (Feld wird geleert), was mit einem simplen `?? this.x`
/// nicht ginge.
const _unset = Object();

class TourEintrag {
  final TourEintragTyp typ;
  final String id;
  final String? betriebId;
  // WICHTIG: anlageId bleibt bestehen (nicht durch anlageIds ersetzt) und
  // wird weiterhin befüllt (= erste Anlage von anlageIds), damit bestehende
  // Screens (z.B. „Reinigung starten") unverändert funktionieren. Fachlich
  // führend ist ab jetzt anlageIds — anlageId ist nur noch die Kompatibilitäts-
  // Ansicht darauf.
  final String? anlageId;
  final String betriebName;
  final String? betriebOrt;
  final String? regionId;
  final String beschreibung;
  final FaelligkeitsStatus? faelligkeit;
  final DateTime? datum;
  final List<String> ruhetage;
  final String? servicezeit;
  final bool istAutoTermin;
  final DateTime? zielDatum;
  // ─── Besuchs-Block (Task 5, Spec Abschnitt 1) ───
  /// Alle Anlagen dieses Besuchs (Reinigung). Fachlich führend; `anlageId`
  /// bleibt als Kompatibilitäts-Feld daneben bestehen (siehe oben).
  final List<String> anlageIds;

  /// Manuelle Übersteuerung der geschätzten Besuchsdauer.
  final int? dauerMinuten;

  /// Termin-Anker „frühestens HH:mm" — erzeugt im Zeitplan ggf. Wartezeit.
  final String? ankerZeit;

  /// Aus einer Plan-Übernahme entstanden, heute nicht fällig → grau markiert.
  final bool uebernommen;

  // ─── Einsatzplanung (Migration 163, Störung/Montage) ───
  /// Rohwerte aus `geplant_am`/`geplant_zeit`/`geplant_dauer_min` — nur zum
  /// Anzeigen (`planungsText`) und als Vorbelegung fürs Einplanen-Sheet.
  /// Fachlich führend für die Zeitachse ist weiterhin `ankerZeit` (oben).
  final DateTime? geplantAm;
  final String? geplantZeit;
  final int? geplantDauerMin;

  const TourEintrag({
    required this.typ,
    required this.id,
    this.betriebId,
    this.anlageId,
    required this.betriebName,
    this.betriebOrt,
    this.regionId,
    required this.beschreibung,
    this.faelligkeit,
    this.datum,
    this.ruhetage = const [],
    this.servicezeit,
    this.istAutoTermin = false,
    this.zielDatum,
    this.anlageIds = const [],
    this.dauerMinuten,
    this.ankerZeit,
    this.uebernommen = false,
    this.geplantAm,
    this.geplantZeit,
    this.geplantDauerMin,
  });

  /// Version für den gespeicherten Plan (kein Auto-Marker mehr).
  TourEintrag alsPlanEintrag() => TourEintrag(
    typ: typ,
    id: id,
    betriebId: betriebId,
    anlageId: anlageId,
    betriebName: betriebName,
    betriebOrt: betriebOrt,
    regionId: regionId,
    beschreibung: beschreibung,
    faelligkeit: faelligkeit,
    datum: datum,
    ruhetage: ruhetage,
    servicezeit: servicezeit,
    anlageIds: anlageIds,
    dauerMinuten: dauerMinuten,
    ankerZeit: ankerZeit,
    uebernommen: uebernommen,
    geplantAm: geplantAm,
    geplantZeit: geplantZeit,
    geplantDauerMin: geplantDauerMin,
  );

  /// Kopie mit neuer `id`, alle anderen Felder unverändert. Nur für die
  /// Plan-Übernahme von einem anderen Datum (Task 7): dort ist `id` NICHT
  /// fest, weil zwei Übernahmen desselben Quelltags sonst auf dieselbe ID
  /// kollidieren würden — `copyWith` erlaubt das bewusst nicht (siehe dort).
  TourEintrag mitId(String neueId) => TourEintrag(
    typ: typ,
    id: neueId,
    betriebId: betriebId,
    anlageId: anlageId,
    betriebName: betriebName,
    betriebOrt: betriebOrt,
    regionId: regionId,
    beschreibung: beschreibung,
    faelligkeit: faelligkeit,
    datum: datum,
    ruhetage: ruhetage,
    servicezeit: servicezeit,
    istAutoTermin: istAutoTermin,
    zielDatum: zielDatum,
    anlageIds: anlageIds,
    dauerMinuten: dauerMinuten,
    ankerZeit: ankerZeit,
    uebernommen: uebernommen,
    geplantAm: geplantAm,
    geplantZeit: geplantZeit,
    geplantDauerMin: geplantDauerMin,
  );

  /// Kopie mit geänderten Feldern. `typ`/`id` sind fest (Identität eines
  /// Eintrags ändert sich nicht). Für die nullable Felder `dauerMinuten`
  /// und `ankerZeit` wird ein Sentinel (`_unset`) genutzt, damit man sie
  /// gezielt auf `null` zurücksetzen kann (z.B. Anker entfernen) statt nur
  /// „nicht angegeben" ausdrücken zu können.
  TourEintrag copyWith({
    String? betriebId,
    String? anlageId,
    String? betriebName,
    String? betriebOrt,
    String? regionId,
    String? beschreibung,
    FaelligkeitsStatus? faelligkeit,
    DateTime? datum,
    List<String>? ruhetage,
    String? servicezeit,
    bool? istAutoTermin,
    DateTime? zielDatum,
    List<String>? anlageIds,
    Object? dauerMinuten = _unset,
    Object? ankerZeit = _unset,
    bool? uebernommen,
  }) => TourEintrag(
    typ: typ,
    id: id,
    betriebId: betriebId ?? this.betriebId,
    anlageId: anlageId ?? this.anlageId,
    betriebName: betriebName ?? this.betriebName,
    betriebOrt: betriebOrt ?? this.betriebOrt,
    regionId: regionId ?? this.regionId,
    beschreibung: beschreibung ?? this.beschreibung,
    faelligkeit: faelligkeit ?? this.faelligkeit,
    datum: datum ?? this.datum,
    ruhetage: ruhetage ?? this.ruhetage,
    servicezeit: servicezeit ?? this.servicezeit,
    istAutoTermin: istAutoTermin ?? this.istAutoTermin,
    zielDatum: zielDatum ?? this.zielDatum,
    anlageIds: anlageIds ?? this.anlageIds,
    dauerMinuten: identical(dauerMinuten, _unset)
        ? this.dauerMinuten
        : dauerMinuten as int?,
    ankerZeit: identical(ankerZeit, _unset)
        ? this.ankerZeit
        : ankerZeit as String?,
    uebernommen: uebernommen ?? this.uebernommen,
    geplantAm: geplantAm,
    geplantZeit: geplantZeit,
    geplantDauerMin: geplantDauerMin,
  );
}

// ─── Filter-State ───

final selectedRegionenProvider = StateProvider<Set<String>>((ref) => {});

/// Fälligkeits-Auswahl der Tourenplanung.
///
/// Standard: alles ausser «Alle» — überfällig, fällig, bald fällig und die
/// saisonalen Fenster. «Bald fällig» ist bewusst an (Regel Daniel 22.07.):
/// Beim Planen einer Zukunfts-Tour sind genau die an dem Tag reif werdenden
/// Kunden «bald fällig» — ohne sie wirkte das Planungsdatum wirkungslos
/// (verifiziert: 32 Anlagen im +7-Tage-Fenster unsichtbar). Eröffnung und
/// Endreinigung liegen seit 29.07.2026 zusammen unter «Saison».
final selectedFaelligkeitProvider = StateProvider<Set<TourFilter>>(
  (ref) => standardTourFilter,
);

// ─── Betrieb-Lookup Helper ───

Map<String, BetriebLocal> _buildBetriebMap(List<BetriebLocal> betriebe) {
  final map = <String, BetriebLocal>{};
  for (final b in betriebe) {
    map[b.routeId] = b;
    if (b.serverId != null) map[b.serverId!] = b;
  }
  return map;
}

/// Betrieb nachschlagen — über routeId oder serverId.
///
/// Anzeigen wie Ruhetage und Servicezeit holen ihre Werte darüber frisch aus
/// den Stammdaten. Im gespeicherten Tagesplan liegen sie nur als Kopie vom
/// Zeitpunkt des Speicherns; eine später gepflegte Servicezeit tauchte dort
/// nie auf (Fall Conditorei Fischer, 29.07.2026).
final betriebLookupProvider = Provider<Map<String, BetriebLocal>>(
  (ref) => _buildBetriebMap(ref.watch(betriebeProvider)),
);

/// Servicezeit-Text eines Betriebs; null, wenn nichts erfasst ist.
String? servicezeitAus(BetriebLocal? b) => _servicezeitAus(b);

/// Tatsächliche (abgeschlossene) Reinigungen eines Tages als Besuchs-Blöcke,
/// sortiert nach Start-Uhrzeit (ohne Uhrzeit ans Ende). Grundlage der
/// Vergangenheits-Ansicht im Tagesplan-Tab UND der Plan-Übernahme von einem
/// Datum — Daniel 31.07.2026: «vergangene Pläne sind nicht mehr relevant,
/// nur die tatsächlichen Tagesdaten». Störungen/Montagen bewusst nicht
/// enthalten.
final tatsaechlicheReinigungenAlsEintraegeProvider =
    Provider.family<List<TourEintrag>, DateTime>((ref, datum) {
      final betriebMap = _buildBetriebMap(ref.watch(betriebeProvider));
      final desTages =
          [
            for (final r in ref.watch(reinigungenProvider))
              if (r.status == 'abgeschlossen' &&
                  r.betriebId.isNotEmpty &&
                  r.datum.year == datum.year &&
                  r.datum.month == datum.month &&
                  r.datum.day == datum.day)
                r,
          ]..sort(
            (a, b) => (minutenAusHhmm(a.uhrzeitStart) ?? 1440).compareTo(
              minutenAusHhmm(b.uhrzeitStart) ?? 1440,
            ),
          );
      return [
        for (final r in desTages)
          TourEintrag(
            typ: TourEintragTyp.reinigung,
            // `hist_`-Präfix: markiert einen tatsächlichen (historischen)
            // Besuch — der Screen leitet Taps darauf zur Reinigung statt
            // ins Block-Sheet.
            id: 'hist_${r.routeId}',
            betriebId: r.betriebId,
            anlageId: r.anlageIds.isNotEmpty
                ? r.anlageIds.first
                : (r.anlageId.isNotEmpty ? r.anlageId : null),
            anlageIds: r.anlageIds.isNotEmpty
                ? r.anlageIds
                : [if (r.anlageId.isNotEmpty) r.anlageId],
            betriebName: betriebMap[r.betriebId]?.name ?? '?',
            betriebOrt: betriebMap[r.betriebId]?.ort,
            regionId: betriebMap[r.betriebId]?.regionId,
            beschreibung: '',
            datum: r.datum,
            ruhetage: betriebMap[r.betriebId]?.ruhetage ?? const [],
            servicezeit: _servicezeitAus(betriebMap[r.betriebId]),
          ),
      ];
    });

String? _servicezeitAus(BetriebLocal? b) {
  if (b == null) return null;
  final t = servicezeitText(
    b.servicezeitMorgenAb,
    b.servicezeitMorgenBis,
    b.servicezeitNachmittagAb,
    b.servicezeitNachmittagBis,
  );
  return t.isEmpty ? null : t;
}

// ─── Vereinigte Fällig-Liste (alle Typen) ───

final faelligeEintraegeProvider = Provider.family<List<TourEintrag>, DateTime>((
  ref,
  datum,
) {
  final betriebe = ref.watch(betriebeProvider);
  final betriebMap = _buildBetriebMap(betriebe);
  final reinigungen = ref.watch(reinigungenProvider);
  final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);
  final eintraege = <TourEintrag>[];

  // 1. Fällige Anlagen → Reinigungen. Bei aktivem «Alle»-Filter kommen auch
  // die noch nicht fälligen Anlagen dazu.
  final alle = zeigtNichtFaellige(ref.watch(selectedFaelligkeitProvider));
  final faelligeAnlagen = ref.watch(
    tourAnlagenProvider((datum: datum, alle: alle)),
  );
  for (final a in faelligeAnlagen) {
    final betrieb = betriebMap[a.betriebId];
    final serviceArt = a.serverId != null ? serviceArtMap[a.serverId!] : null;
    eintraege.add(
      TourEintrag(
        typ: TourEintragTyp.reinigung,
        id: 'r_${a.routeId}',
        betriebId: a.betriebId,
        anlageId: a.routeId,
        betriebName: betrieb?.name ?? '?',
        betriebOrt: betrieb?.ort,
        regionId: betrieb?.regionId,
        beschreibung: '${a.typAnlage} · ${a.anzahlHaehne} Hähne',
        faelligkeit: getFaelligkeit(
          a,
          datum,
          betrieb: betrieb,
          letzteServiceArt: serviceArt,
        ),
        datum: a.naechsteReinigung,
        ruhetage: betrieb?.ruhetage ?? const [],
        servicezeit: _servicezeitAus(betrieb),
      ),
    );
  }

  // 2. Offene Störungen (inkl. angefangener — siehe stoerungOffen).
  // Datumsfilter (Migration 163, `core/util/einsatz_faellig.dart`): ein für
  // einen SPÄTEREN Tag eingeplanter Einsatz taucht an [datum] nicht auf —
  // ungeplante und überfällige Einsätze bleiben sichtbar.
  final stoerungen = ref.watch(stoerungenProvider);
  for (final s in stoerungen) {
    if (!stoerungOffen(s.status)) continue;
    if (!einsatzGehoertZuTag(geplantAm: s.geplantAm, tag: datum)) continue;
    final betrieb = s.betriebId != null ? betriebMap[s.betriebId!] : null;
    eintraege.add(
      TourEintrag(
        typ: TourEintragTyp.stoerung,
        id: 's_${s.routeId}',
        betriebId: s.betriebId,
        anlageId: s.anlageId,
        betriebName: betrieb?.name ?? '?',
        betriebOrt: betrieb?.ort,
        regionId: betrieb?.regionId,
        beschreibung: s.problemBeschreibung,
        datum: s.datum,
        ruhetage: betrieb?.ruhetage ?? const [],
        servicezeit: _servicezeitAus(betrieb),
        // Geplante Uhrzeit wandert als Termin-Anker in die Zeitachse — sonst
        // stünde der abgemachte Termin nirgends im Tagesplan.
        ankerZeit: s.geplantZeit,
        geplantAm: s.geplantAm,
        geplantZeit: s.geplantZeit,
        geplantDauerMin: s.geplantDauerMin,
      ),
    );
  }

  // 3. Geplante Montagen / HeiGenie (inkl. angefangener — siehe montageOffen).
  final montagen = ref.watch(montagenProvider);
  for (final m in montagen) {
    if (!montageOffen(m.status)) continue;
    if (!einsatzGehoertZuTag(geplantAm: m.geplantAm, tag: datum)) continue;
    final betrieb = m.betriebId != null ? betriebMap[m.betriebId!] : null;
    final istHeiGenie = m.montageTyp == 'heigenie_service';
    eintraege.add(
      TourEintrag(
        typ: istHeiGenie ? TourEintragTyp.heigenie : TourEintragTyp.montage,
        id: 'm_${m.routeId}',
        betriebId: m.betriebId,
        anlageId: m.anlageId,
        betriebName: betrieb?.name ?? '?',
        betriebOrt: betrieb?.ort,
        regionId: betrieb?.regionId,
        beschreibung: '${_montageTypLabel(m.montageTyp)} · ${m.beschreibung}',
        datum: m.datum,
        ruhetage: betrieb?.ruhetage ?? const [],
        servicezeit: _servicezeitAus(betrieb),
        ankerZeit: m.geplantZeit,
        geplantAm: m.geplantAm,
        geplantZeit: m.geplantZeit,
        geplantDauerMin: m.geplantDauerMin,
      ),
    );
  }

  // Sortierung: Reinigungen (nach Fälligkeit) → Störungen → Montagen
  eintraege.sort((a, b) {
    final typOrdnung = a.typ.index.compareTo(b.typ.index);
    if (typOrdnung != 0) return typOrdnung;
    if (a.faelligkeit != null && b.faelligkeit != null) {
      return a.faelligkeit!.index.compareTo(b.faelligkeit!.index);
    }
    return 0;
  });

  return eintraege;
});

// ─── Automatische Saison-Termine (Endreinigung/Eröffnung am Ziel-Tag) ───

final autoTermineProvider = Provider.family<List<TourEintrag>, DateTime>((
  ref,
  datum,
) {
  final betriebe = ref.watch(betriebeProvider);
  final betriebMap = _buildBetriebMap(betriebe);
  final anlagen = ref.watch(anlagenProvider);
  final reinigungen = ref.watch(reinigungenProvider);
  final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);
  final imPlan = ref.watch(tagesplanProvider).map((e) => e.id).toSet();
  final tag = DateTime(datum.year, datum.month, datum.day);
  final result = <TourEintrag>[];

  for (final a in anlagen) {
    if (a.status != 'aktiv') continue;
    final betrieb = betriebMap[a.betriebId];
    if (betrieb == null) continue;
    final hatUebergaenge =
        betrieb.istSaisonbetrieb || ferienStarts(betrieb).isNotEmpty;
    if (!hatUebergaenge) continue;

    final id = 'r_${a.routeId}';
    if (imPlan.contains(id)) continue;

    final letzteServiceArt = a.serverId != null
        ? serviceArtMap[a.serverId!]
        : null;

    // Endreinigung: letzter offener Tag vor der nächsten Schliessung
    if (letzteServiceArt != 'endreinigung') {
      final s = qualifizierteSchliessung(betrieb, tag);
      if (s != null) {
        final ziel = naechsterOffenerTag(betrieb, s.datum, rueckwaerts: true);
        if (ziel != null && ziel == tag) {
          result.add(
            TourEintrag(
              typ: TourEintragTyp.reinigung,
              id: id,
              betriebId: a.betriebId,
              anlageId: a.routeId,
              betriebName: betrieb.name,
              betriebOrt: betrieb.ort,
              regionId: betrieb.regionId,
              beschreibung: 'Endreinigung · ${a.typAnlage}',
              faelligkeit: FaelligkeitsStatus.endreinigungFaellig,
              ruhetage: betrieb.ruhetage,
              servicezeit: _servicezeitAus(betrieb),
              istAutoTermin: true,
              zielDatum: ziel,
            ),
          );
          continue;
        }
      }
    }

    // Eröffnung: erster offener Tag ab Wiedereröffnung (Anlage ist geschlossen).
    // Lag die Endreinigung selbst schon in der Schliessung, ist die Anlage
    // versorgt -> kein Auto-Termin (gleiche Regel wie _getSaisonFaelligkeit).
    if (letzteServiceArt == 'endreinigung' &&
        !(a.letzteReinigung != null &&
            istInSchliessung(betrieb, a.letzteReinigung!))) {
      final ab = a.letzteReinigung ?? tag.subtract(const Duration(days: 365));
      final oeffnung = oeffnungNach(betrieb, ab);
      if (oeffnung != null) {
        final ziel = naechsterOffenerTag(betrieb, oeffnung, rueckwaerts: false);
        if (ziel != null && ziel == tag) {
          result.add(
            TourEintrag(
              typ: TourEintragTyp.reinigung,
              id: id,
              betriebId: a.betriebId,
              anlageId: a.routeId,
              betriebName: betrieb.name,
              betriebOrt: betrieb.ort,
              regionId: betrieb.regionId,
              beschreibung: 'Eröffnungsservice · ${a.typAnlage}',
              faelligkeit: FaelligkeitsStatus.eroeffnungFaellig,
              ruhetage: betrieb.ruhetage,
              servicezeit: _servicezeitAus(betrieb),
              istAutoTermin: true,
              zielDatum: ziel,
            ),
          );
        }
      }
    }
  }

  return result;
});

String _montageTypLabel(String typ) {
  switch (typ) {
    case 'neumontage':
      return 'Neumontage';
    case 'demontage':
      return 'Demontage';
    case 'abaenderung':
      return 'Abänderung';
    case 'heigenie_service':
      return 'HeiGenie Service';
    case 'anlass':
      return 'Anlass';
    case 'spesen':
      return 'Spesen';
    case 'aufwandsentschaedigung':
      return 'Aufwandsentsch.';
    default:
      return typ;
  }
}

// ─── Erweiterter Vorschlag (alle Typen) ───

final tourVorschlagErweitertProvider =
    Provider.family<List<TourEintrag>, DateTime>((ref, datum) {
      final betriebe = ref.watch(betriebeProvider);
      final anlagen = ref.watch(anlagenProvider);
      final reinigungen = ref.watch(reinigungenProvider);
      final betriebMap = _buildBetriebMap(betriebe);
      final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);
      final eintraege = <TourEintrag>[];

      // Anlagen-Lookup
      final anlageMap = <String, AnlageLocal>{};
      for (final a in anlagen) {
        anlageMap[a.routeId] = a;
        if (a.serverId != null) anlageMap[a.serverId!] = a;
      }

      // 1. Reinigungen von vor ~28 Tagen
      final vorschlagReinigungen = ref.watch(tourVorschlagProvider(datum));
      final seenAnlagen = <String>{};
      for (final r in vorschlagReinigungen) {
        // Deduplizieren nach Anlage
        final aId = r.anlageIds.isNotEmpty ? r.anlageIds.first : r.betriebId;
        if (!seenAnlagen.add(aId)) continue;

        final anlage = anlageMap[aId];
        if (anlage != null && anlage.status != 'aktiv') continue;

        final betrieb = betriebMap[r.betriebId];
        if (betrieb != null && !isBetriebOffen(betrieb, datum)) continue;

        eintraege.add(
          TourEintrag(
            typ: TourEintragTyp.reinigung,
            id: 'r_$aId',
            betriebId: r.betriebId,
            anlageId: aId,
            betriebName: betrieb?.name ?? '?',
            betriebOrt: betrieb?.ort,
            regionId: betrieb?.regionId,
            beschreibung: anlage != null
                ? '${anlage.typAnlage} · ${anlage.anzahlHaehne} Hähne'
                : 'Reinigung',
            faelligkeit: anlage != null
                ? getFaelligkeit(
                    anlage,
                    datum,
                    betrieb: betrieb,
                    letzteServiceArt: anlage.serverId != null
                        ? serviceArtMap[anlage.serverId!]
                        : null,
                  )
                : null,
            datum: r.datum,
            ruhetage: betrieb?.ruhetage ?? const [],
            servicezeit: _servicezeitAus(betrieb),
          ),
        );
      }

      // 2. Offene Störungen (immer relevant)
      final stoerungen = ref.watch(stoerungenProvider);
      for (final s in stoerungen) {
        if (s.status != 'offen') continue;
        final betrieb = s.betriebId != null ? betriebMap[s.betriebId!] : null;
        eintraege.add(
          TourEintrag(
            typ: TourEintragTyp.stoerung,
            id: 's_${s.routeId}',
            betriebId: s.betriebId,
            anlageId: s.anlageId,
            betriebName: betrieb?.name ?? '?',
            betriebOrt: betrieb?.ort,
            regionId: betrieb?.regionId,
            beschreibung: s.problemBeschreibung,
            datum: s.datum,
            ruhetage: betrieb?.ruhetage ?? const [],
            servicezeit: _servicezeitAus(betrieb),
          ),
        );
      }

      // 3. Montagen an diesem Datum
      final montagen = ref.watch(montagenProvider);
      for (final m in montagen) {
        if (m.status != 'geplant') continue;
        final mDatum = DateTime(m.datum.year, m.datum.month, m.datum.day);
        final selDate = DateTime(datum.year, datum.month, datum.day);
        if (mDatum != selDate) continue;

        final betrieb = m.betriebId != null ? betriebMap[m.betriebId!] : null;
        final istHeiGenie = m.montageTyp == 'heigenie_service';
        eintraege.add(
          TourEintrag(
            typ: istHeiGenie ? TourEintragTyp.heigenie : TourEintragTyp.montage,
            id: 'm_${m.routeId}',
            betriebId: m.betriebId,
            anlageId: m.anlageId,
            betriebName: betrieb?.name ?? '?',
            betriebOrt: betrieb?.ort,
            regionId: betrieb?.regionId,
            beschreibung:
                '${_montageTypLabel(m.montageTyp)} · ${m.beschreibung}',
            datum: m.datum,
            ruhetage: betrieb?.ruhetage ?? const [],
            servicezeit: _servicezeitAus(betrieb),
          ),
        );
      }

      return eintraege;
    });

// ─── Zeitachse: Dauer-Historie, Fahrzeiten, Arbeitstag (Task 6) ───

/// Dauer-Historie je Betrieb (Schlüssel = `betriebId` der Reinigung, also die
/// Server-Id — dieselbe Konvention wie `AnlageLocal.betriebId` und
/// `TourEintrag.betriebId`). Grundlage der Schätzung `geschaetzteDauer`.
///
/// Anlagenzahl eines historischen Besuchs = Zusatzanlagen (`anlageIds`) + die
/// Hauptanlage. Besuche ohne brauchbare Dauer fallen raus, damit sie den
/// Median nicht nach unten ziehen.
final besuchHistorieProvider = Provider<Map<String, List<BesuchHistorie>>>((
  ref,
) {
  final reinigungen = ref.watch(reinigungenProvider);
  final map = <String, List<BesuchHistorie>>{};
  for (final r in reinigungen) {
    final dauer = dauerAusReinigung(
      dauerMinuten: r.dauerMinuten,
      start: r.uhrzeitStart,
      ende: r.uhrzeitEnde,
    );
    if (dauer == null) continue;
    final anlagenZahl = (r.anlageIds.isNotEmpty ? r.anlageIds.length : 0) + 1;
    (map[r.betriebId] ??= []).add((
      anlagenZahl: anlagenZahl,
      dauerMinuten: dauer,
    ));
  }
  return map;
});

/// Alle gelernten/gerouteten Fahrzeiten des Users in einer Abfrage
/// (`'$von>$nach'` → Minuten + Quelle). Lesen über
/// `FahrzeitRepository.ausMap`, das auch die Gegenrichtung prüft.
final fahrzeitenMapProvider = FutureProvider<Map<String, FahrzeitEintrag>>(
  (ref) => FahrzeitRepository.ladeAlle(),
);

/// Arbeitstag-Rahmen je Tag: Beginn (Start der Zeitachse), Ende, km-Stand
/// und die per GPS erfasste Tagesstart-Position.
///
/// Die Position kommt vom «Arbeitsbeginn»-Knopf auf dem Startbildschirm
/// (Daniel 29.07.2026): Er startet nicht immer am festen Startort (Zuhause
/// Domat/Ems), sondern oft anderswo (Chur) — Anfahrt/Heimweg der Zeitachse
/// rechnen darum bevorzugt von hier, der feste Startort ist nur Rückfall.
/// `km` = km-Stand am Abend (historischer Name), `kmStart` = km-Stand beim
/// Arbeitsbeginn — beide zusammen ergeben die Tages-km ohne Privatfahrten
/// (Daniel 29.07.2026). lat/lng = Startposition, endLat/endLng = Endposition.
typedef Arbeitstag = ({
  String beginn,
  String? ende,
  int? km,
  int? kmStart,
  double? lat,
  double? lng,
  double? endLat,
  double? endLng,

  /// Summe aller Pausen des Tages (Migration 159).
  int? pauseMinuten,

  /// 'HH:mm' einer noch LAUFENDEN Pause; null = keine Pause aktiv. Damit
  /// weiss der Knopf auch nach einem App-Neustart, dass die Pause läuft.
  String? pauseStart,
});

final arbeitstagProvider = StateProvider.family<Arbeitstag, DateTime>(
  (ref, datum) => (
    beginn: '06:00',
    ende: null,
    km: null,
    kmStart: null,
    lat: null,
    lng: null,
    endLat: null,
    endLng: null,
    pauseMinuten: null,
    pauseStart: null,
  ),
);

/// Wegpunkte eines Tages (Zeit + Quelle + Betrieb) — Grundlage der Ist-Zeiten
/// im Tagesplan: Störungs-/Montage-Stempel markieren erledigte Einsätze
/// (Daniel 30.07.2026). Am heutigen Tag invalidiert der Screen den Provider
/// im Minutentakt; für vergangene Tage liefert er die damaligen Stempel.
typedef WegpunktTag = ({
  DateTime zeitpunkt,
  String quelle,
  String? betriebId,
  double? lat,
  double? lng,
});

final wegpunkteFuerTagProvider =
    FutureProvider.family<List<WegpunktTag>, DateTime>((ref, datum) async {
      final start = DateTime(datum.year, datum.month, datum.day);
      final ende = start.add(const Duration(days: 1));
      final rows = await SupabaseService.client
          .from('wegpunkte')
          .select('zeitpunkt, quelle, betrieb_id, lat, lng')
          .gte('zeitpunkt', start.toUtc().toIso8601String())
          .lt('zeitpunkt', ende.toUtc().toIso8601String());
      return [
        for (final r in rows)
          (
            zeitpunkt: DateTime.parse(r['zeitpunkt'] as String).toLocal(),
            quelle: r['quelle'] as String,
            betriebId: r['betrieb_id'] as String?,
            lat: (r['lat'] as num?)?.toDouble(),
            lng: (r['lng'] as num?)?.toDouble(),
          ),
      ];
    });

// ─── Anfahrtszeiten ab den festen Startorten ───

/// Die beiden erfassten Startorte (Migration 156/157). Die Zeitachse wählt
/// anhand der GPS-Position des Arbeitsbeginns den näheren aus.
const kStartorte = <String, ({double lat, double lng})>{
  'domat_ems': (lat: 46.8328452, lng: 9.4529918), // Via Rezia 8
  'chur': (lat: 46.8639692, lng: 9.5278708), // Giacomettistrasse 89
};

/// Gerechnete Anfahrtszeiten je Startort: betriebId → Minuten.
/// Quelle `anfahrtszeiten` (Google, sonst OSRM — die Spalte `minuten`
/// entscheidet das in der DB). Ersetzt die Luftlinien-Heuristik für
/// Anfahrt/Heimweg, die bei Fernstrecken massiv daneben lag (Fall Sonne
/// Seehotel Eich: 346 statt 117 min, Daniel 31.07.2026).
final anfahrtszeitenProvider = FutureProvider<Map<String, Map<String, int>>>((
  ref,
) async {
  final rows = await SupabaseService.client
      .from('anfahrtszeiten')
      .select('startort, betrieb_id, minuten');
  final map = <String, Map<String, int>>{};
  for (final r in rows) {
    final startort = r['startort'] as String;
    final betriebId = r['betrieb_id'] as String?;
    final minuten = (r['minuten'] as num?)?.toInt();
    if (betriebId == null || minuten == null) continue;
    (map[startort] ??= {})[betriebId] = minuten;
  }
  return map;
});

/// Welcher der erfassten Startorte passt zur heutigen Startposition?
/// Ohne GPS (oder weiter als 5 km von beiden weg — dann ist es keiner der
/// beiden) `null`, die Zeitachse fällt dann auf die Heuristik zurück.
String? startortSchluessel(({double lat, double lng})? position) {
  if (position == null) return null;
  String? beste;
  var besteKm = double.infinity;
  for (final e in kStartorte.entries) {
    final km = haversineKm(
      position.lat,
      position.lng,
      e.value.lat,
      e.value.lng,
    );
    if (km < besteKm) {
      besteKm = km;
      beste = e.key;
    }
  }
  return besteKm <= 5.0 ? beste : null;
}

/// Datum der letzten Reinigung je Anlage (`AnlageLocal.routeId` — dieselbe
/// Konvention wie `TourEintrag.anlageId` bei Reinigungs-Einträgen). Für die
/// Fällig-Liste (Spec §7: «zuletzt DD.MM.YYYY» unter dem Fälligkeits-Badge).
final letzteReinigungJeAnlageProvider = Provider<Map<String, DateTime>>((ref) {
  final anlagen = ref.watch(anlagenProvider);
  return {
    for (final a in anlagen)
      if (a.letzteReinigung != null) a.routeId: a.letzteReinigung!,
  };
});

/// Startort (Zuhause) aus den Geschäftseinstellungen — Grundlage für
/// Anfahrt/Heimweg in der Zeitachse (Spec §3). `null`, solange keine
/// Koordinaten erfasst sind; die Zeitachse zeichnet dann keine Rand-Segmente.
final startortProvider = Provider<({double lat, double lng})?>((ref) {
  final g = ref.watch(geschaeftProvider).valueOrNull;
  if (g == null || g.startortLat == null || g.startortLng == null) {
    return null;
  }
  return (lat: g.startortLat!, lng: g.startortLng!);
});

// ─── Tagesplan State ───

final aktiverTagesplanTagProvider = StateProvider<DateTime?>((ref) => null);

final tagesplanProvider =
    StateNotifierProvider<TagesplanNotifier, List<TourEintrag>>((ref) {
      return TagesplanNotifier(ref);
    });

class TagesplanNotifier extends StateNotifier<List<TourEintrag>> {
  TagesplanNotifier(this._ref) : super([]);

  final Ref _ref;
  Timer? _saveTimer;

  /// Tag, dem der aktuelle State „gehört" bzw. den der User zuletzt bearbeitet
  /// hat. Schützt davor, dass ein verspätet eintreffender Lade-Fetch die
  /// gerade getätigten Änderungen überschreibt (Race).
  DateTime? _datum;
  DateTime? get datum => _datum;

  /// Speichert den aktuellen Stand entprellt für den aktiven Tag.
  void _scheduleSave() {
    // Aktiven Tag SOFORT beanspruchen (nicht erst wenn der Timer feuert),
    // damit ein spät eintreffender Lade-Fetch diesen Tag nicht überschreibt.
    _datum = _ref.read(aktiverTagesplanTagProvider);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () async {
      final tag = _datum;
      if (tag == null) return;
      try {
        await tagesplanSpeichern(tag, state);
        // Cache invalidieren, damit erneutes Öffnen des Tags den frischen
        // Stand lädt (sonst käme der veraltete gecachte Stand zurück).
        _ref.invalidate(gespeicherterTagesplanProvider(tag));
      } catch (e) {
        debugPrint('[Tagesplan] Speichern fehlgeschlagen: $e');
      }
    });
  }

  void _cancelSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Gespeicherten Plan laden — löst KEINE Speicherung aus.
  void setFromGespeichert(DateTime datum, List<TourEintrag> eintraege) {
    _cancelSave();
    _datum = datum;
    state = List.of(eintraege);
  }

  /// Tag ohne gespeicherten Plan → leer starten (KEINE Speicherung).
  void resetLeer(DateTime datum) {
    _cancelSave();
    _datum = datum;
    state = [];
  }

  void hinzufuegen(TourEintrag eintrag) {
    if (state.any((e) => e.id == eintrag.id)) return;
    state = [...state, eintrag];
    _scheduleSave();
  }

  void entfernen(String id) {
    state = state.where((e) => e.id != id).toList();
    _scheduleSave();
  }

  /// Einen Eintrag an Ort und Stelle ersetzen (Block-Sheet: Anlagen-Auswahl,
  /// Dauer, Anker). Die Position im Plan bleibt erhalten — ein Entfernen +
  /// Hinzufügen würde den Besuch ans Ende schieben und den Tag umbauen.
  void ersetze(String id, TourEintrag neu) {
    final index = state.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final items = List.of(state);
    items[index] = neu;
    state = items;
    _scheduleSave();
  }

  /// Ganzen Plan ersetzen (z.B. Ergebnis von `buendleInPlan` oder einer
  /// Plan-Übernahme von einem anderen Datum) und speichern. Kleinster
  /// Eingriff: die vorbereitete Liste kommt bereits fertig gebaut von der
  /// aufrufenden Stelle, hier nur State setzen + Auto-Save wie bei den
  /// anderen Mutationen.
  void setzePlan(List<TourEintrag> neuerPlan) {
    state = neuerPlan;
    _scheduleSave();
  }

  /// User-Aktion „Leeren" → persistiert den leeren Plan.
  void leeren() {
    state = [];
    _scheduleSave();
  }

  void reorder(int oldIndex, int newIndex) {
    final items = List.of(state);
    if (newIndex > oldIndex) newIndex--;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
    _scheduleSave();
  }

  // «Fällige übernehmen» läuft seit v0.56.2 über buendleInPlan im Screen
  // (_faelligeAlleUebernehmen) — das frühere rohe Anhängen der Fällig-
  // Einträge umging die Besuchs-Bündelung.

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

// ─── Tagesplan Persistierung (Supabase) ───

/// Sichtbar für Tests (`test/tour_eintrag_json_test.dart`) — deckt die
/// Lademigration von Altplänen ab (siehe `tourEintragFromJson`).
@visibleForTesting
Map<String, dynamic> tourEintragToJson(TourEintrag e) => {
  'typ': e.typ.name,
  'id': e.id,
  'betriebId': e.betriebId,
  'anlageId': e.anlageId,
  'betriebName': e.betriebName,
  'betriebOrt': e.betriebOrt,
  'regionId': e.regionId,
  'beschreibung': e.beschreibung,
  'ruhetage': e.ruhetage,
  'servicezeit': e.servicezeit,
  // Fälligkeit + Daten mitspeichern, damit geladene Einträge ihren Status
  // (Farbe, Sortierung) behalten und nicht durch Filter verschwinden.
  'faelligkeit': e.faelligkeit?.name,
  'datum': e.datum?.toIso8601String(),
  'zielDatum': e.zielDatum?.toIso8601String(),
  'anlageIds': e.anlageIds,
  'dauerMinuten': e.dauerMinuten,
  'ankerZeit': e.ankerZeit,
  'uebernommen': e.uebernommen,
};

/// Sichtbar für Tests. Lademigration: Altpläne kennen nur `anlageId`, keine
/// `anlageIds`-Liste — siehe Kommentar im Funktionskörper.
@visibleForTesting
TourEintrag tourEintragFromJson(Map<String, dynamic> j) {
  // Lademigration: Altpläne kennen nur das einzelne `anlageId`-Feld, keine
  // `anlageIds`-Liste. Ist eine Liste vorhanden, ist sie führend; sonst wird
  // sie aus dem Alt-Feld nachgebildet (leer, falls auch das fehlt).
  final anlageIds =
      (j['anlageIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [if (j['anlageId'] != null) j['anlageId'] as String];
  return TourEintrag(
    typ: TourEintragTyp.values.firstWhere(
      (t) => t.name == j['typ'],
      orElse: () => TourEintragTyp.reinigung,
    ),
    id: j['id'] as String,
    betriebId: j['betriebId'] as String?,
    // anlageId bleibt die erste Anlage — egal ob aus neuem oder altem Feld.
    anlageId: anlageIds.isNotEmpty ? anlageIds.first : j['anlageId'] as String?,
    betriebName: j['betriebName'] as String? ?? '',
    betriebOrt: j['betriebOrt'] as String?,
    regionId: j['regionId'] as String?,
    beschreibung: j['beschreibung'] as String? ?? '',
    ruhetage:
        (j['ruhetage'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    servicezeit: j['servicezeit'] as String?,
    faelligkeit: j['faelligkeit'] != null
        ? FaelligkeitsStatus.values.firstWhere(
            (f) => f.name == j['faelligkeit'],
            orElse: () => FaelligkeitsStatus.nichtFaellig,
          )
        : null,
    datum: j['datum'] != null ? DateTime.tryParse(j['datum'] as String) : null,
    zielDatum: j['zielDatum'] != null
        ? DateTime.tryParse(j['zielDatum'] as String)
        : null,
    anlageIds: anlageIds,
    dauerMinuten: j['dauerMinuten'] as int?,
    ankerZeit: j['ankerZeit'] as String?,
    uebernommen: j['uebernommen'] as bool? ?? false,
  );
}

/// Gespeicherter Tagesplan samt Arbeitstag-Rahmen (Arbeitsbeginn/-ende,
/// km-Stand). Der Rahmen wird ab Task 6 im UI-State übernommen; hier nur
/// kompilierfähig durchgereicht.
typedef GespeicherterTagesplan = ({
  List<TourEintrag> eintraege,
  String? arbeitsbeginn,
  String? arbeitsende,
  int? kmStand,
  int? kmStart,
  double? startLat,
  double? startLng,
  double? endLat,
  double? endLng,
  int? pauseMinuten,
  String? pauseStart,
});

final gespeicherterTagesplanProvider =
    FutureProvider.family<GespeicherterTagesplan?, DateTime>((
      ref,
      datum,
    ) async {
      try {
        final datumStr =
            '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
        final rows = await SupabaseService.client
            .from('tagesplaene')
            .select()
            .eq('datum', datumStr)
            .limit(1);
        if (rows.isEmpty) return null;
        final row = rows.first;
        final eintraege = (row['eintraege'] as List<dynamic>)
            .map((e) => tourEintragFromJson(Map<String, dynamic>.from(e)))
            .toList();
        return (
          eintraege: eintraege,
          arbeitsbeginn: row['arbeitsbeginn'] as String?,
          arbeitsende: row['arbeitsende'] as String?,
          kmStand: row['km_stand'] as int?,
          kmStart: row['km_start'] as int?,
          startLat: (row['start_lat'] as num?)?.toDouble(),
          startLng: (row['start_lng'] as num?)?.toDouble(),
          endLat: (row['end_lat'] as num?)?.toDouble(),
          endLng: (row['end_lng'] as num?)?.toDouble(),
          pauseMinuten: row['pause_minuten'] as int?,
          pauseStart: row['pause_start'] as String?,
        );
      } catch (e) {
        debugPrint('[Tagesplan] Laden fehlgeschlagen: $e');
        return null;
      }
    });

Future<void> tagesplanSpeichern(
  DateTime datum,
  List<TourEintrag> eintraege, {
  String? arbeitsbeginn,
  String? arbeitsende,
  int? kmStand,
}) async {
  final datumStr =
      '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
  final userId = SupabaseService.client.auth.currentUser!.id;
  final json = eintraege.map(tourEintragToJson).toList();
  await SupabaseService.client.from('tagesplaene').upsert({
    'user_id': userId,
    'datum': datumStr,
    'eintraege': json,
    'updated_at': DateTime.now().toIso8601String(),
    if (arbeitsbeginn != null) 'arbeitsbeginn': arbeitsbeginn,
    if (arbeitsende != null) 'arbeitsende': arbeitsende,
    if (kmStand != null) 'km_stand': kmStand,
  }, onConflict: 'user_id,datum');
}

/// Speichert NUR den Arbeitstag-Rahmen (Beginn/Ende/km) und schreibt die drei
/// Spalten **immer** — auch mit `null`.
///
/// Warum eine eigene Funktion: In [tagesplanSpeichern] heisst `null`
/// «Parameter nicht angegeben» (die Felder fallen aus dem upsert-Map), sonst
/// würde jedes automatische Speichern der Einträge den Rahmen mitlöschen.
/// Damit lässt sich ein Arbeitsende oder km-Stand aber nie wieder leeren —
/// genau das macht diese Funktion möglich. Sie fasst `eintraege` nicht an
/// (update statt upsert). Existiert für den Tag noch keine Zeile, legt sie
/// [tagesplanSpeichern] mit den aktuellen Einträgen an, statt eine Zeile mit
/// leerem Plan zu erzeugen.
Future<void> arbeitstagFelderSpeichern(
  DateTime datum,
  List<TourEintrag> eintraege, {
  // `null` = kein erfasster Beginn (löscht einen vorhandenen). Früher war der
  // Parameter nicht nullbar — jeder Feierabend ohne erfassten Start schrieb
  // so den 06:00-Standard als angeblich erfassten Beginn in die DB
  // (Fehleingaben-Paket 31.07.2026).
  required String? arbeitsbeginn,
  required String? arbeitsende,
  required int? kmStand,
  required int? kmStart,
  // Start-/End-Position (GPS beim «Arbeitsbeginn»- bzw. «Feierabend»-Knopf).
  // Nur wenn übergeben werden sie geschrieben — sie werden nie gelöscht,
  // nur überschrieben.
  ({double lat, double lng})? startPosition,
  ({double lat, double lng})? endPosition,
  // Pausen (Migration 159): Anders als die Positionen werden sie IMMER
  // geschrieben — `pauseStart: null` beendet eine laufende Pause, und genau
  // das muss auch in der DB ankommen.
  int? pauseMinuten,
  String? pauseStart,
  bool pauseSchreiben = false,
}) async {
  final datumStr =
      '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
  final userId = SupabaseService.client.auth.currentUser!.id;
  final betroffen = await SupabaseService.client
      .from('tagesplaene')
      .update({
        'arbeitsbeginn': arbeitsbeginn,
        'arbeitsende': arbeitsende,
        'km_stand': kmStand,
        'km_start': kmStart,
        if (startPosition != null) 'start_lat': startPosition.lat,
        if (startPosition != null) 'start_lng': startPosition.lng,
        if (endPosition != null) 'end_lat': endPosition.lat,
        if (endPosition != null) 'end_lng': endPosition.lng,
        if (pauseSchreiben) 'pause_minuten': pauseMinuten,
        if (pauseSchreiben) 'pause_start': pauseStart,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('user_id', userId)
      .eq('datum', datumStr)
      .select('id');
  if (betroffen.isNotEmpty) return;

  await tagesplanSpeichern(
    datum,
    eintraege,
    arbeitsbeginn: arbeitsbeginn,
    arbeitsende: arbeitsende,
    kmStand: kmStand,
  );
  // Neu angelegte Zeile: Positionen + km_start nachtragen (tagesplanSpeichern
  // kennt sie bewusst nicht — dort hiesse null «nicht angefasst»).
  final nachtrag = <String, dynamic>{
    if (kmStart != null) 'km_start': kmStart,
    if (startPosition != null) 'start_lat': startPosition.lat,
    if (startPosition != null) 'start_lng': startPosition.lng,
    if (endPosition != null) 'end_lat': endPosition.lat,
    if (endPosition != null) 'end_lng': endPosition.lng,
  };
  if (nachtrag.isNotEmpty) {
    await SupabaseService.client
        .from('tagesplaene')
        .update(nachtrag)
        .eq('user_id', userId)
        .eq('datum', datumStr);
  }
}

Future<void> tagesplanLoeschen(DateTime datum) async {
  final datumStr =
      '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
  await SupabaseService.client
      .from('tagesplaene')
      .delete()
      .eq('datum', datumStr);
}

// ─── Tages-Counts (für Day-Chips, alle Typen) ───

final tagesCountsProvider = Provider.family<List<int>, DateTime>((
  ref,
  weekStart,
) {
  final counts = List<int>.filled(6, 0); // Mo-Sa

  final aktiverTag = ref.watch(aktiverTagesplanTagProvider);
  final aktiverPlan = ref.watch(tagesplanProvider);
  final reinigungen = ref.watch(reinigungenProvider);
  final stoerungen = ref.watch(stoerungenProvider);
  final montagen = ref.watch(montagenProvider);

  for (int i = 0; i < 6; i++) {
    final day = weekStart.add(Duration(days: i));

    // Aktiver Tag: In-Memory-State hat Vorrang (Live-Updates)
    if (aktiverTag != null &&
        day.year == aktiverTag.year &&
        day.month == aktiverTag.month &&
        day.day == aktiverTag.day) {
      counts[i] = aktiverPlan.length;
      continue;
    }

    // Gespeicherter Plan hat Vorrang
    final gespeichert = ref
        .watch(gespeicherterTagesplanProvider(day))
        .valueOrNull;
    if (gespeichert != null) {
      counts[i] = gespeichert.eintraege.length;
      continue;
    }

    int count = 0;

    // Reinigungen von vor 28 Tagen
    final referenz = day.subtract(const Duration(days: 28));
    final von = referenz.subtract(const Duration(days: 2));
    final bis = referenz.add(const Duration(days: 2));
    final seen = <String>{};
    for (final r in reinigungen) {
      if (r.datum.isAfter(von) && r.datum.isBefore(bis)) {
        final key = r.anlageIds.isNotEmpty ? r.anlageIds.first : r.betriebId;
        if (seen.add(key)) count++;
      }
    }

    // Offene Störungen (zählen für jeden Tag)
    for (final s in stoerungen) {
      if (s.status == 'offen') count++;
    }

    // Montagen an diesem Tag
    final dayOnly = DateTime(day.year, day.month, day.day);
    for (final m in montagen) {
      if (m.status != 'geplant') continue;
      final mDatum = DateTime(m.datum.year, m.datum.month, m.datum.day);
      if (mDatum == dayOnly) count++;
    }

    counts[i] = count;
  }

  return counts;
});

// ─── Fälligkeits-Helfer (öffentlich, geteilt mit Betriebe-Karte) ───

/// Farbe je Fälligkeitsstatus (identisch zum Touren-Farbschema).
Color faelligkeitFarbe(FaelligkeitsStatus status) {
  switch (status) {
    case FaelligkeitsStatus.ueberfaellig:
      return AppColors.error;
    case FaelligkeitsStatus.faellig:
      return AppColors.warning;
    case FaelligkeitsStatus.baldFaellig:
      return AppColors.success;
    case FaelligkeitsStatus.endreinigungFaellig:
      return const Color(0xFFEA580C);
    case FaelligkeitsStatus.eroeffnungFaellig:
      return AppColors.info;
    case FaelligkeitsStatus.nichtFaellig:
      return AppColors.textSecondary;
  }
}

/// Kurzlabel je Fälligkeitsstatus.
String faelligkeitLabel(FaelligkeitsStatus status) {
  switch (status) {
    case FaelligkeitsStatus.ueberfaellig:
      return 'Überfällig';
    case FaelligkeitsStatus.faellig:
      return 'Fällig';
    case FaelligkeitsStatus.baldFaellig:
      return 'Bald fällig';
    case FaelligkeitsStatus.endreinigungFaellig:
      return 'Endreinigung';
    case FaelligkeitsStatus.eroeffnungFaellig:
      return 'Eröffnung';
    case FaelligkeitsStatus.nichtFaellig:
      return 'Nicht fällig';
  }
}

// ─── Saisondaten fehlen (Anker nicht bestimmbar) ───

/// Betriebe, deren letzte Reinigung eine Endreinigung ist, die aber keine
/// künftige Wiedereröffnung gepflegt haben — die Fälligkeits-Uhr kann nicht
/// starten. Ohne Meldung wären sie STILL nie fällig (Regel Daniel 17.07.2026:
/// "falls nicht festgelegt Meldung").
final saisonAnkerFehltProvider = Provider<List<BetriebLocal>>((ref) {
  final betriebe = ref.watch(betriebeProvider);
  final anlagen = ref.watch(anlagenProvider);
  final reinigungen = ref.watch(reinigungenProvider);
  final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);
  final betriebMap = _buildBetriebMap(betriebe);

  final result = <String, BetriebLocal>{};
  for (final a in anlagen) {
    if (a.status != 'aktiv' || a.letzteReinigung == null) continue;
    final art = a.serverId != null ? serviceArtMap[a.serverId!] : null;
    if (art != 'endreinigung') continue;
    final b = betriebMap[a.betriebId];
    // Auch manuell auf 'saisonpause' gestellte Betriebe melden (Daniel,
    // 20.07.2026): gerade DIE haben am ehesten eine fehlende Wiedereröffnung.
    // Nur inaktiv/geschlossen bleiben aussen vor (operativ = aktiv+saisonpause).
    if (b == null || (b.status != 'aktiv' && b.status != 'saisonpause')) {
      continue;
    }
    if (faelligkeitsAnker(b, a.letzteReinigung!) == null) {
      result[b.routeId] = b;
    }
  }
  return result.values.toList()..sort((a, b) => a.name.compareTo(b.name));
});
