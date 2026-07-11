import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

// Saison-/Übergangs-Logik für die Tourenplanung (reine Funktionen, testbar).

/// Ab dieser Schliessdauer (Tage) gilt eine Ferienperiode als "lange
/// Schliessung" und löst Endreinigung/Eröffnung aus.
const int langeSchliessungTage = 21;

const List<String> _wochentageVoll = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

bool _istRuhetag(BetriebLocal b, DateTime tag) =>
    b.ruhetage.contains(_wochentageVoll[tag.weekday - 1]);

bool _inAktiverSaison(BetriebLocal b, DateTime datum) {
  if (!b.istSaisonbetrieb) return true;
  bool inSaison = false;
  if (b.winterSaisonAktiv &&
      b.winterStartDatum != null &&
      b.winterEndeDatum != null) {
    if (!datum.isBefore(b.winterStartDatum!) &&
        !datum.isAfter(b.winterEndeDatum!)) {
      inSaison = true;
    }
  }
  if (b.sommerSaisonAktiv &&
      b.sommerStartDatum != null &&
      b.sommerEndeDatum != null) {
    if (!datum.isBefore(b.sommerStartDatum!) &&
        !datum.isAfter(b.sommerEndeDatum!)) {
      inSaison = true;
    }
  }
  return inSaison;
}

/// Kanonischer „offen"-Begriff: aktiv, nicht in Ferien, in aktiver Saison,
/// kein Ruhetag.
bool istOffenerTag(BetriebLocal b, DateTime tag) {
  if (b.status != 'aktiv') return false;
  if (istInFerien(b, tag)) return false;
  if (!_inAktiverSaison(b, tag)) return false;
  if (_istRuhetag(b, tag)) return false;
  return true;
}

/// Erster offener Tag ab [ab] (vorwärts, oder [rueckwaerts]); max. 60 Tage
/// Suchfenster, sonst null.
DateTime? naechsterOffenerTag(BetriebLocal b, DateTime ab,
    {bool rueckwaerts = false}) {
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
    BetriebLocal b, DateTime ab) {
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
