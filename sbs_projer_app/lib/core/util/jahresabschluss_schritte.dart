/// Die sechs Schritte des geführten Jahresabschlusses — reine Logik.
///
/// WARUM: Der Abschluss 2025 lief über SQL-Skripte, ein Python-Skript und
/// Notizen in `docs/buchhaltung/jahresabschluss-2025.md`. Ab 2026 macht
/// Daniel ihn in der App; diese Liste sagt ihm, was in welcher Reihenfolge
/// fällig ist und wo er es erledigt. Die Ampeln kommen aus der
/// Abschlussprüfung (dieselben Regeln), dem Journal der Abschreibungsläufe,
/// dem Steuer-Dossier und dem Steuerjahr — hier wird nichts neu geprüft.
library;

import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/chf_betrag.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

/// Was ein Knopf eines Schritts auslöst. Der Screen setzt es in Navigation
/// oder PDF um — so bleibt die Schrittliste ohne BuildContext testbar.
enum SchrittAktion {
  /// Abschlussprüfung des Jahrs öffnen.
  pruefung,

  /// Schritt «Jahrgang abschreiben» des Jahrs öffnen.
  abschreibung,

  /// Jahresrechnung als PDF ansehen (nichts wird abgelegt).
  vorschau,

  /// Jahresrechnung erzeugen und ins Steuer-Dossier legen.
  erzeugen,

  /// Steuerjahr (Dossier, Status, Veranlagung) öffnen.
  steuerjahr,
}

class SchrittKnopf {
  final String text;
  final SchrittAktion aktion;

  /// `false`: sichtbar, aber gesperrt — etwa «Erzeugen» im laufenden Jahr,
  /// dessen Zahlen sich bis zum 31.12. noch ändern.
  final bool aktiv;
  const SchrittKnopf(this.text, this.aktion, {this.aktiv = true});
}

class JahresabschlussSchritt {
  final int nr;
  final String titel;
  final PruefStatus status;
  final String ist;
  final String hinweis;
  final List<SchrittKnopf> knoepfe;
  const JahresabschlussSchritt({
    required this.nr,
    required this.titel,
    required this.status,
    required this.ist,
    this.hinweis = '',
    this.knoepfe = const [],
  });
}

/// Regel-Ids aus `abschluss_regeln.dart`, auf die sich die Schritte stützen.
const kRegelVerjaehrt = 'debitoren_verjaehrt';
const kRegelDelkredere = 'delkredere';
const kRegelRueckstellung = 'rueckstellung';

final _df = DateFormat('dd.MM.yyyy');

/// Gewinn-Abweichung, ab der eine Fassung als veraltet gilt (5 Rappen wie
/// die Toleranz der Abschlussregeln).
const _gewinnToleranz = 0.05;

/// Eine Fassung der Jahresrechnung im Dossier: aus der App oder aus dem
/// Beilage-Skript (Fassung 1 vom 08.09.2026). [gewinn] ist der Gewinn, mit
/// dem sie erzeugt wurde — aus `dokumente.betrag`, sonst aus dem Titel.
typedef JahresrechnungFassung = ({Dokument dokument, int nr, double? gewinn});

/// Nur App- und Skript-Fassungen zählen, erkennbar am Titel
/// «Jahresrechnung {jahr} …». WARUM: Unter Typ `jahresrechnung` liegen für
/// 2019–2024 auch die eingereichten Unterlagen («Bilanz 31.12.2024 …»,
/// «Erfolgsrechnung 2024 …», Bilanz und ER getrennt) — das sind keine
/// Fassungen dieser Jahresrechnung.
bool _istFassung(Dokument d, int jahr) =>
    d.typ == 'jahresrechnung' &&
    d.jahr == jahr &&
    d.titel.toLowerCase().startsWith('jahresrechnung $jahr');

int _fassungNr(String titel) {
  final m = RegExp(r'Fassung\s+(\d+)').firstMatch(titel);
  return m == null ? 1 : int.parse(m.group(1)!);
}

/// «(Gewinn 20890.22, EK …)» (Skript) oder «(Gewinn 20'890.22, EK …)» (App).
double? _gewinnAusTitel(String titel) {
  final m = RegExp(r"Gewinn\s+(-?[0-9'’]+(?:\.[0-9]+)?)").firstMatch(titel);
  return m == null ? null : chfBetragParsen(m.group(1)!);
}

/// Die Fassungen des Jahrs, höchste Nummer zuerst (bei gleicher Nummer die
/// jüngere).
List<JahresrechnungFassung> fassungenVon(int jahr, List<Dokument> dokumente) {
  final liste = [
    for (final d in dokumente)
      if (_istFassung(d, jahr))
        (
          dokument: d,
          nr: _fassungNr(d.titel),
          gewinn: d.betrag ?? _gewinnAusTitel(d.titel),
        ),
  ];
  liste.sort((a, b) {
    final n = b.nr.compareTo(a.nr);
    if (n != 0) return n;
    final da = a.dokument.createdAt ?? a.dokument.dokumentDatum ?? DateTime(0);
    final db = b.dokument.createdAt ?? b.dokument.dokumentDatum ?? DateTime(0);
    return db.compareTo(da);
  });
  return liste;
}

/// Nummer der nächsten Fassung: höchste vorhandene + 1. Die Skript-Fassung
/// ohne Zusatz ist Fassung 1. WARUM nicht die Anzahl: Wird eine Fassung
/// gelöscht, ergäbe die Anzahl eine Nummer, die es schon gibt.
int naechsteFassung(int jahr, List<Dokument> dokumente) {
  final f = fassungenVon(jahr, dokumente);
  return f.isEmpty ? 1 : f.first.nr + 1;
}

/// Titel der roten Schritte 1–4 — vor ihnen ist jede Jahresrechnung
/// vorläufig.
List<String> offeneVorschritte(List<JahresabschlussSchritt> schritte) => [
  for (final s in schritte)
    if (s.nr <= 4 && s.status == PruefStatus.rot) s.titel,
];

/// «Jahrgänge 2019, 2020 · 105 Rechnungen · 9'452.20» über alle gebuchten
/// Läufe des Geschäftsjahrs, oder «kein Lauf».
String laeufeText(int jahr, List<AbschreibungLauf> laeufe) {
  final gebucht = laeufe.where((l) => l.geschaeftsjahr == jahr && l.gebucht);
  if (gebucht.isEmpty) return 'kein Lauf';
  final jahrgaenge = {for (final l in gebucht) ...l.jahrgaenge}.toList()
    ..sort();
  final anzahl = gebucht.fold<int>(0, (s, l) => s + l.anzahl);
  final brutto = gebucht.fold<double>(0, (s, l) => s + l.brutto);
  return '${jahrgaenge.length == 1 ? 'Jahrgang' : 'Jahrgänge'} '
      '${jahrgaenge.join(', ')} · $anzahl Rechnungen · ${chf(brutto)}';
}

List<JahresabschlussSchritt> jahresabschlussSchritte({
  required int jahr,
  required DateTime heute,
  required List<Pruefbefund> befunde,
  required List<AbschreibungLauf> laeufe,
  required List<Dokument> dokumente,
  Steuerjahr? steuerjahr,
  Dossier? dossier,

  /// Gewinn nach heutigem Journal — daran misst sich, ob die neueste
  /// Fassung noch stimmt. `null`: kein Vergleich.
  double? gewinnAktuell,
}) {
  Pruefbefund? befund(String id) {
    for (final b in befunde) {
      if (b.regelId == id) return b;
    }
    return null;
  }

  // Fehlt ein Befund (Regel umbenannt, Prüfung unvollständig), bleibt der
  // Schritt gelb — nie still grün.
  PruefStatus status(Pruefbefund? b) => b?.status ?? PruefStatus.gelb;
  String istSoll(Pruefbefund? b) {
    if (b == null) return 'kein Befund der Abschlussprüfung';
    if (b.soll.isEmpty) return b.ist;
    return 'Ist ${b.ist} · Soll ${b.soll}';
  }

  final rot = befunde.where((b) => b.status == PruefStatus.rot).length;
  final gelb = befunde.where((b) => b.status == PruefStatus.gelb).length;

  final verjaehrt = befund(kRegelVerjaehrt);
  final delkredere = befund(kRegelDelkredere);
  final rueckstellung = befund(kRegelRueckstellung);

  final sj = steuerjahr;
  final eingereicht = sj != null &&
      (sj.status == 'eingereicht' || sj.status == 'veranlagt');
  // Vor der Einreichung zählen nur die Unterlagen, die es dann schon gibt;
  // Veranlagungen kommen erst danach.
  const vorEinreichung = {'jahresrechnung', 'lohnausweis', 'zinsausweis'};
  final fehlend = [
    for (final f in dossier?.fehlend ?? const <String>[])
      if (vorEinreichung.contains(f)) pflichtTypLabel(f),
  ];

  final vorschritte = [
    JahresabschlussSchritt(
      nr: 1,
      titel: 'Abschlussprüfung',
      status: rot > 0 ? PruefStatus.rot : PruefStatus.gruen,
      ist: '$rot rot · $gelb gelb',
      hinweis: rot > 0
          ? 'Rote Punkte zuerst erledigen.'
          : (gelb > 0 ? 'Gelbe Punkte prüfen.' : ''),
      knoepfe: const [SchrittKnopf('Öffnen', SchrittAktion.pruefung)],
    ),
    JahresabschlussSchritt(
      nr: 2,
      titel: 'Verjährte Jahrgänge abschreiben',
      status: status(verjaehrt),
      ist: laeufeText(jahr, laeufe),
      hinweis: verjaehrt == null
          ? 'Kein Befund der Abschlussprüfung.'
          : (verjaehrt.status == PruefStatus.gruen
                ? ''
                : 'Noch offen: ${verjaehrt.ist}'),
      knoepfe: const [SchrittKnopf('Öffnen', SchrittAktion.abschreibung)],
    ),
    JahresabschlussSchritt(
      nr: 3,
      titel: 'Delkredere 5 %',
      status: status(delkredere),
      ist: istSoll(delkredere),
      hinweis: delkredere?.hinweis ?? '',
      knoepfe: const [SchrittKnopf('Zur Prüfung', SchrittAktion.pruefung)],
    ),
    JahresabschlussSchritt(
      nr: 4,
      titel: 'Steuerrückstellung',
      status: status(rueckstellung),
      ist: istSoll(rueckstellung),
      hinweis: rueckstellung?.hinweis ?? '',
      knoepfe: const [SchrittKnopf('Zur Prüfung', SchrittAktion.pruefung)],
    ),
  ];

  return [
    ...vorschritte,
    _schrittJahresrechnung(
      jahr: jahr,
      heute: heute,
      dokumente: dokumente,
      vorschritteRot: offeneVorschritte(vorschritte).isNotEmpty,
      eingereicht: eingereicht,
      gewinnAktuell: gewinnAktuell,
    ),
    JahresabschlussSchritt(
      nr: 6,
      titel: 'Steuererklärung',
      status: eingereicht ? PruefStatus.gruen : PruefStatus.gelb,
      ist: eingereicht
          ? _eingereichtText(sj)
          : [
              if (sj?.status == 'ermessen')
                'Ermessenstaxation'
              else
                Steuerjahr.statusLabel(sj?.status ?? 'offen'),
              if (dossier != null)
                'Dossier ${dossier.vorhanden}/${dossier.total}',
            ].join(' · '),
      hinweis: eingereicht
          ? ''
          : [
              if (fehlend.isNotEmpty) 'Fehlt: ${fehlend.join(', ')}.',
              if (jahr < heute.year)
                'Einreichen bis 30.09.${jahr + 1}, danach Status '
                    '«eingereicht» setzen.'
              else
                'Jahr läuft noch.',
            ].join(' '),
      knoepfe: const [SchrittKnopf('Öffnen', SchrittAktion.steuerjahr)],
    ),
  ];
}

/// Schritt 5. Grün nur, wenn eine Fassung vorliegt, deren Gewinn noch dem
/// Journal entspricht, und kein Schritt 1–4 rot ist.
///
/// WARUM so streng (Review 29.09.2026, W1): Die Fassung 1 der Jahresrechnung
/// 2025 (Gewinn 20'890.22) lag im Dossier, als der Jahrgang 2020 und das
/// Delkredere den Gewinn schon auf 15'235.70 gedrückt hatten. Ein grüner
/// Schritt 5 hätte die veraltete Fassung als erledigt gemeldet.
JahresabschlussSchritt _schrittJahresrechnung({
  required int jahr,
  required DateTime heute,
  required List<Dokument> dokumente,
  required bool vorschritteRot,
  required bool eingereicht,
  required double? gewinnAktuell,
}) {
  // Das laufende Jahr ändert sich bis zum 31.12. — ablegen erst danach;
  // ansehen darf man es jederzeit (W2).
  final laufend = jahr >= heute.year;
  final knoepfe = [
    const SchrittKnopf('Vorschau', SchrittAktion.vorschau),
    SchrittKnopf(
      'Erzeugen und ins Dossier legen',
      SchrittAktion.erzeugen,
      aktiv: !laufend,
    ),
  ];
  const erstVorschritte =
      'Erst Schritte 1–4 bereinigen — sonst stimmen die Zahlen nicht.';
  final fassungen = fassungenVon(jahr, dokumente);

  if (fassungen.isEmpty) {
    final fremde = dokumente
        .where((d) => d.typ == 'jahresrechnung' && d.jahr == jahr)
        .length;
    // 2019–2024: eingereicht mit Bilanz und ER als getrennte Dokumente —
    // die alte Ablage genügt, eine App-Fassung braucht es nicht mehr.
    if (fremde > 0 && eingereicht) {
      return JahresabschlussSchritt(
        nr: 5,
        titel: 'Jahresrechnung',
        status: PruefStatus.gruen,
        ist: 'Im Dossier: $fremde ältere Unterlagen (Bilanz/ER getrennt)',
        knoepfe: knoepfe,
      );
    }
    return JahresabschlussSchritt(
      nr: 5,
      titel: 'Jahresrechnung',
      status: PruefStatus.gelb,
      ist: 'noch nicht erzeugt',
      hinweis: laufend
          ? 'Jahr läuft noch — ablegen erst nach dem 31.12.$jahr.'
          : (vorschritteRot
                ? erstVorschritte
                : 'Bilanz, Erfolgsrechnung, Anhang und Steuerbeilage in '
                      'einem PDF.'),
      knoepfe: knoepfe,
    );
  }

  final neueste = fassungen.first;
  final datum = neueste.dokument.createdAt ?? neueste.dokument.dokumentDatum;
  final ist =
      '${fassungen.length > 1 ? '${fassungen.length} Fassungen, neueste: ' : ''}'
      '${neueste.dokument.titel}'
      '${datum == null ? '' : ' · ${_df.format(datum)}'}';
  final fassungGewinn = neueste.gewinn;
  final veraltet =
      fassungGewinn != null &&
      gewinnAktuell != null &&
      (fassungGewinn - gewinnAktuell).abs() > _gewinnToleranz;

  final PruefStatus status;
  final String hinweis;
  if (veraltet) {
    status = PruefStatus.gelb;
    hinweis =
        'Zahlen seit dieser Fassung geändert (Fassung: '
        '${chf(fassungGewinn)}, jetzt: ${chf(gewinnAktuell)}) — neue '
        'Fassung ablegen.';
  } else if (vorschritteRot) {
    status = PruefStatus.gelb;
    hinweis = erstVorschritte;
  } else {
    status = PruefStatus.gruen;
    hinweis = 'Nach späteren Buchungen eine neue Fassung ablegen.';
  }
  return JahresabschlussSchritt(
    nr: 5,
    titel: 'Jahresrechnung',
    status: status,
    ist: ist,
    hinweis: hinweis,
    knoepfe: knoepfe,
  );
}

/// Titel des Dossier-Dokuments. Ab der zweiten Fassung mit Nummer, damit
/// die Liste im Steuerjahr die Fassungen unterscheidet (keine wird
/// gelöscht).
String jahresrechnungTitel(JahresrechnungKennzahlen k, {int fassung = 1}) =>
    'Jahresrechnung ${k.jahr} — Bilanz, Erfolgsrechnung, Anhang, '
    'Steuerbeilage (Gewinn ${chf(k.gewinn)}, EK ${chf(k.eigenkapital)})'
    '${fassung > 1 ? ' — Fassung $fassung' : ''}';

String jahresrechnungDateiname(int jahr, {int fassung = 1}) =>
    'Jahresrechnung_$jahr${fassung > 1 ? '_Fassung$fassung' : ''}.pdf';

/// Steuerbaren Gewinn und Kapital der Jahresrechnung mit dem Steuerjahr
/// abgleichen: leere Felder füllen ([neu], `null` = nichts zu speichern),
/// gesetzte behalten und Abweichungen melden ([abweichungen]).
///
/// WARUM nie überschreiben: Nach der Veranlagung stehen dort die Zahlen der
/// Steuerverwaltung. Eine spätere Fassung der Jahresrechnung darf sie nicht
/// still durch den eigenen Vorschlag ersetzen — sie still stehen zu lassen,
/// wenn sie abweichen, aber auch nicht (W2): Daniel entscheidet im
/// Steuerjahr.
({Steuerjahr? neu, List<String> abweichungen}) steuerjahrAbgleich(
  Steuerjahr? alt,
  JahresrechnungKennzahlen k,
) {
  final s = alt ?? Steuerjahr(jahr: k.jahr);
  final abweichungen = <String>[];
  void pruefe(String was, double? gesetzt, double neu) {
    if (gesetzt != null && (gesetzt - neu).abs() > _gewinnToleranz) {
      abweichungen.add('$was ${chf(gesetzt)} (neu ${chf(neu)})');
    }
  }

  pruefe('Gewinn', s.steuerbarerGewinn, k.steuerbarerGewinn);
  pruefe('Kapital', s.steuerbaresKapital, k.eigenkapital);
  final fuellen =
      s.steuerbarerGewinn == null || s.steuerbaresKapital == null;
  return (
    neu: fuellen
        ? s.copyWith(
            steuerbarerGewinn: s.steuerbarerGewinn ?? k.steuerbarerGewinn,
            steuerbaresKapital: s.steuerbaresKapital ?? k.eigenkapital,
          )
        : null,
    abweichungen: abweichungen,
  );
}

/// Meldung zu [abweichungen] aus [steuerjahrAbgleich], `null` wenn keine.
String? steuerjahrHinweis(List<String> abweichungen) => abweichungen.isEmpty
    ? null
    : 'Steuerjahr behält ${abweichungen.join(', ')} — im Steuerjahr anpassen';

String _eingereichtText(Steuerjahr s) {
  if (s.status == 'veranlagt') {
    final d = s.veranlagtAm ?? s.eingereichtAm;
    return d == null ? 'Veranlagt' : 'Veranlagt am ${_df.format(d)}';
  }
  final d = s.eingereichtAm;
  return d == null ? 'Eingereicht' : 'Eingereicht am ${_df.format(d)}';
}
