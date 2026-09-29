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
  const SchrittKnopf(this.text, this.aktion);
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

/// Nur die Jahresrechnungen des Jahrs, neueste zuerst.
List<Dokument> jahresrechnungenVon(int jahr, List<Dokument> dokumente) {
  final liste =
      dokumente.where((d) => d.typ == 'jahresrechnung' && d.jahr == jahr).toList()
        ..sort((a, b) {
          final da = a.createdAt ?? a.dokumentDatum ?? DateTime(0);
          final db = b.createdAt ?? b.dokumentDatum ?? DateTime(0);
          return db.compareTo(da);
        });
  return liste;
}

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

  final jr = jahresrechnungenVon(jahr, dokumente);
  final neueste = jr.isEmpty ? null : jr.first;
  final neuestesDatum = neueste?.createdAt ?? neueste?.dokumentDatum;

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

  return [
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
    JahresabschlussSchritt(
      nr: 5,
      titel: 'Jahresrechnung',
      status: neueste == null ? PruefStatus.gelb : PruefStatus.gruen,
      ist: neueste == null
          ? 'noch nicht erzeugt'
          : '${jr.length > 1 ? '${jr.length} Fassungen, neueste: ' : ''}'
                '${neueste.titel}'
                '${neuestesDatum == null ? '' : ' · ${_df.format(neuestesDatum)}'}',
      hinweis: neueste == null
          ? (rot > 0
                ? 'Erst die Abschlussprüfung bereinigen — sonst stimmen die '
                      'Zahlen nicht.'
                : 'Bilanz, Erfolgsrechnung, Anhang und Steuerbeilage in '
                      'einem PDF.')
          : 'Nach späteren Buchungen eine neue Fassung ablegen.',
      knoepfe: const [
        SchrittKnopf('Vorschau', SchrittAktion.vorschau),
        SchrittKnopf('Erzeugen und ins Dossier legen', SchrittAktion.erzeugen),
      ],
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

/// Titel des Dossier-Dokuments. Ab der zweiten Fassung mit Nummer, damit
/// die Liste im Steuerjahr die Fassungen unterscheidet (keine wird
/// gelöscht).
String jahresrechnungTitel(JahresrechnungKennzahlen k, {int fassung = 1}) =>
    'Jahresrechnung ${k.jahr} — Bilanz, Erfolgsrechnung, Anhang, '
    'Steuerbeilage (Gewinn ${chf(k.gewinn)}, EK ${chf(k.eigenkapital)})'
    '${fassung > 1 ? ' — Fassung $fassung' : ''}';

String jahresrechnungDateiname(int jahr, {int fassung = 1}) =>
    'Jahresrechnung_$jahr${fassung > 1 ? '_Fassung$fassung' : ''}.pdf';

/// Das Steuerjahr mit steuerbarem Gewinn und Kapital aus der Jahresrechnung
/// — aber nur, wo dort noch nichts steht. `null`: nichts zu ändern.
///
/// WARUM nie überschreiben: Nach der Veranlagung stehen dort die Zahlen der
/// Steuerverwaltung. Eine spätere Fassung der Jahresrechnung darf sie nicht
/// still durch den eigenen Vorschlag ersetzen.
Steuerjahr? steuerjahrVorbefuellt(
  Steuerjahr? alt,
  JahresrechnungKennzahlen k,
) {
  final s = alt ?? Steuerjahr(jahr: k.jahr);
  if (s.steuerbarerGewinn != null && s.steuerbaresKapital != null) {
    return null;
  }
  return s.copyWith(
    steuerbarerGewinn: s.steuerbarerGewinn ?? k.steuerbarerGewinn,
    steuerbaresKapital: s.steuerbaresKapital ?? k.eigenkapital,
  );
}

String _eingereichtText(Steuerjahr s) {
  if (s.status == 'veranlagt') {
    final d = s.veranlagtAm ?? s.eingereichtAm;
    return d == null ? 'Veranlagt' : 'Veranlagt am ${_df.format(d)}';
  }
  final d = s.eingereichtAm;
  return d == null ? 'Eingereicht' : 'Eingereicht am ${_df.format(d)}';
}
