/// Zeitplan-Berechnung fuer den Tagesplan-Tab (Spec 2026-07-29, Abschnitt 4).
///
/// Reine Funktion: aus einer geordneten Liste von Besuchs-Bloecken, dem
/// Arbeitsbeginn und einer Fahrzeit-Kaskade wird eine Kette von Segmenten
/// (Anfahrt | Besuch | Fahrt | Wartezeit | Heimweg) mit Start-/Endzeit
/// gebaut. Kein State, keine I/O — die UI (Task 6) liest das Ergebnis nur.
library;

/// `frei`: bereits verstrichene Zeit zwischen dem Ende des letzten erledigten
/// Ereignisses und «jetzt» — im Live-Modus des heutigen Tagesplans sichtbar
/// gemacht, damit ungenutzte Fenster auffallen (Daniel 30.07.2026).
enum SegmentArt { anfahrt, besuch, fahrt, wartezeit, heimweg, frei }

/// Ein planbarer Block (Besuch, Stoerung, Montage) mit seiner geschaetzten
/// oder manuell gesetzten Dauer und optionalem Termin-Anker.
class PlanBlock {
  final String id;
  final int dauerMinuten;

  /// Termin-Anker "fruehestens HH:mm" — liegt die berechnete Ankunft davor,
  /// entsteht ein Wartezeit-Segment.
  final String? ankerZeit;

  /// Gemessene Ist-Zeiten (Minuten seit Mitternacht), wenn der Block heute
  /// bereits erledigt wurde — Quelle: abgeschlossene Reinigung (Start/Ende)
  /// bzw. Wegpunkt-Stempel. Beide gesetzt = erledigt.
  final int? istStartMin;
  final int? istEndMin;

  bool get erledigt => istStartMin != null && istEndMin != null;

  const PlanBlock({
    required this.id,
    required this.dauerMinuten,
    this.ankerZeit,
    this.istStartMin,
    this.istEndMin,
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

  /// true = gemessene Vergangenheit (erledigter Besuch, echte Fahrt-Luecke),
  /// false = geplante Zukunft. Steuert nur die Darstellung.
  final bool ist;

  int get minuten => endMin - startMin;

  const ZeitSegment({
    required this.art,
    this.blockId,
    required this.startMin,
    required this.endMin,
    this.ist = false,
  });
}

/// Standard-Tagesstart 06:00 (Spec 2026-07-29) — Fallback, falls
/// `arbeitsbeginn` nicht als 'HH:mm' geparst werden kann.
const int kZeitleisteStartMin = 6 * 60;

/// 'HH:mm' -> Minuten seit Mitternacht, oder `null` bei ungueltiger Eingabe.
/// Lokale Kopie (bewusst nicht mit besuch_dauer.dart geteilt, siehe Plan
/// Task 5 Step 4 — wenige Zeilen, kein gemeinsamer Helfer noetig).
///
/// Gehaertet gegen korrupte Altdaten (Review-Fund): `int.parse` wuerde bei
/// einem beschaedigten `ankerZeit`/`arbeitsbeginn` (z.B. altes Format, leerer
/// String) die ganze Zeitplan-Berechnung zum Absturz bringen. Ein einzelner
/// kaputter Wert darf aber nie den gesamten Tagesplan unbrauchbar machen —
/// darum `tryParse` + Wertebereichs-Pruefung statt Exception.
int? _parseZeit(String hhmm) {
  final teile = hhmm.split(':');
  if (teile.length != 2) return null;
  final stunden = int.tryParse(teile[0]);
  final minuten = int.tryParse(teile[1]);
  if (stunden == null || minuten == null) return null;
  if (stunden < 0 || stunden > 23 || minuten < 0 || minuten > 59) return null;
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
  // Ungueltiger arbeitsbeginn (korrupte Altdaten) -> Standardstart 06:00,
  // statt die Berechnung fuer den ganzen Tag scheitern zu lassen.
  var aktuell = _parseZeit(arbeitsbeginn) ?? kZeitleisteStartMin;

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
      // Ungueltiger Anker (korrupte Altdaten) -> ignorieren, Besuch startet
      // ohne Wartezeit — statt die Berechnung fuer den ganzen Tag scheitern
      // zu lassen.
      if (ankerMin != null && ankerMin > aktuell) {
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

/// Live-Zeitachse fuer den HEUTIGEN Tagesplan (Daniel 30.07.2026):
/// Erledigte Bloecke erscheinen mit ihren GEMESSENEN Zeiten, der Rest des
/// Plans rechnet ab «jetzt» weiter — so sind Rueckstand, freie Fenster und
/// das voraussichtliche Tagesende jederzeit ablesbar.
///
/// Regeln:
/// - Erledigte Bloecke laufen in ihrer IST-Reihenfolge (nach istStartMin),
///   nicht in der Planreihenfolge — massgebend ist, was wirklich geschah.
/// - Die Luecke zwischen zwei erledigten Bloecken ist die gemessene
///   Uebergangszeit -> Fahrt-Segment mit `ist: true`.
/// - Zwischen dem Ende des letzten erledigten Blocks und «jetzt» entsteht ab
///   3 Minuten ein `frei`-Segment: verstrichene, ungenutzte Zeit.
/// - Der Rest-Plan startet bei max(jetzt, letztes Ist-Ende) — nie in der
///   Vergangenheit. Anker im Rest erzeugen wie gehabt Wartezeit (= das
///   sichtbare freie Fenster der Zukunft).
/// - Anfahrt: liegt ein erster Ist-Block vor, ist die Anfahrt die gemessene
///   Spanne arbeitsbeginn -> erster Ist-Start (`ist: true`); sonst geplant.
List<ZeitSegment> berechneZeitplanMitIst({
  required List<PlanBlock> bloecke,
  required int jetztMin,
  required String arbeitsbeginn,
  required int? anfahrtMinuten,
  required int? heimwegMinuten,
  required int Function(String vonBlockId, String nachBlockId) fahrzeitZwischen,
}) {
  if (bloecke.isEmpty) return const [];

  final erledigte = bloecke.where((b) => b.erledigt).toList()
    ..sort((a, b) => a.istStartMin!.compareTo(b.istStartMin!));
  final offene = bloecke.where((b) => !b.erledigt).toList();

  final segmente = <ZeitSegment>[];
  final beginnMin = _parseZeit(arbeitsbeginn) ?? kZeitleisteStartMin;
  var aktuell = beginnMin;
  String? vorherigeId;

  // ── Vergangenheit: gemessene Ereignisse ──
  for (final block in erledigte) {
    if (vorherigeId == null) {
      // Gemessene Anfahrt: Arbeitsbeginn bis erster Ist-Start. Nur wenn ein
      // Startort bekannt ist (anfahrtMinuten != null) — sonst waere die
      // Spanne blosse Wartezeit vor Ort, nicht unterscheidbar.
      if (anfahrtMinuten != null && block.istStartMin! > aktuell) {
        segmente.add(
          ZeitSegment(
            art: SegmentArt.anfahrt,
            startMin: aktuell,
            endMin: block.istStartMin!,
            ist: true,
          ),
        );
      }
    } else if (block.istStartMin! > aktuell) {
      // Gemessene Uebergangszeit (Fahrt + Ruesten) zwischen zwei Ereignissen.
      segmente.add(
        ZeitSegment(
          art: SegmentArt.fahrt,
          blockId: block.id,
          startMin: aktuell,
          endMin: block.istStartMin!,
          ist: true,
        ),
      );
    }
    segmente.add(
      ZeitSegment(
        art: SegmentArt.besuch,
        blockId: block.id,
        startMin: block.istStartMin!,
        endMin: block.istEndMin!,
        ist: true,
      ),
    );
    aktuell = block.istEndMin!;
    vorherigeId = block.id;
  }

  // ── Grenze Ist/Plan: verstrichene freie Zeit bis «jetzt» ──
  if (erledigte.isNotEmpty && jetztMin - aktuell >= 3) {
    segmente.add(
      ZeitSegment(
        art: SegmentArt.frei,
        startMin: aktuell,
        endMin: jetztMin,
        ist: true,
      ),
    );
  }
  // Der Rest beginnt nie in der Vergangenheit — und nie vor Arbeitsbeginn.
  aktuell = [aktuell, jetztMin, beginnMin].reduce((a, b) => a > b ? a : b);

  // ── Zukunft: Rest-Plan ab jetzt ──
  if (erledigte.isEmpty &&
      anfahrtMinuten != null &&
      anfahrtMinuten > 0 &&
      offene.isNotEmpty) {
    final ende = aktuell + anfahrtMinuten;
    segmente.add(
      ZeitSegment(art: SegmentArt.anfahrt, startMin: aktuell, endMin: ende),
    );
    aktuell = ende;
  }

  for (final block in offene) {
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
    final anker = block.ankerZeit != null ? _parseZeit(block.ankerZeit!) : null;
    if (anker != null && anker > aktuell) {
      segmente.add(
        ZeitSegment(
          art: SegmentArt.wartezeit,
          blockId: block.id,
          startMin: aktuell,
          endMin: anker,
        ),
      );
      aktuell = anker;
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
    segmente.add(
      ZeitSegment(
        art: SegmentArt.heimweg,
        startMin: aktuell,
        endMin: aktuell + heimwegMinuten,
      ),
    );
  }

  return segmente;
}
