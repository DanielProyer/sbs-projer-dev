import 'package:sbs_projer_app/core/util/betrieb_ferien.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

// Saison-/Übergangs-Logik für die Tourenplanung (reine Funktionen, testbar).

/// Ab dieser Schliessdauer (Tage) gilt eine Ferienperiode als "lange
/// Schliessung" und löst Endreinigung/Eröffnung aus.
const int langeSchliessungTage = 21;

/// Fenster (Tage), in dem eine Saison-Reinigung rund um die Schliessung
/// geplant werden darf: die letzten [saisonReinigungFensterTage] Tage vor der
/// Wiedereröffnung (Eröffnungsreinigung) bzw. die ersten Tage der Schliessung
/// (Endreinigung).
///
/// Regel Daniel 08.08.2026 (Fall Pizzeria Paradies): Früher zählte nur der
/// letzte Schliessungstag. Daniel plant den Service aber dann, wenn er in die
/// Tour passt — und der letzte Schliessungstag ist oft gerade Ruhetag. Damit
/// fiel jeder Betrieb durch, dessen letzter Schliessungstag nicht passte.
const int saisonReinigungFensterTage = 7;

/// Zählt diese Service-Art als Endreinigung?
///
/// Gross-/kleinschreibungsunempfindlich: Die Alt-Daten schreiben
/// «Endreinigung» (478 Sätze bis 19.11.2025), erst ab 30.03.2026 steht
/// `endreinigung` klein. Ein exakter Vergleich griff bei keinem Betrieb mit
/// Alt-Historie.
bool istEndreinigungsArt(String? serviceArt) =>
    serviceArt?.toLowerCase() == 'endreinigung';

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

/// Warum ist der Betrieb an diesem Tag zu? `null` = er ist offen.
///
/// Für die Warnung im Tagesplan: «Betrieb geschlossen» allein sagt Daniel
/// nicht, ob er den Besuch verschieben (Ruhetag → morgen wieder offen) oder
/// ganz streichen muss (Ferien bis in drei Wochen). Reihenfolge wie in
/// [istOffenerTag]; genannt wird der erste zutreffende Grund.
/// Ferien nennen zusätzlich das Enddatum, sofern erfasst.
String? schliessungsGrund(BetriebLocal b, DateTime tag) {
  if (b.status != 'aktiv') {
    return b.status == 'geschlossen'
        ? 'Betrieb geschlossen'
        : 'Betrieb inaktiv';
  }
  if (istInFerien(b, tag)) {
    for (final s in ferienSlots(b)) {
      if (s.start == null || s.ende == null) continue;
      if (!tag.isBefore(s.start!) && !tag.isAfter(s.ende!)) {
        final e = s.ende!;
        final d = e.day.toString().padLeft(2, '0');
        final m = e.month.toString().padLeft(2, '0');
        return 'Betriebsferien bis $d.$m.';
      }
    }
    return 'Betriebsferien';
  }
  if (!istInAktiverSaison(b, tag)) return 'Zwischensaison';
  if (_istRuhetag(b, tag)) return 'Ruhetag';
  return null;
}

/// Darf eine Saison-Reinigung an einem Schliessungstag geplant werden?
///
/// Regel (Fall Löwen Grossdietwil, 04.08.2026): Eine **Eröffnungsreinigung**
/// findet naturgemäss statt, solange der Betrieb noch zu ist — kurz vor der
/// Wiedereröffnung. Spiegelbildlich die **Endreinigung** zu Beginn der
/// Schliessung. Tief in der Schliessung bleibt beides ausgeblendet; normale
/// Reinigungen sowieso.
///
/// Massgebend ist nicht mehr der einzelne Rand-Tag, sondern das Fenster von
/// [saisonReinigungFensterTage] Tagen (Regel Daniel 08.08.2026, siehe dort).
///
/// [art] wie `TerminDto.typ`: 'eroeffnungsreinigung' | 'endreinigung'.
/// Schliessung = Saisonpause oder Ferien ([istInSchliessung]) — Ruhetage
/// zählen bewusst nicht, ein inaktiver/geschlossener Betrieb nie.
bool darfTrotzSchliessungGeplantWerden({
  required String art,
  required BetriebLocal betrieb,
  required DateTime tag,
}) =>
    _fensterTag(art: art, betrieb: betrieb, tag: tag) != null;

/// Der wievielte Tag des Fensters ist [tag]? 1 = unmittelbar am Rand
/// (letzter Schliessungstag bzw. erster Tag der Schliessung), maximal
/// [saisonReinigungFensterTage]. `null` = ausserhalb des Fensters.
int? _fensterTag({
  required String art,
  required BetriebLocal betrieb,
  required DateTime tag,
}) {
  if (betrieb.status != 'aktiv') return null;
  final t = DateTime(tag.year, tag.month, tag.day);
  if (!istInSchliessung(betrieb, t)) return null;
  final rueckwaerts = art == 'endreinigung';
  if (art != 'eroeffnungsreinigung' && !rueckwaerts) return null;
  for (var i = 1; i <= saisonReinigungFensterTage; i++) {
    final nachbar = rueckwaerts
        ? t.subtract(Duration(days: i))
        : t.add(Duration(days: i));
    if (!istInSchliessung(betrieb, nachbar)) return i;
  }
  return null;
}

/// Hinweis-Text, warum eine Saison-Reinigung trotz Schliessung im Plan
/// stehen darf — fürs Band am Tagesplan-Block. `null`, wenn
/// [darfTrotzSchliessungGeplantWerden] den Tag nicht zulässt.
String? saisonPlanungsHinweis({
  required String art,
  required BetriebLocal betrieb,
  required DateTime tag,
}) {
  final n = _fensterTag(art: art, betrieb: betrieb, tag: tag);
  if (n == null) return null;
  final inFerien = istInFerien(betrieb, tag);
  if (art == 'eroeffnungsreinigung') {
    if (n > 1) return 'Öffnet in $n Tagen — Eröffnung';
    return inFerien
        ? 'Letzter Ferientag — Eröffnung'
        : 'Letzter Schliessungstag — Eröffnung';
  }
  if (n > 1) {
    return inFerien
        ? '$n. Ferientag — Endreinigung'
        : '$n. Schliessungstag — Endreinigung';
  }
  return inFerien
      ? 'Erster Ferientag — Endreinigung'
      : 'Erster Schliessungstag — Endreinigung';
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

/// Liegt [tag] in einer QUALIFIZIERTEN Schliessung — Saisonpause oder Ferien
/// ab [langeSchliessungTage]? Gegenstück zu [qualifizierteSchliessung], nur
/// auf einen einzelnen Tag bezogen.
bool istInQualifizierterSchliessung(BetriebLocal b, DateTime tag) {
  final t = DateTime(tag.year, tag.month, tag.day);
  if (!istInAktiverSaison(b, t)) return true;
  for (final s in ferienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    final dauer = s.ende!.difference(s.start!).inDays + 1;
    if (dauer < langeSchliessungTage) continue;
    if (!t.isBefore(s.start!) && !t.isAfter(s.ende!)) return true;
  }
  return false;
}

/// Nächste Wiedereröffnung nach einer QUALIFIZIERTEN Schliessung, strikt nach
/// [ab]: Saisonstart oder Ende+1 einer Ferienperiode ab [langeSchliessungTage].
///
/// Massgebend für die Auto-Vorschläge: Eine Eröffnungsreinigung ist nötig,
/// weil die Anlage lange stillstand — eine Woche Betriebsferien löst keine
/// aus (Regel Daniel 08.08.2026). [oeffnungNach] bleibt unverändert, es
/// verankert die Fälligkeits-Uhr und muss JEDE Wiedereröffnung kennen.
DateTime? qualifizierteOeffnungNach(BetriebLocal b, DateTime ab) {
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
  for (final s in ferienSlots(b)) {
    if (s.start == null || s.ende == null) continue;
    final dauer = s.ende!.difference(s.start!).inDays + 1;
    if (dauer < langeSchliessungTage) continue;
    final reopen = s.ende!.add(const Duration(days: 1));
    if (reopen.isAfter(ab)) {
      if (naechste == null || reopen.isBefore(naechste)) naechste = reopen;
    }
  }
  return naechste;
}

/// Ziel-Tag für den automatischen **Eröffnungs**-Vorschlag im Tourenplan —
/// `null`, wenn an [tag] keiner stehen soll.
///
/// Auslöser ist allein die qualifizierte Schliessung, NICHT die Service-Art
/// der letzten Reinigung (Regel Daniel 08.08.2026, Fall Flora Landquart:
/// «dass die letzte Reinigung als Endreinigung erfasst wurde macht keinen
/// Sinn» — die Eröffnungsreinigung ist nötig, weil die Anlage lange
/// stillstand). Zulässig sind der erste offene Tag ab der Wiedereröffnung
/// UND die letzten [saisonReinigungFensterTage] Schliessungstage davor.
///
/// Muloin-Regel (21.07.2026) bleibt: Wurde während der Schliessung bereits
/// gereinigt, ist die Anlage versorgt — kein Vorschlag.
DateTime? eroeffnungsVorschlagsTag({
  required BetriebLocal betrieb,
  required DateTime tag,
  required DateTime? letzteReinigung,
}) {
  if (betrieb.status != 'aktiv') return null;
  final t = DateTime(tag.year, tag.month, tag.day);
  if (letzteReinigung != null && istInSchliessung(betrieb, letzteReinigung)) {
    return null;
  }
  final ab = letzteReinigung ?? t.subtract(const Duration(days: 365));
  final oeffnung = qualifizierteOeffnungNach(betrieb, ab);
  if (oeffnung == null) return null;
  final o = DateTime(oeffnung.year, oeffnung.month, oeffnung.day);

  final tageBis = o.difference(t).inDays;
  if (tageBis >= 1 &&
      tageBis <= saisonReinigungFensterTage &&
      darfTrotzSchliessungGeplantWerden(
        art: 'eroeffnungsreinigung',
        betrieb: betrieb,
        tag: t,
      )) {
    return t;
  }

  final ziel = naechsterOffenerTag(betrieb, o);
  return ziel == t ? t : null;
}

/// Ziel-Tag für den automatischen **Endreinigungs**-Vorschlag im Tourenplan —
/// `null`, wenn an [tag] keiner stehen soll.
///
/// Zulässig sind der letzte offene Tag vor der Schliessung UND die ersten
/// [saisonReinigungFensterTage] Schliessungstage (spiegelbildlich zur
/// Eröffnung). Ist die Endreinigung schon erfasst, entfällt der Vorschlag —
/// [istEndreinigungsArt] prüft das gross-/kleinschreibungsunempfindlich.
DateTime? endreinigungsVorschlagsTag({
  required BetriebLocal betrieb,
  required DateTime tag,
  required String? letzteServiceArt,
}) {
  if (betrieb.status != 'aktiv') return null;
  if (istEndreinigungsArt(letzteServiceArt)) return null;
  final t = DateTime(tag.year, tag.month, tag.day);

  if (istInQualifizierterSchliessung(betrieb, t) &&
      darfTrotzSchliessungGeplantWerden(
        art: 'endreinigung',
        betrieb: betrieb,
        tag: t,
      )) {
    return t;
  }

  final s = qualifizierteSchliessung(betrieb, t);
  if (s == null) return null;
  final ziel = naechsterOffenerTag(betrieb, s.datum, rueckwaerts: true);
  return ziel == t ? t : null;
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
