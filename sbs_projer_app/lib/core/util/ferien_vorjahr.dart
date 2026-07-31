/// Vorjahres-Hinweis auf Betriebsferien (Wunsch Daniel 31.07.2026).
///
/// Die meisten Betriebe machen jedes Jahr etwa zur gleichen Zeit Ferien.
/// Steht fuer das laufende Jahr noch keine Aussage fest, warnt der Tagesplan
/// mit dem Fenster aus einem frueheren Jahr: «Letztes Jahr hier
/// Betriebsferien (20.07.–10.08.) — nachfragen».
///
/// Bewusst nur ein **Hinweis**: Er verschiebt keine Faelligkeit und plant
/// nichts um. Ein aus dem Vorjahr abgeleitetes Datum ist eine Vermutung, und
/// eine Vermutung darf die Planung nicht steuern — sie darf nur dazu
/// anstossen, beim Kunden nachzufragen.
library;

import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';

/// Ein Ferienfenster. Absichtlich als schlichter Record, damit diese Datei
/// nichts aus der Datenschicht braucht und rein testbar bleibt.
typedef FerienFenster = ({DateTime von, DateTime bis});

/// Wie viele Tage das Fenster in beide Richtungen aufgeweitet wird.
/// Ferien wandern von Jahr zu Jahr um ein paar Tage (Wochentage, Schulferien),
/// deshalb eine Toleranz — einschliesslich der Randtage.
const int kVorjahrToleranzTage = 5;

/// Wie viele Jahre zurueck ein Fenster noch als Hinweis taugt. Zwei Jahre
/// sind vertretbar; aelteres sagt ueber den heutigen Betrieb zu wenig aus.
const int kVorjahrMaxJahre = 2;

/// Das passende Ferienfenster aus einem frueheren Jahr, oder `null`.
///
/// [perioden] sind alle bekannten Ferienfenster des Betriebs (beliebige
/// Jahre). [tag] ist der geplante Besuchstag. [hatAussageFuerJahr] sagt, ob
/// fuer das Jahr von [tag] bereits etwas feststeht — entweder eine erfasste
/// Periode oder ein ausdrueckliches «keine Ferien geplant». Ist das der Fall,
/// schweigt der Hinweis: Dann ist die Frage beantwortet.
///
/// Zurueckgegeben wird das **Original**-Fenster (mit seinem alten Jahr), denn
/// genau das soll im Hinweis stehen. Passen mehrere, gewinnt das juengste.
FerienFenster? vorjahresFerienHinweis({
  required List<FerienFenster> perioden,
  required DateTime tag,
  required bool hatAussageFuerJahr,
}) {
  if (hatAussageFuerJahr || perioden.isEmpty) return null;

  final besuchstag = DateTime(tag.year, tag.month, tag.day);
  FerienFenster? treffer;

  for (final periode in perioden) {
    // Das Fenster wird um 1 und um 2 Jahre nach vorne geschoben und dann
    // geprueft. Bewusst NICHT den Versatz aus dem Startjahr ableiten: Bei
    // einem Fenster ueber den Jahreswechsel (27.12.2024–06.01.2025) liegt
    // der Besuchstag im Januar sonst im falschen Zyklus. Beide Daten werden
    // um denselben Betrag verschoben, damit die Fensterlaenge erhalten bleibt.
    for (var versatz = 1; versatz <= kVorjahrMaxJahre; versatz++) {
      final von = DateTime(
        periode.von.year + versatz,
        periode.von.month,
        periode.von.day,
      ).subtract(const Duration(days: kVorjahrToleranzTage));
      final bis = DateTime(
        periode.bis.year + versatz,
        periode.bis.month,
        periode.bis.day,
      ).add(const Duration(days: kVorjahrToleranzTage));

      if (besuchstag.isBefore(von) || besuchstag.isAfter(bis)) continue;

      // Juengstes passendes Fenster gewinnt.
      if (treffer == null || periode.von.isAfter(treffer.von)) {
        treffer = periode;
      }
      break;
    }
  }

  return treffer;
}

/// Steht fuer [jahr] beim Betrieb [b] bereits eine Ferien-Aussage fest?
///
/// Fuettert [vorjahresFerienHinweis]s `hatAussageFuerJahr` direkt aus den
/// Feldern, die der Tagesplan ohnehin schon laedt (`betriebeProvider`) —
/// anders als [vorjahresFerienHinweis] selbst braucht dieser Helfer die
/// Datenschicht, bleibt aber eine reine Funktion (keine Queries).
///
/// Trifft eine von drei Bedingungen zu, gilt das Jahr als geklaert:
/// - eine erfasste Ferienperiode faellt in [jahr] (Start- ODER Endjahr, wegen
///   Perioden ueber den Jahreswechsel),
/// - [BetriebLocal.keineBetriebsferien] ist gesetzt (Betrieb macht grundsaetzlich
///   keine Ferien),
/// - [BetriebLocal.ferienBestaetigtAm] liegt im selben Jahr (die Ferienfrage
///   wurde fuer dieses Jahr beim Reinigungs-Abschluss schon beantwortet).
///
/// `null` in [BetriebLocal.ferienPerioden] heisst "noch nicht geladen" — dann
/// zaehlt fuer den ersten Punkt nichts, die anderen beiden bleiben gueltig.
bool hatFerienAussageFuerJahr(BetriebLocal b, int jahr) {
  if (b.keineBetriebsferien) return true;

  final bestaetigt = b.ferienBestaetigtAm;
  if (bestaetigt != null && bestaetigt.year == jahr) return true;

  final perioden = b.ferienPerioden;
  if (perioden != null) {
    for (final p in perioden) {
      if (p.von.year == jahr || p.bis.year == jahr) return true;
    }
  }

  return false;
}
