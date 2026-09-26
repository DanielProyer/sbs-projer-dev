// Regeln fürs Verschieben von Tagesplan-Einträgen auf einen anderen Tag
// (Daniel 26.09.2026: «einfacher Weg um geplante Touren zu verschieben»).
//
// Rein und ohne Flutter-Widgets — die Screens holen sich hier, welche
// Einträge mitgehen, wie der Zieltag danach aussieht und was die Rückfrage
// sagt.

import 'package:sbs_projer_app/core/util/einsatz_start.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

const List<String> _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Kurzes Datum für Rückfragen und Meldungen, z. B. `Di 29.09.` — bewusst
/// ohne intl, damit es in Tests deterministisch bleibt.
String kurzTag(DateTime d) =>
    '${_wochentage[d.weekday - 1]} ${d.day}.${d.month.toString().padLeft(2, '0')}.';

String _stopps(int n) => n == 1 ? '1 Stopp' : '$n Stopps';

/// Welche Einträge beim Tag-Verschieben mitgehen: nicht in [erledigteIds]
/// (Ist-Zeit, abgeschlossener Einsatz, abgemachter Termin — was eben am Tag
/// bleibt) und keine `hist_`-Einträge (tatsächliche Reinigungen).
List<TourEintrag> verschiebbareEintraege(
  List<TourEintrag> plan,
  Set<String> erledigteIds,
) => [
  for (final e in plan)
    if (!e.id.startsWith('hist_') && !erledigteIds.contains(e.id)) e,
];

/// Störungs-/Montage-Einträge (inkl. HeiGenie) im [plan], deren Einsatz
/// nicht mehr offen ist ([stoerungOffen]/[montageOffen]). Sie gelten beim
/// Verschieben als erledigt, auch ohne Wegpunkt-Stempel — umgeplant und in
/// den Kalender geschoben wird ein abgeschlossener Einsatz nie (Review
/// 26.09.2026, K1).
///
/// [einsatzStatus]: Status je Plan-Id (`s_<routeId>`/`m_<routeId>`, siehe
/// `einsatzStatusJePlanIdProvider`). Ein unbekannter Einsatz gilt als offen.
Set<String> abgeschlosseneEinsatzEintragIds(
  List<TourEintrag> plan,
  Map<String, String> einsatzStatus,
) {
  final ids = <String>{};
  for (final e in plan) {
    if (geplanteEinsatzId(e) == null) continue;
    final status = einsatzStatus[e.id];
    if (status == null) continue;
    final offen = e.typ == TourEintragTyp.stoerung
        ? stoerungOffen(status)
        : montageOffen(status);
    if (!offen) ids.add(e.id);
  }
  return ids;
}

bool _gleicherTag(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Reinigungs-Einträge im [plan], die aus einem abgemachten Saison-Termin
/// stammen (Tabelle `termine`, Typ Eröffnungs-/Endreinigung, Status
/// `geplant`, am [plantag]) — plus jeder `t_`-Eintrag (Termin ohne aktive
/// Anlage, siehe `saisonTermineFuerTag`).
///
/// Entscheid (Review 26.09.2026, M4): Sie bleiben beim Verschieben am
/// Plantag. Das Termin-Datum und das Kalender-Ereignis blieben sonst am
/// alten Tag, und die Sektion «Saison-Termine» böte den Termin dort sofort
/// wieder an. Ein Termin wird im Betrieb umgeplant, nicht im Tourenplan.
///
/// Die Termin-Einträge tragen `betriebId = termin.betriebId`, gewöhnliche
/// Reinigungs-Einträge die `betriebId` der Anlage — das kann nativ die
/// routeId statt der serverId sein. [betriebSchluessel] bildet beide auf
/// denselben Schlüssel ab (im Screen: routeId über den Betriebs-Lookup);
/// ohne ihn wird direkt verglichen.
Set<String> terminEintragIds(
  List<TourEintrag> plan,
  List<TerminDto> termine,
  DateTime plantag, {
  String Function(String betriebId)? betriebSchluessel,
}) {
  final schluessel = betriebSchluessel ?? (String id) => id;
  final betriebeMitTermin = <String>{
    for (final t in termine)
      if (t.status == 'geplant' &&
          (t.typ == 'eroeffnungsreinigung' || t.typ == 'endreinigung') &&
          _gleicherTag(t.datum, plantag))
        schluessel(t.betriebId),
  };
  return {
    for (final e in plan)
      if (e.id.startsWith('t_') ||
          (e.typ == TourEintragTyp.reinigung &&
              e.betriebId != null &&
              betriebeMitTermin.contains(schluessel(e.betriebId!))))
        e.id,
  };
}

/// Aufteilung des Plans beim Verschieben des ganzen Tages: was mitgeht, wie
/// viele erledigte Stopps (inkl. `hist_`) und welche Betriebe mit
/// abgemachtem Termin hier bleiben. Ein erledigter Termin zählt als
/// erledigt, nicht als Termin.
({List<TourEintrag> mit, int erledigt, List<String> termine})
tagesplanAufteilen(
  List<TourEintrag> plan, {
  required Set<String> erledigtIds,
  required Set<String> terminIds,
}) {
  var erledigt = 0;
  final termine = <String>{};
  for (final e in plan) {
    if (e.id.startsWith('hist_') || erledigtIds.contains(e.id)) {
      erledigt++;
    } else if (terminIds.contains(e.id)) {
      termine.add(e.betriebName);
    }
  }
  return (
    mit: verschiebbareEintraege(plan, {...erledigtIds, ...terminIds}),
    erledigt: erledigt,
    termine: termine.toList(),
  );
}

/// Einträge des Zieltags nach dem Anhängen: bestehende zuerst, neue ans Ende,
/// keine doppelte id (der bestehende Eintrag gewinnt).
List<TourEintrag> planNachAnhaengen(
  List<TourEintrag> ziel,
  List<TourEintrag> neu,
) {
  final ids = {for (final e in ziel) e.id};
  return [
    ...ziel,
    for (final e in neu)
      if (ids.add(e.id)) e,
  ];
}

/// Betriebsnamen (ohne Doppel, Reihenfolge des Plans), die am Zieltag
/// Ruhetag haben.
List<String> ruhetagBetriebe(List<TourEintrag> eintraege, DateTime ziel) {
  final namen = <String>{};
  for (final e in eintraege) {
    if (istRuhetag(e.ruhetage, ziel)) namen.add(e.betriebName);
  }
  return namen.toList();
}

/// Text für die Rückfrage beim Verschieben des ganzen Tages.
String verschiebenRueckfrageText({
  required int anzahl,
  required DateTime ziel,
  required int schonDort,
  required List<String> ruhetag,
  required int erledigt,
  // Betriebsnamen der abgemachten Saison-Termine, die hier bleiben (M4).
  List<String> termine = const [],
}) {
  final zeilen = <String>[
    '${_stopps(anzahl)} auf ${kurzTag(ziel)} verschieben?',
    if (schonDort > 0)
      schonDort == 1
          ? 'Dort steht schon 1 Stopp.'
          : 'Dort stehen schon $schonDort Stopps.',
    if (ruhetag.isNotEmpty) 'Ruhetag am Zieltag: ${ruhetag.join(', ')}',
    if (erledigt > 0)
      erledigt == 1
          ? '1 erledigter Stopp bleibt hier.'
          : '$erledigt erledigte Stopps bleiben hier.',
    if (termine.isNotEmpty)
      termine.length == 1
          ? '1 abgemachter Termin bleibt hier: ${termine.first}'
          : '${termine.length} abgemachte Termine bleiben hier: '
                '${termine.join(', ')}',
  ];
  return zeilen.join('\n');
}

/// Hinweis beim Verschieben eines einzelnen Stopps auf einen Ruhetag.
String ruhetagHinweisText(String betriebName, DateTime ziel) =>
    '$betriebName hat am ${_wochentage[ziel.weekday - 1]} Ruhetag. '
    'Trotzdem verschieben?';

/// Meldung nach dem Verschieben, z. B. «5 Stopps auf Di 29.09. verschoben».
String verschobenText(int anzahl, DateTime ziel) =>
    '${_stopps(anzahl)} auf ${kurzTag(ziel)} verschoben';

/// Fehlermeldung beim Verschieben — sagt ehrlich, wie weit es kam.
///
/// - [angehaengt]: Am Zieltag stehen die Stopps schon, nur das Entfernen am
///   alten Tag scheiterte → sie stehen doppelt (nicht verloren).
/// - [einsaetzeUmgeplant]: Störungen/Montagen, deren Plandatum schon auf
///   [ziel] steht, obwohl der Plan danach scheiterte.
String verschiebenFehlerText({
  required String fehler,
  required DateTime ziel,
  required bool angehaengt,
  required int einsaetzeUmgeplant,
}) {
  if (angehaengt) {
    return 'Am Zieltag angehängt, aber hier nicht entfernt — '
        'bitte Tag prüfen ($fehler)';
  }
  final zusatz = switch (einsaetzeUmgeplant) {
    0 => '',
    1 => ' — der Einsatz steht aber schon auf ${kurzTag(ziel)}',
    _ =>
      ' — die $einsaetzeUmgeplant Einsätze stehen aber schon auf '
          '${kurzTag(ziel)}',
  };
  return 'Verschieben fehlgeschlagen: $fehler$zusatz';
}
