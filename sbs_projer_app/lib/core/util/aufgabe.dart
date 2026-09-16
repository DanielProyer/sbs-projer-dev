/// Ein Aufgaben-Begriff (B6).
///
/// WARUM: Glocke und Kachel «Aufgaben» hatten zwei Quellen — die Glocke
/// zeigte die fällige Heineken-Rechnung, aber nicht die offene Störung; die
/// Kachel umgekehrt (Befund 4 der App-Analyse 09/2026). Hier steht einmal,
/// was eine Aufgabe ist, wann sie «jetzt fällig» ist und wie die Liste
/// gebaut wird. Reine Funktionen mit Primitiven — testbar ohne Supabase.
library;

import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_faellig.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/core/util/termin_abgleich.dart';

/// Woher ein Eintrag kommt. Die Reihenfolge ist die Sortierung innerhalb
/// eines Tages (nach «dringend»).
enum AufgabenQuelle {
  detektor,
  eigene,
  einsatz,
  saisonVorschlag,
  aenderungsVorschlag,
  termin,
}

/// Berechneter Eröffnungs-/Endreinigungs-Vorschlag aus der Saison-Automatik.
typedef SaisonVorschlag = ({
  String betriebId,
  String betriebName,
  String? betriebOrt,
  String typ, // 'eroeffnungsreinigung' | 'endreinigung'
  DateTime zielDatum,
  String beschreibung,
});

/// Bestätigter Saison-Termin (Tabelle `termine`, offen).
typedef SaisonTerminEintrag = ({
  String id,
  String betriebId,
  String betriebName,
  String? betriebOrt,
  String typ,
  DateTime datum,
  String titel,
});

/// Was «Bestätigen» bei einem Saison-Vorschlag anlegt.
typedef SaisonTerminAnlage = ({
  String betriebId,
  String typ,
  DateTime datum,
  String titel,
  String anlass,
});

/// Ein Eintrag der gemeinsamen Aufgabenliste. Trägt Daten, keine Callbacks —
/// welche Knöpfe eine Zeile zeigt, folgt aus der Quelle.
class AufgabenEintrag {
  final AufgabenQuelle quelle;

  /// Deterministisch, für Snooze und Marker: 'heineken:2026-08',
  /// `'eigene:<uuid>'`, `'einsatz:stoerung:<routeId>'`,
  /// `'saison:<betriebId>:<typ>'`, 'vorschlaege', `'termin:<id>'`.
  final String key;
  final String titel;
  final String? untertitel;
  final DateTime? faellig;
  final bool dringend;

  /// «Dorthin»-Ziel; bei Einsätzen die Detailseite.
  final String? route;
  final Einsatz? einsatz;
  final String? eigeneId;
  final String? terminId;
  final SaisonTerminAnlage? saison;

  /// Nur Detektoren: Haken zeigen (heute nur MWST).
  final bool manuellErledigbar;

  /// Siehe `Aufgabe.istVorrat` — ein Stapel ohne Stichtag (B3).
  final bool istVorrat;

  const AufgabenEintrag({
    required this.quelle,
    required this.key,
    required this.titel,
    this.untertitel,
    this.faellig,
    this.dringend = false,
    this.route,
    this.einsatz,
    this.eigeneId,
    this.terminId,
    this.saison,
    this.manuellErledigbar = false,
    this.istVorrat = false,
  });

  bool get erledigbar =>
      quelle == AufgabenQuelle.eigene ||
      quelle == AufgabenQuelle.termin ||
      (quelle == AufgabenQuelle.detektor && manuellErledigbar);

  /// Einsätze werden nicht gesnoozt, sondern eingeplant.
  bool get snoozebar =>
      quelle == AufgabenQuelle.detektor ||
      quelle == AufgabenQuelle.eigene ||
      quelle == AufgabenQuelle.aenderungsVorschlag;

  bool get einplanbar =>
      quelle == AufgabenQuelle.einsatz &&
      (einsatz!.typ == EinsatzTyp.stoerung ||
          einsatz!.typ == EinsatzTyp.montage);

  bool get bestaetigbar => quelle == AufgabenQuelle.saisonVorschlag;
}

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Fälligkeit eines Einsatzes: der geplante Tag, sonst das Meldedatum.
DateTime einsatzFaelligkeit(Einsatz e) => e.geplantAm ?? e.datum;

/// Gehört der Eintrag in Glocke, Startkarte, Kachelzähler und Sheet?
/// Detektoren und Änderungsvorschläge immer (Snooze ist schon angewandt);
/// eigene Aufgaben ab Fälligkeit −7 Tage (bestehende Regel); Einsätze,
/// Saison-Vorschläge und Termine erst am Tag selbst oder überfällig —
/// die geplante Montage von Donnerstag steht im Tagesplan, nicht in der
/// Glocke (Daniel 15.09.2026, Schwelle 1). Vorräte sind nie jetzt fällig
/// (B3).
bool jetztFaellig(AufgabenEintrag a, DateTime heute) {
  // Ein Vorrat wächst und schrumpft ohne Stichtag — er gehört in den
  // Aufgaben-Screen und ins Büro, nicht in die Glocke (B3).
  if (a.istVorrat) return false;
  return switch (a.quelle) {
    AufgabenQuelle.detektor || AufgabenQuelle.aenderungsVorschlag => true,
    AufgabenQuelle.eigene => eigeneSichtbar(a.faellig, heute),
    AufgabenQuelle.einsatz ||
    AufgabenQuelle.saisonVorschlag ||
    AufgabenQuelle.termin =>
      a.faellig != null && !_tag(a.faellig!).isAfter(_tag(heute)),
  };
}

/// Wohin die Büro-Startseite schaut. Die Zugehörigkeit folgt aus dem Ziel,
/// nicht aus einem zweiten Pflegefeld: Ein neuer Detektor, der in die
/// Buchhaltung führt, erscheint dort von selbst; Saisondaten (`/touren`)
/// fällt heraus, ohne dass jemand daran denken muss.
const _bueroPraefixe = ['/buchhaltung', '/rechnungen', '/heineken'];

bool istBueroAufgabe(AufgabenEintrag a) {
  final r = a.route;
  if (r == null) return false;
  return _bueroPraefixe.any((p) => r == p || r.startsWith('$p/'));
}

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Kurztext für die Zeile: «überfällig seit 3 Tagen», «heute», «morgen»,
/// «Do 17.09.» oder leer.
String faelligText(DateTime? faellig, DateTime heute) {
  if (faellig == null) return '';
  final f = _tag(faellig);
  final h = _tag(heute);
  final tage = h.difference(f).inDays;
  if (tage > 0) return 'überfällig seit $tage ${tage == 1 ? 'Tag' : 'Tagen'}';
  if (tage == 0) return 'heute';
  if (tage == -1) return 'morgen';
  return '${_wochentage[f.weekday - 1]} '
      '${f.day.toString().padLeft(2, '0')}.${f.month.toString().padLeft(2, '0')}.';
}

/// Baut die eine Liste. Sortiert nach Fälligkeit (ohne Datum zuletzt), am
/// selben Tag dringend zuerst, dann Quelle, dann Titel.
List<AufgabenEintrag> baueAufgabenListe({
  required List<Aufgabe> detektoren,
  required List<Map<String, dynamic>> aufgabenZeilen,
  required List<Einsatz> anstehend,
  required List<SaisonVorschlag> saisonVorschlaege,
  required List<SaisonTerminEintrag> saisonTermine,
  required int aenderungsVorschlaege,
  required DateTime heute,
}) {
  final heuteTag = _tag(heute);

  final snoozes = <String, DateTime>{};
  for (final z in aufgabenZeilen.where((z) => z['typ'] == 'snooze')) {
    final bis = DateTime.tryParse(z['snooze_bis'] as String? ?? '');
    if (z['key'] != null && bis != null) snoozes[z['key'] as String] = bis;
  }
  bool gesnoozt(String key) => snoozeAktiv(snoozes[key], heute);

  final liste = <AufgabenEintrag>[];

  // Detektoren sind per Definition jetzt fällig — Fälligkeit heute, damit sie
  // im Screen unter «Heute» stehen und nicht unter «Ohne Datum».
  for (final a in detektoren) {
    if (gesnoozt(a.key)) continue;
    liste.add(
      AufgabenEintrag(
        quelle: AufgabenQuelle.detektor,
        key: a.key,
        titel: a.titel,
        faellig: heuteTag,
        dringend: a.dringend,
        route: a.route,
        manuellErledigbar: a.manuellErledigbar,
        istVorrat: a.istVorrat,
      ),
    );
  }

  if (aenderungsVorschlaege > 0 && !gesnoozt('vorschlaege')) {
    liste.add(
      AufgabenEintrag(
        quelle: AufgabenQuelle.aenderungsVorschlag,
        key: 'vorschlaege',
        titel: '$aenderungsVorschlaege Änderungsvorschläge prüfen',
        faellig: heuteTag,
        route: '/betriebe/vorschlaege',
      ),
    );
  }

  for (final z in aufgabenZeilen.where((z) => z['typ'] == 'eigene')) {
    if (z['erledigt_am'] != null) continue;
    final id = z['id'] as String;
    final key = 'eigene:$id';
    if (gesnoozt(key)) continue;
    final faellig = DateTime.tryParse(z['faellig_am'] as String? ?? '');
    liste.add(
      AufgabenEintrag(
        quelle: AufgabenQuelle.eigene,
        key: key,
        titel: (z['titel'] ?? '?') as String,
        faellig: faellig,
        dringend: faellig != null && !_tag(faellig).isAfter(heuteTag),
        eigeneId: id,
      ),
    );
  }

  for (final e in anstehend) {
    final faellig = einsatzFaelligkeit(e);
    final plan = e.typ == EinsatzTyp.stoerung || e.typ == EinsatzTyp.montage
        ? planungsText(geplantAm: e.geplantAm, geplantZeit: e.zeit)
        : null;
    final untertitel = [
      if (e.beschreibung != null && e.beschreibung!.isNotEmpty) e.beschreibung!,
      if (plan != null) plan,
      if (plan == null && e.betriebOrt != null) e.betriebOrt!,
    ].join(' · ');
    liste.add(
      AufgabenEintrag(
        quelle: AufgabenQuelle.einsatz,
        key: 'einsatz:${e.typ.name}:${e.routeId}',
        titel: '${e.typLabel} ${e.betriebName}',
        untertitel: untertitel.isEmpty ? null : untertitel,
        faellig: faellig,
        // Gemeldet ohne Termin oder überfällig — das ist der Morgen-Fall.
        dringend:
            e.status == EinsatzStatus.offen || _tag(faellig).isBefore(heuteTag),
        route: e.detailRoute,
        einsatz: e,
      ),
    );
  }

  final bestehende = [
    for (final t in saisonTermine)
      TerminVergleich(betriebId: t.betriebId, typ: t.typ, datum: t.datum),
  ];
  for (final v in saisonVorschlaege) {
    // Ein Vorschlag, den ein bestätigter Termin (±7 Tage) abdeckt, würde
    // sonst doppelt erscheinen — einmal als Vorschlag, einmal als Termin.
    if (terminDecktVorschlagAb(
      vorschlagBetriebId: v.betriebId,
      vorschlagTyp: v.typ,
      vorschlagDatum: v.zielDatum,
      bestehendeTermine: bestehende,
    )) {
      continue;
    }
    final label = v.typ == 'endreinigung'
        ? 'Endreinigung'
        : 'Eröffnungsreinigung';
    final titel = '$label ${v.betriebName}'.trim();
    liste.add(
      AufgabenEintrag(
        quelle: AufgabenQuelle.saisonVorschlag,
        key: 'saison:${v.betriebId}:${v.typ}',
        titel: titel,
        untertitel: v.betriebOrt,
        faellig: v.zielDatum,
        route: '/betriebe/${v.betriebId}',
        saison: (
          betriebId: v.betriebId,
          typ: v.typ,
          datum: v.zielDatum,
          titel: titel,
          anlass: v.typ == 'endreinigung' ? 'saisonende' : 'saisonstart',
        ),
      ),
    );
  }

  for (final t in saisonTermine) {
    final label = t.typ == 'endreinigung'
        ? 'Endreinigung'
        : 'Eröffnungsreinigung';
    liste.add(
      AufgabenEintrag(
        quelle: AufgabenQuelle.termin,
        key: 'termin:${t.id}',
        titel: t.titel.isNotEmpty ? t.titel : '$label ${t.betriebName}',
        untertitel: t.betriebOrt,
        faellig: t.datum,
        dringend: _tag(t.datum).isBefore(heuteTag),
        route: '/betriebe/${t.betriebId}',
        terminId: t.id,
      ),
    );
  }

  liste.sort((a, b) {
    if (a.faellig == null && b.faellig == null) {
      return a.titel.compareTo(b.titel);
    }
    if (a.faellig == null) return 1;
    if (b.faellig == null) return -1;
    final tag = _tag(a.faellig!).compareTo(_tag(b.faellig!));
    if (tag != 0) return tag;
    final d = (b.dringend ? 1 : 0) - (a.dringend ? 1 : 0);
    if (d != 0) return d;
    final q = a.quelle.index.compareTo(b.quelle.index);
    if (q != 0) return q;
    return a.titel.compareTo(b.titel);
  });
  return liste;
}
