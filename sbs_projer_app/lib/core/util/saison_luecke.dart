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

/// Letzter Tag, an dem den Betrieb überhaupt noch ein Saisonfenster trägt —
/// `null`, wenn ihn eines dauerhaft trägt oder gar keines angehakt ist.
///
/// WARUM das nötig wurde: Bis zum 20.09.2026 meldete die Warnung «bereits aus
/// dem Plan gefallen», sobald das lückenhafte Fenster abgelaufen war. Das war
/// falsch — nachgerechnet trug an jenem Tag **jeden der 21 gemeldeten
/// Betriebe** noch sein Sommerfenster, keiner war draussen. Die Lücke wirkt
/// erst, wenn auch das andere Fenster ausläuft.
///
/// Ein Fenster läuft **nie** ab, wenn sein Ende fehlt («läuft weiter»), wenn
/// beide Grenzen fehlen («unbefristet offen») oder wenn der Start nach dem
/// Ende liegt — das umspannt den Jahreswechsel und gilt damit jedes Jahr.
/// In allen drei Fällen fällt der Betrieb nie heraus; dafür fehlt ihm die
/// Pause, er wird also auch in der Sperrzeit eingeplant. Beides ist falsch,
/// aber verschieden dringend.
DateTime? saisonDeckungBis(BetriebLocal b) {
  if (!b.istSaisonbetrieb) return null;
  final fenster = <(DateTime?, DateTime?)>[
    if (b.winterSaisonAktiv) (b.winterStartDatum, b.winterEndeDatum),
    if (b.sommerSaisonAktiv) (b.sommerStartDatum, b.sommerEndeDatum),
  ];
  if (fenster.isEmpty) return null; // gar keine Saison — eigener Fall
  DateTime? spaetestes;
  for (final (von, bis) in fenster) {
    if (bis == null) return null; // läuft weiter
    if (von != null && von.isAfter(bis)) return null; // über den Jahreswechsel
    final b2 = DateTime(bis.year, bis.month, bis.day);
    if (spaetestes == null || b2.isAfter(spaetestes)) spaetestes = b2;
  }
  return spaetestes;
}

/// Fehlen dem Betrieb die Saisondaten für die kommende Saison?
///
/// Genau die Frage, die sich beim Reinigen vor Ort stellt: Muss ich den Wirt
/// jetzt nach Saisonende und -start fragen? Zwei Fälle zählen:
///
/// 1. Eine **Lücke** im Sinne von [saisonLuecken] — ein Fenster ohne Start
///    oder gar keine angehakte Saison.
/// 2. **Kein einziges der vier Daten liegt in der Zukunft.** Die Angaben sind
///    dann zwar vollständig, aber von der letzten Saison; für die kommende
///    weiss die App nichts. Am 20.09.2026 traf das 19 Betriebe.
///
/// Ein Betrieb mit gepflegten künftigen Daten fällt bewusst durch — dort gibt
/// es nichts zu fragen.
bool saisondatenUnvollstaendig(BetriebLocal b, DateTime heute) {
  if (!b.istSaisonbetrieb) return false;
  if (saisonLuecken(b).isNotEmpty) return true;
  final h = DateTime(heute.year, heute.month, heute.day);
  final daten = <DateTime?>[
    if (b.winterSaisonAktiv) b.winterStartDatum,
    if (b.winterSaisonAktiv) b.winterEndeDatum,
    if (b.sommerSaisonAktiv) b.sommerStartDatum,
    if (b.sommerSaisonAktiv) b.sommerEndeDatum,
  ];
  // Kein Datum erfasst heisst «unbefristet offen» — das ist eine bewusste
  // Angabe und keine Lücke (siehe [saisonLuecken]).
  if (daten.every((d) => d == null)) return false;
  return !daten.any((d) => d != null && !d.isBefore(h));
}

/// Was die Lücke praktisch bedeutet — fertig für die Anzeige.
String saisonLueckeWirkung(BetriebLocal b, DateTime heute) {
  if (saisonLuecken(b).contains(SaisonLuecke.keineSaisonAngehakt)) {
    return 'erscheint an keinem einzigen Tag';
  }
  final bis = saisonDeckungBis(b);
  if (bis == null) {
    return 'Pause fehlt — wird auch in der Sperrzeit eingeplant';
  }
  final h = DateTime(heute.year, heute.month, heute.day);
  final ab = bis.add(const Duration(days: 1));
  final d =
      '${ab.day.toString().padLeft(2, '0')}.'
      '${ab.month.toString().padLeft(2, '0')}.${ab.year}';
  return ab.isAfter(h) ? 'fällt am $d aus dem Plan' : 'seit $d aus dem Plan';
}
