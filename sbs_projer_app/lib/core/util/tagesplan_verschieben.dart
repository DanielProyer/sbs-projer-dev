// Regeln fürs Verschieben von Tagesplan-Einträgen auf einen anderen Tag
// (Daniel 26.09.2026: «einfacher Weg um geplante Touren zu verschieben»).
//
// Rein und ohne Flutter-Widgets — die Screens holen sich hier, welche
// Einträge mitgehen, wie der Zieltag danach aussieht und was die Rückfrage
// sagt.

import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

const List<String> _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Kurzes Datum für Rückfragen und Meldungen, z. B. `Di 29.09.` — bewusst
/// ohne intl, damit es in Tests deterministisch bleibt.
String kurzTag(DateTime d) =>
    '${_wochentage[d.weekday - 1]} ${d.day}.${d.month.toString().padLeft(2, '0')}.';

String _stopps(int n) => n == 1 ? '1 Stopp' : '$n Stopps';

/// Welche Einträge beim Tag-Verschieben mitgehen: nicht erledigt (Ist-Zeit
/// vorhanden) und keine `hist_`-Einträge (tatsächliche Reinigungen).
List<TourEintrag> verschiebbareEintraege(
  List<TourEintrag> plan,
  Set<String> erledigteIds,
) => [
  for (final e in plan)
    if (!e.id.startsWith('hist_') && !erledigteIds.contains(e.id)) e,
];

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
