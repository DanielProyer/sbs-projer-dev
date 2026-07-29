import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

// Saison-/Übergangs-Logik für die Tourenplanung (reine Funktionen, testbar).

/// Ab dieser Schliessdauer (Tage) gilt eine Ferienperiode als "lange
/// Schliessung" und löst Endreinigung/Eröffnung aus.
const int langeSchliessungTage = 21;

// Ruhetag-Erkennung liegt in touren_anzeige.dart und versteht Kürzel wie
// volle Namen. Hier stand früher eine eigene Prüfung nur auf volle Namen —
// da die Betriebe Kürzel speichern, wurde nie ein Ruhetag erkannt.
bool _istRuhetag(BetriebLocal b, DateTime tag) => istRuhetag(b.ruhetage, tag);

/// Liegt [datum] im Saisonfenster [von]–[bis]?
///
/// Die Grenzen sind offen (Regel Daniel 29.07.2026): Ein fehlendes Enddatum
/// heisst «läuft weiter» — genau der Normalfall einer laufenden Saison, deren
/// Ende noch nicht feststeht. Ein fehlendes Startdatum heisst «hat schon
/// begonnen». Fehlen beide, ist die Saison unbefristet offen.
///
/// Liegt der Start NACH dem Ende, umspannt das Fenster den Jahreswechsel
/// (Wintersaison 01.12.–01.04.) und gilt ab dem Start ODER bis zum Ende.
bool _imFenster(DateTime? von, DateTime? bis, DateTime datum) {
  final d = DateTime(datum.year, datum.month, datum.day);
  if (von == null && bis == null) return true;
  if (von == null) return !d.isAfter(bis!);
  if (bis == null) return !d.isBefore(von);
  if (von.isAfter(bis)) return !d.isBefore(von) || !d.isAfter(bis);
  return !d.isBefore(von) && !d.isAfter(bis);
}

/// Ist der Betrieb an diesem Tag in einer aktiven Saison?
///
/// Ein Betrieb ohne Saisonbetrieb-Kennzeichen ist immer in Saison. Sonst muss
/// mindestens eine der beiden angehakten Saisons das Datum abdecken; zu den
/// offenen Grenzen siehe [_imFenster].
bool istInAktiverSaison(BetriebLocal b, DateTime datum) {
  if (!b.istSaisonbetrieb) return true;
  if (b.winterSaisonAktiv &&
      _imFenster(b.winterStartDatum, b.winterEndeDatum, datum)) {
    return true;
  }
  if (b.sommerSaisonAktiv &&
      _imFenster(b.sommerStartDatum, b.sommerEndeDatum, datum)) {
    return true;
  }
  return false;
}

/// Betrieb an diesem Tag in einer Schliessung (Saisonpause oder Ferien)?
/// Ruhetage und Status zählen bewusst nicht — gleiche Definition wie beim
/// Fälligkeits-Anker.
bool istInSchliessung(BetriebLocal b, DateTime tag) =>
    !istInAktiverSaison(b, tag) || istInFerien(b, tag);

/// Kanonischer „offen"-Begriff: aktiv, nicht in Ferien, in aktiver Saison,
/// kein Ruhetag.
bool istOffenerTag(BetriebLocal b, DateTime tag) {
  if (b.status != 'aktiv') return false;
  if (istInFerien(b, tag)) return false;
  if (!istInAktiverSaison(b, tag)) return false;
  if (_istRuhetag(b, tag)) return false;
  return true;
}

/// Erster offener Tag ab [ab] (vorwärts, oder [rueckwaerts]); max. 60 Tage
/// Suchfenster, sonst null.
DateTime? naechsterOffenerTag(
  BetriebLocal b,
  DateTime ab, {
  bool rueckwaerts = false,
}) {
  var tag = DateTime(ab.year, ab.month, ab.day);
  for (var i = 0; i < 60; i++) {
    if (istOffenerTag(b, tag)) return tag;
    tag = tag.add(Duration(days: rueckwaerts ? -1 : 1));
  }
  return null;
}

/// Nächste relevante Schliessung ab [ab]: der erste **geschlossene** Tag der
/// Schliessung (Saisonende+1 oder Ferienstart) plus Flag, ob Saisonende.
/// Nur Saisonende und Ferien ab [langeSchliessungTage].
({DateTime datum, bool istSaisonende})? qualifizierteSchliessung(
  BetriebLocal b,
  DateTime ab,
) {
  final kandidaten = <({DateTime datum, bool istSaisonende})>[];

  if (b.istSaisonbetrieb) {
    for (final ende in [
      if (b.sommerSaisonAktiv) b.sommerEndeDatum,
      if (b.winterSaisonAktiv) b.winterEndeDatum,
    ]) {
      if (ende != null) {
        final closed = ende.add(const Duration(days: 1));
        if (!closed.isBefore(ab)) {
          kandidaten.add((datum: closed, istSaisonende: true));
        }
      }
    }
  }

  for (final s in ferienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    final dauer = s.ende!.difference(s.start!).inDays + 1;
    if (dauer >= langeSchliessungTage && !s.start!.isBefore(ab)) {
      kandidaten.add((datum: s.start!, istSaisonende: false));
    }
  }

  if (kandidaten.isEmpty) return null;
  kandidaten.sort((x, y) => x.datum.compareTo(y.datum));
  return kandidaten.first;
}

/// Nächste Wiedereröffnung strikt nach [ab] (Saisonstart oder Ferienende+1).
DateTime? oeffnungNach(BetriebLocal b, DateTime ab) {
  DateTime? naechste;
  if (b.istSaisonbetrieb) {
    for (final start in [
      if (b.sommerSaisonAktiv) b.sommerStartDatum,
      if (b.winterSaisonAktiv) b.winterStartDatum,
    ]) {
      if (start != null && start.isAfter(ab)) {
        if (naechste == null || start.isBefore(naechste)) naechste = start;
      }
    }
  }
  for (final ende in ferienEnden(b)) {
    final reopen = ende.add(const Duration(days: 1));
    if (reopen.isAfter(ab)) {
      if (naechste == null || reopen.isBefore(naechste)) naechste = reopen;
    }
  }
  return naechste;
}

/// Anker für die Fälligkeits-Uhr (Regel Daniel 17.07.2026): War der Betrieb am
/// Tag nach der letzten Reinigung GESCHLOSSEN (Saisonpause oder Ferien —
/// Ruhetage zählen bewusst NICHT), startet die Zählung erst bei der
/// Wiedereröffnung. Deckt die Endreinigung am Saisonschluss UND die
/// Eröffnungsreinigung kurz vor Saisonstart ab. null = geschlossen, aber keine
/// Wiedereröffnung gepflegt -> Aufrufer zeigt die "Saisondaten fehlen"-Meldung.
DateTime? faelligkeitsAnker(BetriebLocal b, DateTime letzteReinigung) {
  final tagDanach = DateTime(
    letzteReinigung.year,
    letzteReinigung.month,
    letzteReinigung.day,
  ).add(const Duration(days: 1));
  final geschlossen =
      !istInAktiverSaison(b, tagDanach) || istInFerien(b, tagDanach);
  if (!geschlossen) return letzteReinigung;
  return oeffnungNach(b, letzteReinigung);
}
