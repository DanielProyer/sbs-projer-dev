import 'package:flutter/foundation.dart';
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
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

// ─── Regionen ───

final regionenStreamProvider = StreamProvider<List<RegionLocal>>((ref) {
  return RegionRepository.watchAll();
});

final regionenProvider = Provider<List<RegionLocal>>((ref) {
  return ref.watch(regionenStreamProvider).valueOrNull ?? [];
});

// ─── Fälligkeits-Status ───

enum FaelligkeitsStatus {
  ueberfaellig,
  faellig,
  baldFaellig,
  endreinigungFaellig,
  eroeffnungFaellig,
  nichtFaellig,
}

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

/// Findet das Wiedereröffnungsdatum nach einer Endreinigung
/// (nächster Saisonstart oder Tag nach Ferienende).
DateTime? _wiederoeffnungNachEndreinigung(
  BetriebLocal betrieb,
  DateTime letzteReinigung,
) {
  DateTime? wiederoeffnung;

  // Ferien: Tag nach Ferienende = Wiedereröffnung
  for (final fe in [
    betrieb.ferienEnde,
    betrieb.ferien2Ende,
    betrieb.ferien3Ende,
  ]) {
    if (fe != null && fe.isAfter(letzteReinigung)) {
      final reopen = fe.add(const Duration(days: 1));
      if (wiederoeffnung == null || reopen.isBefore(wiederoeffnung)) {
        wiederoeffnung = reopen;
      }
    }
  }

  // Saison: nächster Saisonstart
  if (betrieb.istSaisonbetrieb) {
    for (final s in [
      if (betrieb.sommerSaisonAktiv) betrieb.sommerStartDatum,
      if (betrieb.winterSaisonAktiv) betrieb.winterStartDatum,
    ]) {
      if (s != null && s.isAfter(letzteReinigung)) {
        if (wiederoeffnung == null || s.isBefore(wiederoeffnung)) {
          wiederoeffnung = s;
        }
      }
    }
  }

  return wiederoeffnung;
}

/// Baut eine Map: anlageId → serviceArt der letzten Reinigung
Map<String, String?> _buildLetzteServiceArtMap(
    List<ReinigungLocal> reinigungen) {
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

const _saisonVorlaufTage = 14; // 2 Wochen

/// Nächstes Schliessungsdatum (Saisonende oder Ferienstart)
/// nur wenn der Betrieb JETZT offen ist.
DateTime? _naechsteSchliessung(BetriebLocal betrieb, DateTime datum) {
  DateTime? naechste;

  // Saisonende: nur wenn aktuell IN dieser Saison
  if (betrieb.istSaisonbetrieb) {
    if (betrieb.sommerSaisonAktiv &&
        betrieb.sommerStartDatum != null &&
        betrieb.sommerEndeDatum != null) {
      if (!datum.isBefore(betrieb.sommerStartDatum!) &&
          !datum.isAfter(betrieb.sommerEndeDatum!)) {
        final e = betrieb.sommerEndeDatum!;
        if (naechste == null || e.isBefore(naechste)) naechste = e;
      }
    }
    if (betrieb.winterSaisonAktiv &&
        betrieb.winterStartDatum != null &&
        betrieb.winterEndeDatum != null) {
      if (!datum.isBefore(betrieb.winterStartDatum!) &&
          !datum.isAfter(betrieb.winterEndeDatum!)) {
        final e = betrieb.winterEndeDatum!;
        if (naechste == null || e.isBefore(naechste)) naechste = e;
      }
    }
  }

  // Ferienstart: Ferien die noch kommen
  for (final fs in [
    betrieb.ferienStart,
    betrieb.ferien2Start,
    betrieb.ferien3Start,
  ]) {
    if (fs != null && fs.isAfter(datum)) {
      if (naechste == null || fs.isBefore(naechste)) naechste = fs;
    }
  }

  return naechste;
}

/// Nächstes Öffnungsdatum (Saisonstart oder Tag nach Ferienende).
/// Gibt auch vergangene Öffnungen zurück wenn sie nach letzteReinigung liegen.
DateTime? _naechsteOeffnung(
    BetriebLocal betrieb, DateTime datum, DateTime? letzteReinigung) {
  DateTime? naechste;

  // Saisonstart
  if (betrieb.istSaisonbetrieb) {
    for (final s in [
      if (betrieb.sommerSaisonAktiv) betrieb.sommerStartDatum,
      if (betrieb.winterSaisonAktiv) betrieb.winterStartDatum,
    ]) {
      if (s != null &&
          (letzteReinigung == null || s.isAfter(letzteReinigung))) {
        if (naechste == null || s.isBefore(naechste)) naechste = s;
      }
    }
  }

  // Ferienende + 1 Tag
  for (final fe in [
    betrieb.ferienEnde,
    betrieb.ferien2Ende,
    betrieb.ferien3Ende,
  ]) {
    if (fe != null) {
      final reopen = fe.add(const Duration(days: 1));
      if (letzteReinigung == null || reopen.isAfter(letzteReinigung)) {
        if (naechste == null || reopen.isBefore(naechste)) naechste = reopen;
      }
    }
  }

  return naechste;
}

/// Prüft ob eine saisonale Fälligkeit vorliegt (Endreinigung / Eröffnung).
FaelligkeitsStatus? _getSaisonFaelligkeit(
  AnlageLocal anlage,
  DateTime datum,
  BetriebLocal betrieb,
  String? letzteServiceArt,
) {
  // --- Endreinigung: Schliessung innerhalb von 2 Wochen ---
  if (letzteServiceArt != 'endreinigung') {
    final schliessung = _naechsteSchliessung(betrieb, datum);
    if (schliessung != null &&
        schliessung.difference(datum).inDays <= _saisonVorlaufTage) {
      return FaelligkeitsStatus.endreinigungFaellig;
    }
  }

  // --- Eröffnungsservice: Öffnung bald oder gerade erst geöffnet ---
  if (letzteServiceArt == 'endreinigung' || letzteServiceArt == null) {
    final oeffnung =
        _naechsteOeffnung(betrieb, datum, anlage.letzteReinigung);
    if (oeffnung != null) {
      final tage = oeffnung.difference(datum).inDays;
      // Öffnung in ≤14 Tagen (Zukunft)
      if (tage >= 0 && tage <= _saisonVorlaufTage) {
        return FaelligkeitsStatus.eroeffnungFaellig;
      }
      // Öffnung bereits vorbei, Eröffnungsservice noch nicht gemacht
      if (tage < 0 && letzteServiceArt == 'endreinigung') {
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
        anlage, datum, betrieb, letzteServiceArt);
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

  // Endreinigung + Ferien/Saison → Fälligkeit auf Wiedereröffnung + 4 Wochen
  if (letzteServiceArt == 'endreinigung' &&
      betrieb != null &&
      anlage.letzteReinigung != null) {
    final wiederoeffnung =
        _wiederoeffnungNachEndreinigung(betrieb, anlage.letzteReinigung!);
    if (wiederoeffnung != null) {
      final adjusted = wiederoeffnung.add(const Duration(days: 28));
      if (adjusted.isAfter(naechste)) {
        naechste = adjusted;
      }
    }
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
      // Saisonpause → nicht aktiv für reguläre Fälligkeit.
      // Eröffnungs-/Endreinigung wird über _getSaisonFaelligkeit
      // gesteuert und bypassed diesen Filter.
      return false;
    }
  }

  return true;
}

// ─── Fällige Anlagen Provider ───

final faelligeAnlagenProvider =
    Provider.family<List<AnlageLocal>, DateTime>((ref, datum) {
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
    final serviceArt =
        a.serverId != null ? serviceArtMap[a.serverId!] : null;
    final faelligkeit = getFaelligkeit(a, datum,
        betrieb: betrieb, letzteServiceArt: serviceArt);
    if (faelligkeit == FaelligkeitsStatus.nichtFaellig) return false;

    // Saisonale Einträge immer anzeigen (auch wenn Betrieb in Pause)
    if (faelligkeit == FaelligkeitsStatus.endreinigungFaellig ||
        faelligkeit == FaelligkeitsStatus.eroeffnungFaellig) {
      return true;
    }

    // Betrieb aktiv? (ohne Ruhetag-Check)
    if (betrieb != null && !_isBetriebAktiv(betrieb, datum)) return false;

    return true;
  }).toList()
    ..sort((a, b) {
      // Überfällig zuerst
      final betriebA = betriebMap[a.betriebId];
      final betriebB = betriebMap[b.betriebId];
      final saA =
          a.serverId != null ? serviceArtMap[a.serverId!] : null;
      final saB =
          b.serverId != null ? serviceArtMap[b.serverId!] : null;
      final fa = getFaelligkeit(a, datum,
          betrieb: betriebA, letzteServiceArt: saA).index;
      final fb = getFaelligkeit(b, datum,
          betrieb: betriebB, letzteServiceArt: saB).index;
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
    StateProvider<Set<FaelligkeitsStatus>>((ref) => {});

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
  final reinigungen = ref.watch(reinigungenProvider);
  final serviceArtMap = _buildLetzteServiceArtMap(reinigungen);
  final eintraege = <TourEintrag>[];

  // 1. Fällige Anlagen → Reinigungen
  final faelligeAnlagen = ref.watch(faelligeAnlagenProvider(datum));
  for (final a in faelligeAnlagen) {
    final betrieb = betriebMap[a.betriebId];
    final serviceArt =
        a.serverId != null ? serviceArtMap[a.serverId!] : null;
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
      faelligkeit: getFaelligkeit(a, datum,
          betrieb: betrieb, letzteServiceArt: serviceArt),
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
      faelligkeit: anlage != null
          ? getFaelligkeit(anlage, datum,
              betrieb: betrieb,
              letzteServiceArt: anlage.serverId != null
                  ? serviceArtMap[anlage.serverId!]
                  : null)
          : null,
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

  bool _gespeichert = false;
  bool get gespeichert => _gespeichert;

  void setFromVorschlag(List<TourEintrag> eintraege) {
    state = List.of(eintraege);
    _gespeichert = false;
  }

  void setFromGespeichert(List<TourEintrag> eintraege) {
    state = List.of(eintraege);
    _gespeichert = true;
  }

  void hinzufuegen(TourEintrag eintrag) {
    if (state.any((e) => e.id == eintrag.id)) return;
    state = [...state, eintrag];
    _gespeichert = false;
  }

  void entfernen(String id) {
    state = state.where((e) => e.id != id).toList();
    _gespeichert = false;
  }

  void leeren() {
    state = [];
    _gespeichert = false;
  }

  void reorder(int oldIndex, int newIndex) {
    final items = List.of(state);
    if (newIndex > oldIndex) newIndex--;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    state = items;
    _gespeichert = false;
  }

  void befuellenAusFaellig(List<TourEintrag> faellige) {
    final existing = state.map((e) => e.id).toSet();
    final neue = faellige.where((e) => !existing.contains(e.id)).toList();
    state = [...state, ...neue];
    _gespeichert = false;
  }

  void markGespeichert() {
    _gespeichert = true;
  }
}

// ─── Tagesplan Persistierung (Supabase) ───

Map<String, dynamic> _tourEintragToJson(TourEintrag e) => {
      'typ': e.typ.name,
      'id': e.id,
      'betriebId': e.betriebId,
      'anlageId': e.anlageId,
      'betriebName': e.betriebName,
      'betriebOrt': e.betriebOrt,
      'regionId': e.regionId,
      'beschreibung': e.beschreibung,
    };

TourEintrag _tourEintragFromJson(Map<String, dynamic> j) => TourEintrag(
      typ: TourEintragTyp.values.firstWhere(
          (t) => t.name == j['typ'],
          orElse: () => TourEintragTyp.reinigung),
      id: j['id'] as String,
      betriebId: j['betriebId'] as String?,
      anlageId: j['anlageId'] as String?,
      betriebName: j['betriebName'] as String? ?? '',
      betriebOrt: j['betriebOrt'] as String?,
      regionId: j['regionId'] as String?,
      beschreibung: j['beschreibung'] as String? ?? '',
    );

final gespeicherterTagesplanProvider =
    FutureProvider.family<List<TourEintrag>?, DateTime>((ref, datum) async {
  try {
    final datumStr = '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
    final rows = await SupabaseService.client
        .from('tagesplaene')
        .select()
        .eq('datum', datumStr)
        .limit(1);
    if (rows.isEmpty) return null;
    final eintraege = (rows.first['eintraege'] as List<dynamic>)
        .map((e) => _tourEintragFromJson(Map<String, dynamic>.from(e)))
        .toList();
    return eintraege;
  } catch (e) {
    debugPrint('[Tagesplan] Laden fehlgeschlagen: $e');
    return null;
  }
});

Future<void> tagesplanSpeichern(DateTime datum, List<TourEintrag> eintraege) async {
  final datumStr = '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
  final json = eintraege.map(_tourEintragToJson).toList();
  await SupabaseService.client.from('tagesplaene').upsert({
    'datum': datumStr,
    'eintraege': json,
    'updated_at': DateTime.now().toIso8601String(),
  }, onConflict: 'user_id,datum');
}

Future<void> tagesplanLoeschen(DateTime datum) async {
  final datumStr = '${datum.year}-${datum.month.toString().padLeft(2, '0')}-${datum.day.toString().padLeft(2, '0')}';
  await SupabaseService.client
      .from('tagesplaene')
      .delete()
      .eq('datum', datumStr);
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
