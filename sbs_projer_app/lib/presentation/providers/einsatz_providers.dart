import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Beleg-Ids mit Ertragsbuchung im Kalenderjahr — eine Anfrage je Jahr,
/// gecacht, solange der Screen offen ist. Grundlage für «verrechnet» bei
/// Reinigungen (siehe `einsatz_lage.dart`).
final belegIdsMitBuchungProvider = FutureProvider.family<Set<String>, int>((
  ref,
  jahr,
) {
  return BuchungRepository.belegIdsMitBuchung(
    ab: DateTime(jahr, 1, 1),
    bis: DateTime(jahr, 12, 31),
  );
});

/// Alle Einsätze eines Kalenderjahres, als eine Liste, neuestes Datum zuerst.
///
/// Reinigungen kommen jahresweise vom Server (rund 1'000 je Jahr), alle
/// anderen Typen liegen ohnehin vollständig im Speicher und werden hier auf
/// das Jahr gefiltert. Termine sind nur die offenen — die erledigten sind als
/// Saison-Beleg schon in der Liste.
final einsaetzeProvider = FutureProvider.family<List<Einsatz>, int>((
  ref,
  jahr,
) async {
  final betriebe = ref.watch(betriebLookupProvider);
  final reinigungen = await ref.watch(reinigungenByJahrProvider(jahr).future);
  final belegIds = await ref.watch(belegIdsMitBuchungProvider(jahr).future);
  final termine = await ref.watch(offeneTermineProvider.future);

  bool imJahr(DateTime d) => d.year == jahr;

  final liste = <Einsatz>[
    for (final r in reinigungen)
      einsatzAusReinigung(
        r,
        betrieb: betriebe[r.betriebId],
        hatBuchung: r.serverId != null && belegIds.contains(r.serverId),
      ),
    for (final s in ref.watch(stoerungenProvider))
      if (imJahr(s.datum))
        einsatzAusStoerung(s, betrieb: betriebe[s.betriebId]),
    for (final m in ref.watch(montagenProvider))
      if (imJahr(m.datum)) einsatzAusMontage(m, betrieb: betriebe[m.betriebId]),
    for (final e in ref.watch(eigenauftraegeProvider))
      if (imJahr(e.datum))
        einsatzAusEigenauftrag(e, betrieb: betriebe[e.betriebId]),
    for (final s in ref.watch(eroeffnungsreinigungenProvider))
      if (imJahr(s.datum))
        einsatzAusSaisonreinigung(s, betrieb: betriebe[s.betriebId]),
    for (final p in ref.watch(pikettDiensteProvider))
      if (imJahr(p.datumStart)) einsatzAusPikett(p),
    for (final t in termine)
      if (imJahr(t.datum)) einsatzAusTermin(t, betrieb: betriebe[t.betriebId]),
  ]..sort((a, b) => b.datum.compareTo(a.datum));
  return liste;
});

/// Anstehende Einsätze für die Aufgabenliste (B6): Störungen, Montagen,
/// Eigenaufträge und offene Termine mit Stufe offen/geplant/inArbeit — aus
/// den Speicher-Providern über die B2-Adapter, ohne Jahresgrenze und ohne
/// Buchungsabfrage (für Offenes belanglos). Saison-Termine laufen in der
/// Aufgabenliste als eigene Quelle und fehlen hier; Reinigungen («offen» =
/// Entwurf), Saison-Belege und Pikett sind nie Aufgaben.
final anstehendeEinsaetzeProvider = Provider<List<Einsatz>>((ref) {
  final betriebe = ref.watch(betriebLookupProvider);
  const anstehend = {
    EinsatzStatus.offen,
    EinsatzStatus.geplant,
    EinsatzStatus.inArbeit,
  };
  final termine = ref.watch(offeneTermineProvider).valueOrNull ?? const [];
  return [
    for (final s in ref.watch(stoerungenProvider))
      einsatzAusStoerung(s, betrieb: betriebe[s.betriebId]),
    for (final m in ref.watch(montagenProvider))
      einsatzAusMontage(m, betrieb: betriebe[m.betriebId]),
    for (final e in ref.watch(eigenauftraegeProvider))
      einsatzAusEigenauftrag(e, betrieb: betriebe[e.betriebId]),
    for (final t in termine)
      if (t.typ != 'eroeffnungsreinigung' && t.typ != 'endreinigung')
        einsatzAusTermin(t, betrieb: betriebe[t.betriebId]),
  ].where((e) => anstehend.contains(e.status)).toList();
});
