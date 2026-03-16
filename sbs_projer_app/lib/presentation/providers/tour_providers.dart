import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/region_repository.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';

// ─── Regionen ───

final regionenStreamProvider = StreamProvider<List<RegionLocal>>((ref) {
  return RegionRepository.watchAll();
});

final regionenProvider = Provider<List<RegionLocal>>((ref) {
  return ref.watch(regionenStreamProvider).valueOrNull ?? [];
});

// ─── Fälligkeits-Status ───

enum FaelligkeitsStatus { ueberfaellig, faellig, baldFaellig, nichtFaellig }

FaelligkeitsStatus getFaelligkeit(AnlageLocal anlage, DateTime datum) {
  if (anlage.naechsteReinigung == null) return FaelligkeitsStatus.nichtFaellig;
  final diff = datum.difference(anlage.naechsteReinigung!).inDays;
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

    // Betrieb offen?
    final betrieb = betriebMap[a.betriebId];
    if (betrieb != null && !isBetriebOffen(betrieb, datum)) return false;

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
