/// Die vier Ziele der unteren Navigationsleiste (B1).
///
/// WARUM diese vier: Die App hat 97 Routen und hatte keine globale
/// Navigation — aus einer Eingangsrechnung zurück zur Startseite waren es
/// drei Mal «zurück». Die Analyse schlug «Heute · Betriebe · Einsätze ·
/// Büro» vor; die Nutzungsmessung (`route_nutzung`, 09.–16.09.2026) zeigte
/// aber, dass Büro auf dem Handy **nie** geöffnet wird (20 Aufrufe von
/// Buchhaltung und Rechnungen, alle vom PC), während der Tourenplan
/// neunmal unterwegs dran war. Also Tour statt Büro; Buchhaltung bleibt
/// über «Weitere» auf der Startseite erreichbar.
///
/// Beide Entscheidungen — welches Ziel leuchtet und ob die Leiste
/// überhaupt erscheint — sind reine Funktionen über dem Pfad, damit sie
/// ohne Router und ohne Widget prüfbar bleiben.
///
/// Seit v0.131.0 fünftes Ziel «Mehr»: Alles unterhalb der Heute-Liste war
/// schlecht erreichbar, je länger der Tagesplan, desto tiefer. «Mehr» ist
/// von jeder Seite aus einen Tipp entfernt, und jede Seite ausserhalb der
/// ersten vier Ziele lässt es leuchten — vorher leuchtete dort nichts.
library;

import 'package:flutter/material.dart';

enum NavZiel { heute, einsaetze, betriebe, tour, mehr }

/// Höhe der Leiste ohne den `SafeArea`-Unterrand.
const double kNavigationHoehe = 56;

String navPfad(NavZiel z) => switch (z) {
  NavZiel.heute => '/',
  NavZiel.einsaetze => '/einsaetze',
  NavZiel.betriebe => '/betriebe',
  NavZiel.tour => '/touren',
  NavZiel.mehr => '/mehr',
};

String navLabel(NavZiel z) => switch (z) {
  NavZiel.heute => 'Heute',
  NavZiel.einsaetze => 'Einsätze',
  NavZiel.betriebe => 'Betriebe',
  NavZiel.tour => 'Tour',
  NavZiel.mehr => 'Mehr',
};

IconData navIcon(NavZiel z) => switch (z) {
  NavZiel.heute => Icons.today,
  NavZiel.einsaetze => Icons.assignment,
  NavZiel.betriebe => Icons.store,
  NavZiel.tour => Icons.route,
  NavZiel.mehr => Icons.apps,
};

/// Die Einsatztypen haben eigene Detailrouten (aus der Zeit vor B2). Sie
/// gehören zum Ziel «Einsätze», damit das Leuchten nicht verschwindet,
/// sobald man eine Störung öffnet.
const _einsatzPraefixe = [
  '/reinigungen',
  '/stoerungen',
  '/montagen',
  '/eigenauftraege',
  '/eroeffnungsreinigungen',
  '/pikett',
];

String _ohneSchraegstrich(String pfad) => pfad.length > 1 && pfad.endsWith('/')
    ? pfad.substring(0, pfad.length - 1)
    : pfad;

/// Die Personen sind seit v0.131.0 ein Reiter der Betriebe-Liste — das
/// Leuchten bleibt deshalb bei «Betriebe».
const _betriebPraefixe = ['/kontakte'];

/// Gehört [pfad] zu [basis] — als die Seite selbst oder als Unterseite?
/// `/betriebe-alt` gehört NICHT zu `/betriebe`, deshalb reicht
/// `startsWith` allein nicht.
bool _unter(String pfad, String basis) =>
    pfad == basis || pfad.startsWith('$basis/');

/// Welches Ziel ist hervorgehoben? Immer genau eines: Was zu keinem der
/// ersten vier gehört, gehört zu «Mehr».
NavZiel aktivesZiel(String pfad) {
  final p = _ohneSchraegstrich(pfad);
  if (p == '/') return NavZiel.heute;
  for (final z in [NavZiel.einsaetze, NavZiel.betriebe, NavZiel.tour]) {
    if (_unter(p, navPfad(z))) return z;
  }
  for (final e in _einsatzPraefixe) {
    if (_unter(p, e)) return NavZiel.einsaetze;
  }
  for (final b in _betriebPraefixe) {
    if (_unter(p, b)) return NavZiel.betriebe;
  }
  return NavZiel.mehr;
}

/// Pfad-Endungen, die ein Formular kennzeichnen. Fast alle
/// `*FormScreen`-Routen enden so.
const _formularEndungen = [
  '/neu',
  '/bearbeiten',
  // Zwei `*FormScreen` mit eigener Endung:
  '/rechnungsadresse',
  // Vollflächen-Werkzeug mit Karte — eine Leiste am Rand wäre dort im Weg.
  '/lageplan',
];

/// Formulare und mehrstufige Vorgänge ohne solche Endung. Ein Eintrag mit
/// abschliessendem `/` gilt als Präfix, alles andere als genauer Pfad —
/// `/materialien/bestellen` ist ein Formular, `/materialien/bestellungen`
/// eine Liste.
const kFormularPfade = [
  '/login',
  // Der Spesen-Scanner ist mehrstufig und trägt eine eigene
  // `bottomNavigationBar`; zwei Leisten übereinander will niemand.
  '/spesen',
  '/einstellungen/preise/', // PreisVersionFormScreen
  '/buchhaltung/camt-import',
  '/buchhaltung/eingangsrechnungen/upload',
  '/materialien/bestellen',
];

/// Zeigt dieser Pfad die Leiste? In Formularen nicht: Ein Fehltipp auf
/// «Tour» mitten in einer Reinigung soll gar nicht erst möglich sein.
bool zeigtNavigation(String pfad) {
  final p = _ohneSchraegstrich(pfad);
  for (final e in _formularEndungen) {
    if (p.endsWith(e)) return false;
  }
  for (final f in kFormularPfade) {
    if (f.endsWith('/') ? p.startsWith(f) : p == f) return false;
  }
  return true;
}
