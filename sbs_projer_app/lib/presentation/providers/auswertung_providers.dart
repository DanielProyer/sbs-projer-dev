import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/bergkundenpauschale_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/bergkundenpauschale_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_aggregat.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_modell.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_mwst.dart';

/// serverIds der Betriebe mit Rechnungsstellung an Heineken.
final heinekenBetriebIdsProvider = Provider<Set<String>>((ref) {
  final betriebe = ref.watch(betriebeProvider);
  return {
    for (final BetriebLocal b in betriebe)
      if (b.serverId != null && b.rechnungsstellung == 'heineken') b.serverId!,
  };
});

/// Live-Aggregat der Auswertung über alle Arbeitsarten (Jahr/Monat).
final auswertungProvider = Provider<AuswertungDaten>((ref) {
  final hkIds = ref.watch(heinekenBetriebIdsProvider);
  final posten = <ArbeitsPosten>[];

  ArbeitsPosten p(AuswertungKategorie k, DateTime d, double netto) =>
      ArbeitsPosten(k, d.year, d.month, netto, netto * mwstFaktor(d.year));

  for (final ReinigungLocal r in ref.watch(reinigungenProvider)) {
    final netto = r.preisNetto ?? 0;
    final kat = hkIds.contains(r.betriebId)
        ? AuswertungKategorie.reinigungHk
        : AuswertungKategorie.reinigung;
    posten.add(p(kat, r.datum, netto));
  }
  for (final StoerungLocal s in ref.watch(stoerungenProvider)) {
    posten.add(p(AuswertungKategorie.stoerung, s.datum, s.preisNetto ?? 0));
  }
  for (final MontageLocal m in ref.watch(montagenProvider)) {
    posten.add(p(AuswertungKategorie.montage, m.datum, m.kostenArbeit ?? 0));
  }
  for (final EigenauftragLocal e in ref.watch(eigenauftraegeProvider)) {
    posten.add(p(AuswertungKategorie.eigenauftrag, e.datum, e.pauschale ?? 0));
  }
  for (final EroeffnungsreinigungLocal e
      in ref.watch(eroeffnungsreinigungenProvider)) {
    posten.add(p(AuswertungKategorie.eroeffnung, e.datum, e.preis ?? 0));
  }
  for (final BergkundenpauschaleLocal b
      in ref.watch(bergkundenpauschaleProvider)) {
    posten.add(p(AuswertungKategorie.bkPauschale, b.datum, b.betrag));
  }
  for (final PikettDienstLocal pk in ref.watch(pikettDiensteProvider)) {
    posten.add(p(AuswertungKategorie.pikett, pk.datumStart,
        pk.pauschaleGesamt ?? pk.pauschale ?? 0));
  }

  return aggregiere(posten);
});
