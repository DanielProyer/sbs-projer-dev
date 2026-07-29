/// Zeitplan-Berechnung fuer den Tagesplan-Tab (Spec 2026-07-29, Abschnitt 4).
///
/// Reine Funktion: aus einer geordneten Liste von Besuchs-Bloecken, dem
/// Arbeitsbeginn und einer Fahrzeit-Kaskade wird eine Kette von Segmenten
/// (Anfahrt | Besuch | Fahrt | Wartezeit | Heimweg) mit Start-/Endzeit
/// gebaut. Kein State, keine I/O — die UI (Task 6) liest das Ergebnis nur.
library;

enum SegmentArt { anfahrt, besuch, fahrt, wartezeit, heimweg }

/// Ein planbarer Block (Besuch, Stoerung, Montage) mit seiner geschaetzten
/// oder manuell gesetzten Dauer und optionalem Termin-Anker.
class PlanBlock {
  final String id;
  final int dauerMinuten;

  /// Termin-Anker "fruehestens HH:mm" — liegt die berechnete Ankunft davor,
  /// entsteht ein Wartezeit-Segment.
  final String? ankerZeit;

  const PlanBlock({
    required this.id,
    required this.dauerMinuten,
    this.ankerZeit,
  });
}

/// Ein Abschnitt der Tageszeitachse.
class ZeitSegment {
  final SegmentArt art;

  /// Block, zu dem das Segment gehoert (Besuch/Wartezeit: der Block selbst;
  /// Fahrt: der Zielblock). Bei Anfahrt/Heimweg gibt es keinen Block.
  final String? blockId;
  final int startMin;
  final int endMin;

  int get minuten => endMin - startMin;

  const ZeitSegment({
    required this.art,
    this.blockId,
    required this.startMin,
    required this.endMin,
  });
}

/// 'HH:mm' -> Minuten seit Mitternacht. Lokale Kopie (bewusst nicht mit
/// besuch_dauer.dart geteilt, siehe Plan Task 5 Step 4 — 6 Zeilen, kein
/// gemeinsamer Helfer noetig).
int _parseZeit(String hhmm) {
  final teile = hhmm.split(':');
  final stunden = int.parse(teile[0]);
  final minuten = int.parse(teile[1]);
  return stunden * 60 + minuten;
}

/// Baut die Tageszeitachse aus den Bloecken in ihrer gegebenen Reihenfolge.
///
/// - `arbeitsbeginn`: Start der Zeitachse ('HH:mm').
/// - `anfahrtMinuten`/`heimwegMinuten`: `null` = kein Startort bekannt, kein
///   Segment. `0` erzeugt (wie jede andere Dauer) kein Segment, da es keine
///   sichtbare Zeitspanne darstellt.
/// - `fahrzeitZwischen(vonBlockId, nachBlockId)`: Fahrzeit zwischen zwei
///   aufeinanderfolgenden Bloecken; `0` Minuten -> kein Fahrt-Segment.
List<ZeitSegment> berechneZeitplan({
  required List<PlanBlock> bloecke,
  required String arbeitsbeginn,
  required int? anfahrtMinuten,
  required int? heimwegMinuten,
  required int Function(String vonBlockId, String nachBlockId) fahrzeitZwischen,
}) {
  if (bloecke.isEmpty) return const [];

  final segmente = <ZeitSegment>[];
  var aktuell = _parseZeit(arbeitsbeginn);

  if (anfahrtMinuten != null && anfahrtMinuten > 0) {
    final ende = aktuell + anfahrtMinuten;
    segmente.add(
      ZeitSegment(art: SegmentArt.anfahrt, startMin: aktuell, endMin: ende),
    );
    aktuell = ende;
  }

  String? vorherigeId;
  for (final block in bloecke) {
    if (vorherigeId != null) {
      final fahrt = fahrzeitZwischen(vorherigeId, block.id);
      if (fahrt > 0) {
        final ende = aktuell + fahrt;
        segmente.add(
          ZeitSegment(
            art: SegmentArt.fahrt,
            blockId: block.id,
            startMin: aktuell,
            endMin: ende,
          ),
        );
        aktuell = ende;
      }
    }

    final anker = block.ankerZeit;
    if (anker != null) {
      final ankerMin = _parseZeit(anker);
      if (ankerMin > aktuell) {
        segmente.add(
          ZeitSegment(
            art: SegmentArt.wartezeit,
            blockId: block.id,
            startMin: aktuell,
            endMin: ankerMin,
          ),
        );
        aktuell = ankerMin;
      }
      // Ankunft nach dem Anker: keine Wirkung, nur Anzeige am Block (UI).
    }

    final ende = aktuell + block.dauerMinuten;
    segmente.add(
      ZeitSegment(
        art: SegmentArt.besuch,
        blockId: block.id,
        startMin: aktuell,
        endMin: ende,
      ),
    );
    aktuell = ende;
    vorherigeId = block.id;
  }

  if (heimwegMinuten != null && heimwegMinuten > 0) {
    final ende = aktuell + heimwegMinuten;
    segmente.add(
      ZeitSegment(art: SegmentArt.heimweg, startMin: aktuell, endMin: ende),
    );
    aktuell = ende;
  }

  return segmente;
}
