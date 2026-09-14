import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/data/local/bergkundenpauschale_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/bergkundenpauschale_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';

class TagesUebersichtData {
  final List<ReinigungLocal> reinigungen;
  final List<StoerungLocal> stoerungen;
  final List<MontageLocal> montagen;
  final List<EigenauftragLocal> eigenauftraege;
  final List<EroeffnungsreinigungLocal> eroeffnungen;
  final List<BergkundenpauschaleLocal> bergkundenpauschalen;
  final double totalCHF;
  final double monatsUmsatzCHF;

  /// Umsatz im selben Monat des Vorjahres, aber nur bis zum heutigen Tag —
  /// damit der Vergleich denselben Zeitraum misst und nicht einen halben
  /// Monat gegen einen ganzen stellt.
  final double vorjahrUmsatzCHF;

  const TagesUebersichtData({
    required this.reinigungen,
    required this.stoerungen,
    required this.montagen,
    required this.eigenauftraege,
    required this.eroeffnungen,
    required this.bergkundenpauschalen,
    required this.totalCHF,
    required this.monatsUmsatzCHF,
    this.vorjahrUmsatzCHF = 0,
  });

  int get total =>
      reinigungen.length +
      stoerungen.length +
      montagen.length +
      eigenauftraege.length +
      eroeffnungen.length;
}

final tagesUebersichtProvider = Provider<TagesUebersichtData>((ref) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  bool isToday(DateTime d) => DateTime(d.year, d.month, d.day) == todayDate;

  final hR = ref.watch(reinigungenProvider).where((r) => isToday(r.datum)).toList();
  final hS = ref.watch(stoerungenProvider).where((s) => isToday(s.datum)).toList();
  final hM = ref.watch(montagenProvider).where((m) => isToday(m.datum)).toList();
  final hE = ref.watch(eigenauftraegeProvider).where((e) => isToday(e.datum)).toList();
  final hER = ref.watch(eroeffnungsreinigungenProvider).where((e) => isToday(e.datum)).toList();
  final hBP = ref.watch(bergkundenpauschaleProvider).where((b) => isToday(b.datum)).toList();

  final totalCHF = hR.fold(0.0, (s, r) => s + (r.preisBrutto ?? 0)) +
      hS.fold(0.0, (s, r) => s + (r.preisNetto ?? 0)) +
      hM.fold(0.0, (s, r) => s + (r.kostenArbeit ?? 0)) +
      hE.fold(0.0, (s, r) => s + (r.pauschale ?? 0)) +
      hER.fold(0.0, (s, r) => s + (r.preis ?? 0)) +
      hBP.fold(0.0, (s, b) => s + b.betrag);

  // Monatsumsatz: alle Einnahmen im aktuellen Monat
  bool isThisMonth(DateTime d) => d.year == today.year && d.month == today.month;

  final mR = ref.watch(reinigungenProvider).where((r) => isThisMonth(r.datum));
  final mS = ref.watch(stoerungenProvider).where((s) => isThisMonth(s.datum));
  final mM = ref.watch(montagenProvider).where((m) => isThisMonth(m.datum));
  final mE = ref.watch(eigenauftraegeProvider).where((e) => isThisMonth(e.datum));
  final mER = ref.watch(eroeffnungsreinigungenProvider).where((e) => isThisMonth(e.datum));
  final mBP = ref.watch(bergkundenpauschaleProvider).where((b) => isThisMonth(b.datum));
  final mP = ref.watch(pikettDiensteProvider).where((p) => isThisMonth(p.datumStart));

  final monatsUmsatzCHF =
      mR.fold(0.0, (s, r) => s + (r.preisBrutto ?? 0)) +
      mS.fold(0.0, (s, r) => s + (r.preisNetto ?? 0)) +
      mM.fold(0.0, (s, r) => s + (r.kostenArbeit ?? 0)) +
      mE.fold(0.0, (s, r) => s + (r.pauschale ?? 0)) +
      mER.fold(0.0, (s, r) => s + (r.preis ?? 0)) +
      mBP.fold(0.0, (s, b) => s + b.betrag) +
      mP.fold(0.0, (s, p) => s + (p.pauschaleGesamt ?? p.pauschale ?? 0));

  // Vorjahres-Vergleich: derselbe Monat, aber nur bis zum HEUTIGEN Tag.
  //
  // WARUM nicht der ganze Vorjahresmonat: Am 14. eines Monats stünde der halbe
  // laufende Monat gegen einen vollen — der Vergleich zeigte jeden Monat bis
  // kurz vor Schluss einen Rückstand, den es nicht gibt. September 2025 lief
  // auf 10'219.66 hinaus, bis zum 14. waren es aber erst 3'425.67.
  bool isVorjahrBisHeute(DateTime d) =>
      d.year == today.year - 1 && d.month == today.month && d.day <= today.day;

  final vR = ref.watch(reinigungenProvider).where((r) => isVorjahrBisHeute(r.datum));
  final vS = ref.watch(stoerungenProvider).where((s) => isVorjahrBisHeute(s.datum));
  final vM = ref.watch(montagenProvider).where((m) => isVorjahrBisHeute(m.datum));
  final vE = ref.watch(eigenauftraegeProvider).where((e) => isVorjahrBisHeute(e.datum));
  final vER = ref
      .watch(eroeffnungsreinigungenProvider)
      .where((e) => isVorjahrBisHeute(e.datum));
  final vBP = ref
      .watch(bergkundenpauschaleProvider)
      .where((b) => isVorjahrBisHeute(b.datum));
  final vP = ref
      .watch(pikettDiensteProvider)
      .where((p) => isVorjahrBisHeute(p.datumStart));

  final vorjahrUmsatzCHF =
      vR.fold(0.0, (s, r) => s + (r.preisBrutto ?? 0)) +
      vS.fold(0.0, (s, r) => s + (r.preisNetto ?? 0)) +
      vM.fold(0.0, (s, r) => s + (r.kostenArbeit ?? 0)) +
      vE.fold(0.0, (s, r) => s + (r.pauschale ?? 0)) +
      vER.fold(0.0, (s, r) => s + (r.preis ?? 0)) +
      vBP.fold(0.0, (s, b) => s + b.betrag) +
      vP.fold(0.0, (s, p) => s + (p.pauschaleGesamt ?? p.pauschale ?? 0));

  return TagesUebersichtData(
    reinigungen: hR,
    stoerungen: hS,
    montagen: hM,
    eigenauftraege: hE,
    eroeffnungen: hER,
    bergkundenpauschalen: hBP,
    totalCHF: totalCHF,
    monatsUmsatzCHF: monatsUmsatzCHF,
    vorjahrUmsatzCHF: vorjahrUmsatzCHF,
  );
});
