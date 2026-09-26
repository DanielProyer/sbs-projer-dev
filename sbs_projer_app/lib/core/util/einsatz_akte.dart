/// Die Einsätze eines Betriebs (oder einer Anlage) als eine Liste — die
/// «Akte» auf der Betriebs- und der Anlagenseite (T10).
///
/// WARUM: Die Betriebsseite hatte drei getrennte Listen (Reinigungen,
/// Störungen, Eigenaufträge), Montagen fehlten ganz. Hier laufen alle Typen
/// über dieselben Adapter wie der Einsätze-Screen (`einsatz.dart`), damit
/// Status und Betrag überall gleich aussehen.
library;

import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';

/// Neueste zuerst. Mit [anlageId] nur, was an dieser Anlage hängt —
/// Reinigungen auch über `anlageIds` (Sammelreinigung), Saisonbelege gar
/// nicht (sie gelten für den ganzen Betrieb). Pikett hängt an keinem Betrieb
/// und kommt hier nie vor.
List<Einsatz> einsaetzeDerAkte({
  required BetriebLocal? betrieb,
  List<ReinigungLocal> reinigungen = const [],
  List<StoerungLocal> stoerungen = const [],
  List<MontageLocal> montagen = const [],
  List<EigenauftragLocal> eigenauftraege = const [],
  List<EroeffnungsreinigungLocal> saisonreinigungen = const [],
  required Set<String> belegIdsMitBuchung,
  String? anlageId,
}) {
  bool passt(String? a) => anlageId == null || a == anlageId;
  final liste = <Einsatz>[
    for (final r in reinigungen)
      if (anlageId == null ||
          r.anlageId == anlageId ||
          r.anlageIds.contains(anlageId))
        einsatzAusReinigung(
          r,
          betrieb: betrieb,
          hatBuchung:
              r.serverId != null && belegIdsMitBuchung.contains(r.serverId),
        ),
    for (final s in stoerungen)
      if (passt(s.anlageId)) einsatzAusStoerung(s, betrieb: betrieb),
    for (final m in montagen)
      if (passt(m.anlageId)) einsatzAusMontage(m, betrieb: betrieb),
    for (final e in eigenauftraege)
      if (passt(e.anlageId)) einsatzAusEigenauftrag(e, betrieb: betrieb),
    if (anlageId == null)
      for (final s in saisonreinigungen)
        einsatzAusSaisonreinigung(s, betrieb: betrieb),
  ]..sort((a, b) => b.datum.compareTo(a.datum));
  return liste;
}
