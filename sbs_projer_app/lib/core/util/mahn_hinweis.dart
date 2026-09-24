/// Hinweis beim Service (Mahnwesen Teil 3, v0.136.0) — rein, ohne I/O.
///
/// WARUM: Wer vor Ort eine Reinigung, Störung oder Montage erfasst, soll
/// sehen, dass der Betrieb gemahnte Rechnungen hat — und bei einem Mahnfall,
/// dass nur noch gegen Barzahlung gearbeitet wird (Spec §6).
/// Spec: docs/superpowers/specs/2026-09-23-mahnwesen-design.md
library;

import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

enum MahnHinweisStufe { keine, gemahnt, mahnfall }

final DateFormat _ddMMyyyy = DateFormat('dd.MM.yyyy');

class MahnHinweis {
  final MahnHinweisStufe stufe;

  /// Offene Rechnungen des Betriebs im Mahnbereich (ab 2026), älteste zuerst.
  final List<Rechnung> offene;
  final int anzahlGemahnt;
  final double summeOffen;

  /// Datum der frühesten 1. Mahnung unter den gemahnten Rechnungen.
  final DateTime? ersteMahnungAm;

  const MahnHinweis({
    required this.stufe,
    required this.offene,
    required this.anzahlGemahnt,
    required this.summeOffen,
    this.ersteMahnungAm,
  });

  /// «2 Rechnungen gemahnt, CHF 188.10 offen (1. Mahnung vom 20.07.2026)»;
  /// bei Mahnfall zusätzlich « — nur gegen Barzahlung». Leer bei
  /// [MahnHinweisStufe.keine].
  String get text {
    if (stufe == MahnHinweisStufe.keine) return '';
    final wort = anzahlGemahnt == 1 ? 'Rechnung' : 'Rechnungen';
    final b = StringBuffer('$anzahlGemahnt $wort gemahnt, CHF ${chf(summeOffen)} offen');
    if (ersteMahnungAm != null) {
      b.write(' (1. Mahnung vom ${_ddMMyyyy.format(ersteMahnungAm!)})');
    }
    if (stufe == MahnHinweisStufe.mahnfall) b.write(' — nur gegen Barzahlung');
    return b.toString();
  }
}

bool _gemahnt(Rechnung r) =>
    r.zahlungsstatus == 'mahnung_1' || r.zahlungsstatus == 'mahnung_2';

/// [rechnungen] = alle Rechnungen des Betriebs; [imMahnfall] = Rechnung-Ids
/// in sperrenden Mahnfällen des Betriebs (`sperrtRechnungen`).
MahnHinweis mahnHinweis({
  required List<Rechnung> rechnungen,
  required Set<String> imMahnfall,
}) {
  final offene = rechnungen.where(imMahnbereich).toList()
    ..sort((a, b) {
      final c = a.rechnungsdatum.compareTo(b.rechnungsdatum);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final gemahnt = offene.where(_gemahnt).toList();
  DateTime? erste;
  for (final r in gemahnt) {
    final m = r.mahnung1Am;
    if (m != null && (erste == null || m.isBefore(erste))) erste = m;
  }
  final summe = rundeAufRappen(offene.fold(0.0, (s, r) => s + r.betragBrutto));
  final stufe = offene.any((r) => imMahnfall.contains(r.id))
      ? MahnHinweisStufe.mahnfall
      : gemahnt.isNotEmpty
          ? MahnHinweisStufe.gemahnt
          : MahnHinweisStufe.keine;
  return MahnHinweis(
    stufe: stufe,
    offene: offene,
    anzahlGemahnt: gemahnt.length,
    summeOffen: summe,
    ersteMahnungAm: erste,
  );
}
