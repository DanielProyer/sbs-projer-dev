import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Saison-Angaben, bei denen ein Betrieb dauerhaft aus dem Tourenplan fällt.
///
/// WARUM eigens geprüft: `istInAktiverSaison()` lässt Grenzen bewusst offen —
/// ein fehlendes Ende heisst «läuft weiter», ein fehlender Start «hat schon
/// begonnen» (Regel Daniel 29.07.2026). Diese Grosszügigkeit hat zwei
/// Kehrseiten, und beide enden gleich: Der Betrieb erscheint nie wieder, ohne
/// dass irgendwo etwas rot wird.
///
/// Am 20.09.2026 nachgezählt: **25 von 96 operativen Saisonbetrieben** —
/// 21-mal ein Fenster ohne Start, 4-mal gar keine Saison angehakt.
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
