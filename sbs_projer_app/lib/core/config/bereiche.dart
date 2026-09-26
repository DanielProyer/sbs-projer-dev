/// Welche Bereiche die App hat und was darin steht — als Daten (v0.131.0).
///
/// WARUM als Daten: Die Einträge der Startseite, der Buchhaltung und der
/// Einstellungen waren über drei Screens verstreut, und jedes Umhängen hiess
/// Screen-Code anfassen. Hier steht die Ordnung einmal; die Mehr-Seite und
/// alle Bereichsseiten zeichnen sich daraus, und die Wächter-Tests prüfen
/// gegen dieselbe Liste, ob jeder Screen erreichbar ist.
library;

import 'package:flutter/material.dart';

/// Woher der Zähler eines Eintrags kommt. Es gibt bewusst keine neue
/// Zähl-Logik: Alles stammt aus Providern, die es schon gibt.
enum ZaehlerQuelle {
  /// «N niedrig» — Materialbestand unter Mindestmenge.
  materialNiedrig,

  /// Dieselbe Zahl wie die Glocke.
  aufgaben,

  /// Offene Aufgaben, deren Sprungziel in diesen Büro-Bereich führt.
  bereich,
}

class BereichEintrag {
  final String titel;
  final String? untertitel;
  final IconData icon;

  /// Route, die beim Antippen per `context.push` geöffnet wird.
  final String ziel;
  final ZaehlerQuelle? zaehler;

  /// Weitere Suchbegriffe (Suche, v0.133.0): «mwst» findet die
  /// MwSt-Abrechnung, auch wenn das Wort nicht im Titel steht.
  final List<String> stichwoerter;

  const BereichEintrag({
    required this.titel,
    this.untertitel,
    required this.icon,
    required this.ziel,
    this.zaehler,
    this.stichwoerter = const [],
  });
}

class BereichGruppe {
  final String? titel;

  /// Kacheln im 2er-Raster statt Zeilen — nur für wenige, oft genutzte Ziele.
  final bool alsKacheln;
  final List<BereichEintrag> eintraege;

  const BereichGruppe({
    this.titel,
    this.alsKacheln = false,
    required this.eintraege,
  });
}

class Bereich {
  final String id;
  final String titel;
  final List<BereichGruppe> gruppen;

  const Bereich({required this.id, required this.titel, required this.gruppen});

  Iterable<BereichEintrag> get alleEintraege =>
      gruppen.expand((g) => g.eintraege);
}

// ---------------------------------------------------------------------------
// Pfad → Büro-Bereich
// ---------------------------------------------------------------------------

/// Reihenfolge ist Vorrang: Spezielles vor Allgemeinem, `/buchhaltung`
/// zuletzt als Sammelbecken. Ein Präfix auf `-` gilt als Wortanfang
/// (`/buchhaltung/camt-` fängt camt-import, camt-pruefliste, …).
const _bereichPraefixe = <(String, String)>[
  ('/rechnungen', 'rechnungen'),
  ('/heineken', 'rechnungen'),
  ('/jahresrechnung', 'rechnungen'),
  ('/bergkundenpauschalen', 'rechnungen'),
  ('/buchhaltung/mahnwesen', 'rechnungen'),
  ('/buchhaltung/debitoren', 'rechnungen'),
  ('/bank', 'bank'),
  ('/buchhaltung/camt-', 'bank'),
  ('/buchhaltung/eingangsrechnungen', 'bank'),
  ('/buchhaltung/lohn', 'lohn'),
  ('/abschluesse', 'abschluesse'),
  ('/buchhaltung/mwst', 'abschluesse'),
  ('/buchhaltung/monatsabschluss', 'abschluesse'),
  ('/buchhaltung/audit', 'abschluesse'),
  ('/buchhaltung/abschreibung', 'abschluesse'),
  ('/buchhaltung/steuern', 'abschluesse'),
  ('/dokumente', 'dokumente'),
  ('/buchhaltung', 'buchhaltung'),
];

/// Zu welchem Büro-Bereich gehört [pfad]? `null` ausserhalb des Büros.
String? bereichFuerPfad(String pfad) {
  // Aufgaben-Routen können einen Query-String tragen
  // (`/buchhaltung/abschreibung?jahr=2025`) — ohne den Schnitt verglichen
  // die Präfixe gegen den ganzen String und trafen nie.
  final p = Uri.parse(pfad).path;
  for (final (praefix, id) in _bereichPraefixe) {
    final trifft = praefix.endsWith('-')
        ? p.startsWith(praefix)
        : p == praefix || p.startsWith('$praefix/');
    if (trifft) return id;
  }
  return null;
}

/// Wie viele der [routen] führen in welchen Büro-Bereich?
Map<String, int> zaehleJeBereich(Iterable<String?> routen) {
  final n = <String, int>{};
  for (final r in routen) {
    if (r == null) continue;
    final id = bereichFuerPfad(r);
    if (id != null) n[id] = (n[id] ?? 0) + 1;
  }
  return n;
}

// ---------------------------------------------------------------------------
// Die Bereiche
// ---------------------------------------------------------------------------

const kBereichMehr = Bereich(
  id: 'mehr',
  titel: 'Mehr',
  gruppen: [
    BereichGruppe(
      titel: 'Unterwegs',
      alsKacheln: true,
      eintraege: [
        BereichEintrag(
          titel: 'Spesen',
          icon: Icons.receipt_long,
          ziel: '/spesen',
          stichwoerter: ['beleg', 'quittung', 'tanken', 'benzin', 'material', 'scanner'],
        ),
        BereichEintrag(
          titel: 'Material',
          icon: Icons.inventory_2,
          ziel: '/materialien',
          zaehler: ZaehlerQuelle.materialNiedrig,
          stichwoerter: ['bestellung', 'lager', 'bestand'],
        ),
        BereichEintrag(
          titel: 'Aufgaben',
          icon: Icons.task_alt,
          ziel: '/aufgaben',
          zaehler: ZaehlerQuelle.aufgaben,
          stichwoerter: ['todo', 'erinnerung'],
        ),
        BereichEintrag(
          titel: 'Events',
          icon: Icons.festival,
          ziel: '/events',
        ),
        BereichEintrag(
          titel: 'Google-Termine',
          icon: Icons.event_note,
          ziel: '/google-termine',
          stichwoerter: ['google', 'kalender', 'termine zuordnen'],
        ),
      ],
    ),
    BereichGruppe(
      titel: 'Büro',
      eintraege: [
        BereichEintrag(
          titel: 'Rechnungen',
          untertitel: 'Kunden, Heineken, pro Betrieb',
          icon: Icons.request_quote,
          ziel: '/rechnungen',
          zaehler: ZaehlerQuelle.bereich,
          stichwoerter: ['forderungen', 'debitoren', 'mahnung', 'mahnwesen', 'offen'],
        ),
        BereichEintrag(
          titel: 'Bank und Zahlungen',
          untertitel: 'Bankauszug, Eingangsrechnungen',
          icon: Icons.account_balance,
          ziel: '/bank',
          zaehler: ZaehlerQuelle.bereich,
          stichwoerter: ['camt', 'gkb', 'zahlung'],
        ),
        BereichEintrag(
          titel: 'Buchhaltung',
          untertitel: 'Konten, Journal, Bilanz',
          icon: Icons.menu_book,
          ziel: '/buchhaltung',
          zaehler: ZaehlerQuelle.bereich,
        ),
        BereichEintrag(
          titel: 'Lohn',
          untertitel: 'Lohnlauf, Lohnausweis',
          icon: Icons.payments,
          ziel: '/buchhaltung/lohn',
          zaehler: ZaehlerQuelle.bereich,
          stichwoerter: ['lohnausweis', 'ahv', 'bvg', 'sozialversicherung'],
        ),
        BereichEintrag(
          titel: 'Abschlüsse und Steuern',
          untertitel: 'Monat, MWST, Jahr, Steuern',
          icon: Icons.fact_check,
          ziel: '/abschluesse',
          zaehler: ZaehlerQuelle.bereich,
          stichwoerter: ['jahresabschluss', 'steuererklaerung'],
        ),
        BereichEintrag(
          titel: 'Dokumente',
          icon: Icons.folder_open,
          ziel: '/dokumente',
          zaehler: ZaehlerQuelle.bereich,
        ),
      ],
    ),
    BereichGruppe(
      titel: 'Einrichtung',
      eintraege: [
        BereichEintrag(
          titel: 'Auswertungen',
          untertitel: 'Umsatz, Arbeitstage, Nutzung',
          icon: Icons.insights,
          ziel: '/auswertungen',
        ),
        BereichEintrag(
          titel: 'Stammdaten',
          untertitel: 'Firma, Preise, Regionen, Anlagen',
          icon: Icons.dataset,
          ziel: '/stammdaten',
          stichwoerter: ['preise', 'preisliste', 'biersorten', 'regionen', 'firma', 'anlagen'],
        ),
        BereichEintrag(
          titel: 'Einstellungen',
          untertitel: 'Google, Speicher, Abmelden',
          icon: Icons.settings,
          ziel: '/einstellungen',
          stichwoerter: ['google', 'kalender', 'kontakte sync', 'abmelden', 'logout'],
        ),
      ],
    ),
  ],
);

const kBereichBank = Bereich(
  id: 'bank',
  titel: 'Bank und Zahlungen',
  gruppen: [
    BereichGruppe(
      eintraege: [
        BereichEintrag(
          titel: 'Bankauszug Import',
          untertitel: 'Import, Prüfliste, Regeln und Dateien',
          icon: Icons.account_balance,
          ziel: '/buchhaltung/camt-import',
        ),
        BereichEintrag(
          titel: 'Eingangsrechnungen',
          untertitel: 'Lieferantenrechnungen erfassen und buchen',
          icon: Icons.mark_email_read,
          ziel: '/buchhaltung/eingangsrechnungen',
        ),
      ],
    ),
  ],
);

const kBereichAbschluesse = Bereich(
  id: 'abschluesse',
  titel: 'Abschlüsse und Steuern',
  gruppen: [
    BereichGruppe(
      eintraege: [
        BereichEintrag(
          titel: 'Monatsabschluss',
          untertitel: 'Zehn Punkte je Monat: Einsätze, Heineken, Bank, Lohn',
          icon: Icons.event_available,
          ziel: '/buchhaltung/monatsabschluss',
        ),
        BereichEintrag(
          titel: 'MwSt-Abrechnung',
          untertitel: 'Quartals-Abrechnung ESTV',
          icon: Icons.account_balance,
          ziel: '/buchhaltung/mwst',
          stichwoerter: ['mwst', 'mehrwertsteuer', 'estv'],
        ),
        BereichEintrag(
          titel: 'Abschlussprüfung',
          untertitel: 'Jahres-Check, Jahrgang abschreiben',
          icon: Icons.fact_check,
          ziel: '/buchhaltung/audit',
          stichwoerter: ['abschreiben', 'jahrgang'],
        ),
        BereichEintrag(
          titel: 'Steuern',
          untertitel: 'Veranlagungen, Zahlungen, Unterlagen',
          icon: Icons.gavel,
          ziel: '/buchhaltung/steuern',
        ),
      ],
    ),
  ],
);

const kBereichAuswertungen = Bereich(
  id: 'auswertungen',
  titel: 'Auswertungen',
  gruppen: [
    BereichGruppe(
      eintraege: [
        BereichEintrag(
          titel: 'Umsatz und Arbeiten',
          untertitel: 'Nach Jahr und Monat',
          icon: Icons.insights,
          ziel: '/buchhaltung/auswertung',
        ),
        BereichEintrag(
          titel: 'Arbeitstage',
          untertitel: 'Arbeitszeit, Fahrten und Einsätze pro Tag',
          icon: Icons.query_stats,
          ziel: '/auswertungen/arbeitstage',
        ),
        BereichEintrag(
          titel: 'Nutzung der App',
          untertitel: 'Welcher Bereich wird wie oft geöffnet',
          icon: Icons.bar_chart,
          ziel: '/auswertungen/nutzung',
          stichwoerter: ['statistik'],
        ),
      ],
    ),
  ],
);

/// Die Einträge unter den Kennzahlen der Buchhaltung.
///
/// Heineken, Jahresrechnungen und Bergkundenpauschalen hingen hier als
/// Übergangsgruppe «Rechnungen» — seit v0.132.0 sind sie nur noch über die
/// Reiter des Rechnungs-Bereichs erreichbar (`kReiterRechnungen`), nicht
/// mehr über eine eigene Bereichsseite.
const kBereichBuchhaltung = Bereich(
  id: 'buchhaltung',
  titel: 'Buchhaltung',
  gruppen: [
    BereichGruppe(
      titel: 'Bücher',
      eintraege: [
        BereichEintrag(
          titel: 'Kontenplan',
          untertitel: 'Konten nach Schweizer KMU-Standard',
          icon: Icons.account_tree,
          ziel: '/buchhaltung/konten',
        ),
        BereichEintrag(
          titel: 'Journal',
          untertitel: 'Alle Buchungen anzeigen',
          icon: Icons.menu_book,
          ziel: '/buchhaltung/buchungen',
        ),
        BereichEintrag(
          titel: 'Bilanz und Erfolgsrechnung',
          untertitel: 'Per Datum',
          icon: Icons.assessment,
          ziel: '/buchhaltung/berichte',
        ),
      ],
    ),
  ],
);

/// Ziele, die nur die Suche kennt — keine eigene Zeile auf Mehr, weil sie
/// ein Filter eines Leisten-Ziels sind. «Pikett-Dienste» stand bis v0.130.0
/// in der «Weitere»-Liste und ist seit v0.131.0 ein Typ-Filter der
/// Einsätze; ohne diesen Eintrag fand die Suche das Wort «pikett» nicht
/// (Daniel 23.09.2026).
const kSuchZusatzZiele = [
  BereichEintrag(
    titel: 'Pikett-Dienste',
    untertitel: 'Einsätze, gefiltert auf Pikett',
    icon: Icons.nightlight_round,
    ziel: '/einsaetze?typ=pikett',
    stichwoerter: ['pikett', 'bereitschaft', 'wochenenddienst'],
  ),
  // Bergkundenpauschalen und Anlagen hatten bis T11 keinen eigenen
  // Such-Treffer — beide Screens hängen nur über andere Screens ein
  // (Rechnungs-Reiter bzw. Betrieb-Detail), keine eigene Zeile auf Mehr.
  BereichEintrag(
    titel: 'Bergkundenpauschalen',
    untertitel: 'Pauschale pro Betrieb und Tag',
    icon: Icons.terrain,
    ziel: '/bergkundenpauschalen',
    stichwoerter: ['bergkunde', 'pauschale'],
  ),
  BereichEintrag(
    titel: 'Anlagen',
    untertitel: 'Alle Anlagen',
    icon: Icons.local_bar,
    ziel: '/anlagen',
    stichwoerter: ['zapfanlage', 'zapfsystem'],
  ),
];

const kAlleBereiche = [
  kBereichMehr,
  kBereichBank,
  kBereichAbschluesse,
  kBereichAuswertungen,
  kBereichBuchhaltung,
];
