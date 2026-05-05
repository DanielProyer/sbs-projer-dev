import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/region_repository.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';

// ─── Regionen ───

final regionenStreamProvider = StreamProvider<List<RegionLocal>>((ref) {
  return RegionRepository.watchAll();
});

final regionenProvider = Provider<List<RegionLocal>>((ref) {
  return ref.watch(regionenStreamProvider).valueOrNull ?? [];
});

// ─── Fälligkeits-Status ───

enum FaelligkeitsStatus { ueberfaellig, faellig, baldFaellig, nichtFaellig }

int? _rhythmusTage(String rhythmus) {
  switch (rhythmus) {
    case '4-Wochen': return 28;
    case '6-Wochen': return 42;
    case '2-Monate': return 60;
    case '3-Monate': return 90;
    case '6-Monate': return 180;
    case 'Jährlich': return 365;
    default: return null; // auf-Abruf, Selbstreiniger
  }
}

FaelligkeitsStatus getFaelligkeit(AnlageLocal anlage, DateTime datum) {
  final tage = _rhythmusTage(anlage.reinigungRhythmus);
  if (tage == null) return FaelligkeitsStatus.nichtFaellig;

  // naechsteReinigung bestimmen
  DateTime? naechste = anlage.naechsteReinigung;
  if (naechste == null && anlage.letzteReinigung != null) {
    naechste = anlage.letzteReinigung!.add(Duration(days: tage));
  }
  if (naechste == null) {
    // Neue Anlage, nie gereinigt → überfällig
    return FaelligkeitsStatus.ueberfaellig;
  }

  final diff = datum.difference(naechste).inDays;
  if (diff > 7) return FaelligkeitsStatus.ueberfaellig;
  if (diff >= 0) return FaelligkeitsStatus.faellig;
  if (diff >= -7) return FaelligkeitsStatus.baldFaellig;
  return FaelligkeitsStatus.nichtFaellig;
}

// ─── Betrieb "offen" Check ───

bool isBetriebOffen(BetriebLocal b, DateTime datum) {
  if (b.status != 'aktiv') return false;

  // Ferien-Check
  if (b.ferienStart != null && b.ferienEnde != null) {
    if (!datum.isBefore(b.ferienStart!) && !datum.isAfter(b.ferienEnde!)) {
      return false;
    }
  }

  // Saison-Check
  if (b.istSaisonbetrieb) {
    bool inAktiverSaison = false;

    if (b.winterSaisonAktiv &&
        b.winterStartDatum != null &&
        b.winterEndeDatum != null) {
      if (!datum.isBefore(b.winterStartDatum!) &&
          !datum.isAfter(b.winterEndeDatum!)) {
        inAktiverSaison = true;
      }
    }

    if (b.sommerSaisonAktiv &&
        b.sommerStartDatum != null &&
        b.sommerEndeDatum != null) {
      if (!datum.isBefore(b.sommerStartDatum!) &&
          !datum.isAfter(b.sommerEndeDatum!)) {
        inAktiverSaison = true;
      }
    }

    if (!inAktiverSaison) return false;
  }

  // Ruhetag-Check
  const wochentage = [
    'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
    'Freitag', 'Samstag', 'Sonntag',
  ];
  final wochentag = wochentage[datum.weekday - 1];
  if (b.ruhetage.contains(wochentag)) return false;

  return true;
}

// ─── Betrieb "aktiv" Check (ohne Ruhetag, für Fällig-Tab) ───

bool _isBetriebAktiv(BetriebLocal b, DateTime datum) {
  if (b.status != 'aktiv') return false;

  // Ferien-Check
  if (b.ferienStart != null && b.ferienEnde != null) {
    if (!datum.isBefore(b.ferienStart!) && !datum.isAfter(b.ferienEnde!)) {
      return false;
    }
  }

  // Saison-Check
  if (b.istSaisonbetrieb) {
    bool inAktiverSaison = false;

    if (b.winterSaisonAktiv &&
        b.winterStartDatum != null &&
        b.winterEndeDatum != null) {
      if (!datum.isBefore(b.winterStartDatum!) &&
          !datum.isAfter(b.winterEndeDatum!)) {
        inAktiverSaison = true;
      }
    }

    if (b.sommerSaisonAktiv &&
        b.sommerStartDatum != null &&
        b.sommerEndeDatum != null) {
      if (!datum.isBefore(b.sommerStartDatum!) &&
          !datum.isAfter(b.sommerEndeDatum!)) {
        inAktiverSaison = true;
      }
    }

    if (!inAktiverSaison) {
      // Saisonpause: Trotzdem als aktiv behandeln wenn nächste Saison
      // innerhalb von 4 Wochen startet (Eröffnungsreinigung nötig)
      if (_naechsterSaisonStartBald(b, datum, 28)) return true;
      return false;
    }
  }

  return true;
}

/// Prüft ob die nächste Saison innerhalb von [tage] Tagen ab [datum] startet.
bool _naechsterSaisonStartBald(BetriebLocal b, DateTime datum, int tage) {
  final grenze = datum.add(Duration(days: tage));

  if (b.sommerSaisonAktiv && b.sommerStartDatum != null) {
    if (!b.sommerStartDatum!.isBefore(datum) &&
        !b.sommerStartDatum!.isAfter(grenze)) {
      return true;
    }
  }

  if (b.winterSaisonAktiv && b.winterStartDatum != null) {
    if (!b.winterStartDatum!.isBefore(datum) &&
        !b.winterStartDatum!.isAfter(grenze)) {
      return true;
    }
  }

  return false;
}

// ─── Fällige Anlagen Provider ───

final faelligeAnlagenProvider =
    Provider.family<List<AnlageLocal>, DateTime>((ref, datum) {
  final anlagen = ref.watch(anlagenProvider);
  final betriebe = ref.watch(betriebeProvider);

  // Betrieb-Lookup: serverId/routeId → BetriebLocal
  final betriebMap = <String, BetriebLocal>{};
  for (final b in betriebe) {
    betriebMap[b.routeId] = b;
    if (b.serverId != null) betriebMap[b.serverId!] = b;
  }

  return anlagen.where((a) {
    if (a.status != 'aktiv') return false;
    final faelligkeit = getFaelligkeit(a, datum);
    if (faelligkeit == FaelligkeitsStatus.nichtFaellig) return false;

    // Betrieb aktiv? (ohne Ruhetag-Check)
    final betrieb = betriebMap[a.betriebId];
    if (betrieb != null && !_isBetriebAktiv(betrieb, datum)) return false;

    return true;
  }).toList()
    ..sort((a, b) {
      // Überfällig zuerst
      final fa = getFaelligkeit(a, datum).index;
      final fb = getFaelligkeit(b, datum).index;
      return fa.compareTo(fb);
    });
});

// ─── Tour-Vorschlag Provider (Reinigungen von vor ~28 Tagen) ───

final tourVorschlagProvider =
    Provider.family<List<ReinigungLocal>, DateTime>((ref, datum) {
  final reinigungen = ref.watch(reinigungenProvider);
  final referenz = datum.subtract(const Duration(days: 28));
  final von = referenz.subtract(const Duration(days: 2));
  final bis = referenz.add(const Duration(days: 2));

  return reinigungen.where((r) {
    return r.datum.isAfter(von) && r.datum.isBefore(bis);
  }).toList()
    ..sort((a, b) => a.datum.compareTo(b.datum));
});

// ─── Fällige Anlagen Count ───

final faelligeAnlagenCountProvider = Provider<int>((ref) {
  final heute = DateTime.now();
  final datum = DateTime(heute.year, heute.month, heute.day);
  return ref.watch(faelligeAnlagenProvider(datum)).length;
});

// ─── TourEintrag (UI-only Wrapper für alle planbaren Typen) ───

enum TourEintragTyp { reinigung, stoerung, montage, heigenie }

class TourEintrag {
  final TourEintragTyp typ;
  final String id;
  final String? betriebId;
  final String? anlageId;
  final String betriebName;
  final String? betriebOrt;
  final String? regionId;
  final String beschreibung;
  final FaelligkeitsStatus? faelligkeit;
  final DateTime? datum;

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
  });
}

// ─── Filter-State ───

final selectedRegionenProvider = StateProvider<Set<String>>((ref) => {});
final selectedFaelligkeitProvider =
    StateProvider<FaelligkeitsStatus?>((ref) => null);

// ─── Betrieb-Lookup Helper ───

Map<String, BetriebLocal> _buildBetriebMap(List<BetriebLocal> betriebe) {
  final map = <String, BetriebLocal>{};
  for (final b in betriebe) {
    map[b.routeId] = b;
    if (b.serverId != null) map[b.serverId!] = b;
  }
  return map;
}

// ─── Vereinigte Fällig-Liste (alle Typen) ───

final faelligeEintraegeProvider =
    Provider.family<List<TourEintrag>, DateTime>((ref, datum) {
  final betriebe = ref.watch(betriebeProvider);
  final betriebMap = _buildBetriebMap(betriebe);
  final eintraege = <TourEintrag>[];

  // 1. Fällige Anlagen → Reinigungen
  final faelligeAnlagen = ref.watch(faelligeAnlagenProvider(datum));
  for (final a in faelligeAnlagen) {
    final betrieb = betriebMap[a.betriebId];
    eintraege.add(TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: 'r_${a.routeId}',
      betriebId: a.betriebId,
      anlageId: a.routeId,
      betriebName: betrieb?.name ?? '?',
      betriebOrt: betrieb?.ort,
      regionId: betrieb?.regionId,
      beschreibung:
          '${a.typAnlage} · ${a.anzahlHaehne} Hähne',
      faelligkeit: getFaelligkeit(a, datum),
      datum: a.naechsteReinigung,
    ));
  }

  // 2. Offene Störungen
  final stoerungen = ref.watch(stoerungenProvider);
  for (final s in stoerungen) {
    if (s.status != 'offen') continue;
    final betrieb =
        s.betriebId != null ? betriebMap[s.betriebId!] : null;
    eintraege.add(TourEintrag(
      typ: TourEintragTyp.stoerung,
      id: 's_${s.routeId}',
      betriebId: s.betriebId,
      anlageId: s.anlageId,
      betriebName: betrieb?.name ?? '?',
      betriebOrt: betrieb?.ort,
      regionId: betrieb?.regionId,
      beschreibung: s.problemBeschreibung,
      datum: s.datum,
    ));
  }

  // 3. Geplante Montagen / HeiGenie
  final montagen = ref.watch(montagenProvider);
  for (final m in montagen) {
    if (m.status != 'geplant') continue;
    final betrieb =
        m.betriebId != null ? betriebMap[m.betriebId!] : null;
    final istHeiGenie = m.montageTyp == 'heigenie_service';
    eintraege.add(TourEintrag(
      typ: istHeiGenie ? TourEintragTyp.heigenie : TourEintragTyp.montage,
      id: 'm_${m.routeId}',
      betriebId: m.betriebId,
      anlageId: m.anlageId,
      betriebName: betrieb?.name ?? '?',
      betriebOrt: betrieb?.ort,
      regionId: betrieb?.regionId,
      beschreibung: '${_montageTypLabel(m.montageTyp)} · ${m.beschreibung}',
      datum: m.datum,
    ));
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

String _montageTypLabel(String typ) {
  switch (typ) {
    case 'neumontage': return 'Neumontage';
    case 'demontage': return 'Demontage';
    case 'abaenderung': return 'Abänderung';
    case 'heigenie_service': return 'HeiGenie Service';
    case 'anlass': return 'Anlass';
    case 'spesen': return 'Spesen';
    case 'aufwandsentschaedigung': return 'Aufwandsentsch.';
    default: return typ;
  }
}

// ─── Erweiterter Vorschlag (alle Typen) ───

final tourVorschlagErweitertProvider =
    Provider.family<List<TourEintrag>, DateTime>((ref, datum) {
  final betriebe = ref.watch(betriebeProvider);
  final anlagen = ref.watch(anlagenProvider);
  final betriebMap = _buildBetriebMap(betriebe);
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
    final aId = r.anlageIds.isNotEmpty
        ? r.anlageIds.first
        : r.betriebId;
    if (!seenAnlagen.add(aId)) continue;

    final anlage = anlageMap[aId];
    if (anlage != null && anlage.status != 'aktiv') continue;

    final betrieb = betriebMap[r.betriebId];
    if (betrieb != null && !isBetriebOffen(betrieb, datum)) continue;

    eintraege.add(TourEintrag(
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
      faelligkeit: anlage != null ? getFaelligkeit(anlage, datum) : null,
      datum: r.datum,
    ));
  }

  // 2. Offene Störungen (immer relevant)
  final stoerungen = ref.watch(stoerungenProvider);
  for (final s in stoerungen) {
    if (s.status != 'offen') continue;
    final betrieb =
        s.betriebId != null ? betriebMap[s.betriebId!] : null;
    eintraege.add(TourEintrag(
      typ: TourEintragTyp.stoerung,
      id: 's_${s.routeId}',
      betriebId: s.betriebId,
      anlageId: s.anlageId,
      betriebName: betrieb?.name ?? '?',
      betriebOrt: betrieb?.ort,
      regionId: betrieb?.regionId,
      beschreibung: s.problemBeschreibung,
      datum: s.datum,
    ));
  }

  // 3. Montagen an diesem Datum
  final montagen = ref.watch(montagenProvider);
  for (final m in montagen) {
    if (m.status != 'geplant') continue;
    final mDatum = DateTime(m.datum.year, m.datum.month, m.datum.day);
    final selDate = DateTime(datum.year, datum.month, datum.day);
    if (mDatum != selDate) continue;

    final betrieb =
        m.betriebId != null ? betriebMap[m.betriebId!] : null;
    final istHeiGenie = m.montageTyp == 'heigenie_service';
    eintraege.add(TourEintrag(
      typ: istHeiGenie ? TourEintragTyp.heigenie : TourEintragTyp.montage,
      id: 'm_${m.routeId}',
      betriebId: m.betriebId,
      anlageId: m.anlageId,
      betriebName: betrieb?.name ?? '?',
      betriebOrt: betrieb?.ort,
      regionId: betrieb?.regionId,
      beschreibung: '${_montageTypLabel(m.montageTyp)} · ${m.beschreibung}',
      datum: m.datum,
    ));
  }

  return eintraege;
});

// ─── Tagesplan State ───

final tagesplanProvider =
    StateNotifierProvider<TagesplanNotifier, List<TourEintrag>>((ref) {
  return TagesplanNotifier();
});

class TagesplanNotifier extends StateNotifier<List<TourEintrag>> {
  TagesplanNotifier() : super([]);

  void setFromVorschlag(List<TourEintrag> eintraege) {
    state = List.of(eintraege);
  }

  void hinzufuegen(TourEintrag eintrag) {
    if (state.any((e) => e.id == eintrag.id)) return;
    state = [...state, eintrag];
  }

  void entfernen(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void leeren() {
    state = [];
  }

  void reorder(int oldIndex, int newIndex) {
    final items = List.of(state);
    if (newIndex > oldIndex) newIndex--;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
  }

  void befuellenAusFaellig(List<TourEintrag> faellige) {
    final existing = state.map((e) => e.id).toSet();
    final neue = faellige.where((e) => !existing.contains(e.id)).toList();
    state = [...state, ...neue];
  }
}

// ─── Tages-Counts (für Day-Chips, alle Typen) ───

final tagesCountsProvider =
    Provider.family<List<int>, DateTime>((ref, weekStart) {
  final counts = List<int>.filled(6, 0); // Mo-Sa

  // Reinigungen-Basis
  final reinigungen = ref.watch(reinigungenProvider);
  final stoerungen = ref.watch(stoerungenProvider);
  final montagen = ref.watch(montagenProvider);

  for (int i = 0; i < 6; i++) {
    final day = weekStart.add(Duration(days: i));
    int count = 0;

    // Reinigungen von vor 28 Tagen
    final referenz = day.subtract(const Duration(days: 28));
    final von = referenz.subtract(const Duration(days: 2));
    final bis = referenz.add(const Duration(days: 2));
    final seen = <String>{};
    for (final r in reinigungen) {
      if (r.datum.isAfter(von) && r.datum.isBefore(bis)) {
        final key = r.anlageIds.isNotEmpty
            ? r.anlageIds.first
            : r.betriebId;
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
