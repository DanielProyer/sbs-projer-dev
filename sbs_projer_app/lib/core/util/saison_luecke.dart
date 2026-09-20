import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Saison-Angaben, bei denen ein Betrieb dauerhaft aus dem Tourenplan fällt.
///
/// WARUM eigens geprüft: `istInAktiverSaison()` lässt Grenzen bewusst offen —
/// ein fehlendes Ende heisst «läuft weiter», ein fehlender Start «hat schon
/// begonnen» (Regel Daniel 29.07.2026). Diese Grosszügigkeit hat zwei
/// Kehrseiten, und beide enden gleich: Der Betrieb erscheint nie wieder, ohne
/// dass irgendwo etwas rot wird.
///
/// Am 20.09.2026 nachgezählt: 25 von 96 operativen Saisonbetrieben — 21-mal
/// ein Fenster ohne Start, 4-mal gar keine Saison angehakt. Die vier ohne
/// Saison waren allesamt **keine eigenen Kunden** (Alpina Vals, Pellas
/// Vignogn, Rätia Filisur, Weiss Kreuz Preda); `saisonLueckenProvider`
/// filtert die weg, gemeldet werden **21**. Diese Funktion prüft nur die
/// Angabe selbst — wer sie anderswo verwendet, filtert selbst.
///
/// Was hier bewusst NICHT gemeldet wird: ein vollständiges Fenster, das
/// abgelaufen ist (Winter 2025/26, neue Daten noch nicht erfasst). Das ist
/// normale Herbstarbeit und keine kaputte Angabe — es liegen Start UND Ende
/// vor, sie werden jedes Jahr nachgeführt. Eine Warnung dafür stünde von
/// April bis November und wäre nur noch Tapete.
enum SaisonLuecke {
  /// Saisonbetrieb, bei dem weder Winter noch Sommer angehakt ist.
  /// `istInAktiverSaison()` liefert dann für JEDEN Tag false.
  keineSaisonAngehakt,

  /// Wintersaison mit Enddatum, aber ohne Startdatum. Das Fenster heisst
  /// «bis zum Ende» — ist das Ende vorbei, schliesst es sich für immer.
  winterOhneStart,

  /// Dasselbe für die Sommersaison.
  sommerOhneStart,
}

extension SaisonLueckeText on SaisonLuecke {
  String get kurz => switch (this) {
    SaisonLuecke.keineSaisonAngehakt => 'keine Saison angehakt',
    SaisonLuecke.winterOhneStart => 'Winter ohne Startdatum',
    SaisonLuecke.sommerOhneStart => 'Sommer ohne Startdatum',
  };

  String get erklaerung => switch (this) {
    SaisonLuecke.keineSaisonAngehakt =>
      'Als Saisonbetrieb gekennzeichnet, aber weder Winter- noch '
          'Sommersaison angehakt — er erscheint an keinem einzigen Tag.',
    SaisonLuecke.winterOhneStart =>
      'Wintersaison hat ein Ende, aber keinen Start. Ab dem Enddatum '
          'verschwindet der Betrieb dauerhaft.',
    SaisonLuecke.sommerOhneStart =>
      'Sommersaison hat ein Ende, aber keinen Start. Ab dem Enddatum '
          'verschwindet der Betrieb dauerhaft.',
  };
}

/// Alle Lücken eines Betriebs. Leer = in Ordnung.
///
/// Ein Fenster ganz ohne Daten (Start und Ende leer) ist KEINE Lücke: Es
/// bedeutet «unbefristet offen» und der Betrieb bleibt sichtbar.
List<SaisonLuecke> saisonLuecken(BetriebLocal b) {
  if (!b.istSaisonbetrieb) return const [];
  if (!b.winterSaisonAktiv && !b.sommerSaisonAktiv) {
    return const [SaisonLuecke.keineSaisonAngehakt];
  }
  final l = <SaisonLuecke>[];
  if (b.winterSaisonAktiv &&
      b.winterStartDatum == null &&
      b.winterEndeDatum != null) {
    l.add(SaisonLuecke.winterOhneStart);
  }
  if (b.sommerSaisonAktiv &&
      b.sommerStartDatum == null &&
      b.sommerEndeDatum != null) {
    l.add(SaisonLuecke.sommerOhneStart);
  }
  return l;
}

/// Schiebt ein vergangenes Saisondatum auf die nächste Saison vor.
///
/// Saisondaten wiederholen sich jährlich um wenige Tage — Acla Grischuna
/// endete fünf Winter in Folge zwischen dem 30. März und dem 4. April
/// (siehe `saison_historie.dart`). Das Datum des Vorjahres ist deshalb der
/// beste Ausgangspunkt, den die App aus eigener Kraft kennt; bestätigen oder
/// korrigieren muss es der Mensch.
///
/// Liegt [datum] noch in der Zukunft, bleibt es unverändert — dann gibt es
/// nichts vorzuschlagen. `null` bleibt `null`: Für ein Fenster ohne Start
/// lässt sich nichts ableiten, dort hilft nur die Ansage des Betriebs.
///
/// Am 29. Februar rutscht der Vorschlag auf den 1. März. Für eine
/// Saisongrenze ist der eine Tag ohne Belang.
DateTime? saisonVorschlag(DateTime? datum, DateTime heute) {
  if (datum == null) return null;
  final h = DateTime(heute.year, heute.month, heute.day);
  var d = DateTime(datum.year, datum.month, datum.day);
  while (d.isBefore(h)) {
    d = DateTime(d.year + 1, datum.month, datum.day);
  }
  return d;
}

/// Ist der Betrieb bereits aus dem Plan gefallen, oder fällt er noch?
/// Massgebend ist das späteste Ende der lückenhaften Fenster.
bool saisonLueckeWirktSchon(BetriebLocal b, DateTime heute) {
  final l = saisonLuecken(b);
  if (l.isEmpty) return false;
  if (l.contains(SaisonLuecke.keineSaisonAngehakt)) return true;
  final h = DateTime(heute.year, heute.month, heute.day);
  DateTime? spaetestes;
  for (final x in l) {
    final ende = x == SaisonLuecke.winterOhneStart
        ? b.winterEndeDatum
        : b.sommerEndeDatum;
    if (ende == null) continue;
    if (spaetestes == null || ende.isAfter(spaetestes)) spaetestes = ende;
  }
  return spaetestes != null && spaetestes.isBefore(h);
}
