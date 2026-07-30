/// Routen-Optimierung fuer den Tagesplan (Tourenplan-Zeitachse).
///
/// Reine Funktion, bewusst ohne Kenntnis von Betrieben, Koordinaten oder
/// Datenbank: sie kennt nur Block-Ids und eine Fahrzeit-Funktion. Woher die
/// Minuten stammen (beobachtet, geroutet, Heuristik aus `fahrzeit.dart`), ist
/// Sache des Aufrufers — so bleibt die Optimierung testbar und der
/// Fahrzeit-Kaskade gegenueber gleichgueltig.
///
/// Bewusst NICHT beruecksichtigt: Besuchsdauern, Servicefenster und
/// Termin-Anker. Zielgroesse ist allein die Gesamtfahrzeit. Alles, was an
/// feste Uhrzeiten gebunden ist, kommt ueber `fixiert` herein — diese Bloecke
/// behalten ihren Platz, der Rest wird um sie herum sortiert. Damit kann das
/// Ergebnis nie einen Termin verschieben, und die Zeitachse
/// (`zeitplan.dart`) rechnet danach unveraendert weiter.
library;

/// Obergrenze fuer 2-opt-Durchlaeufe.
///
/// Ein Durchlauf prueft alle Paare (i, j) und bewertet jeden Kandidaten mit
/// [gesamtFahrzeit] — bei 20 Bloecken rund 190 Kandidaten a 20 Additionen,
/// also ~4'000 Rechenschritte pro Durchlauf. In der Praxis konvergiert das
/// Verfahren nach weniger als 10 Durchlaeufen; 100 ist reine Notbremse.
///
/// Sie ist noetig, weil die Fahrzeit-Matrix **nicht symmetrisch** sein muss
/// (Einbahnen, beobachtete Werte je Richtung). Bei asymmetrischen Kosten kann
/// 2-opt theoretisch zwischen gleichwertigen Loesungen pendeln; nur strikte
/// Verbesserungen werden akzeptiert, aber die Grenze garantiert zusaetzlich,
/// dass der Tagesplan bei keiner Datenlage haengen bleibt.
const int _maxDurchlaeufe = 100;

/// Gesamte Fahrzeit einer Reihenfolge in Minuten — Kennzahl fuer die Anzeige
/// «spart 23 min» und zugleich Zielfunktion der Optimierung.
///
/// [anfahrtVomStart] / [heimwegZumStart] sind `null`, wenn kein Startort
/// bekannt ist; dann zaehlen nur die Fahrten zwischen den Besuchen.
int gesamtFahrzeit({
  required List<String> reihenfolge,
  required int Function(String vonId, String nachId) fahrzeitZwischen,
  int Function(String blockId)? anfahrtVomStart,
  int Function(String blockId)? heimwegZumStart,
}) {
  if (reihenfolge.isEmpty) return 0;
  var summe = 0;
  if (anfahrtVomStart != null) summe += anfahrtVomStart(reihenfolge.first);
  for (var i = 0; i + 1 < reihenfolge.length; i++) {
    summe += fahrzeitZwischen(reihenfolge[i], reihenfolge[i + 1]);
  }
  if (heimwegZumStart != null) summe += heimwegZumStart(reihenfolge.last);
  return summe;
}

/// Sortiert [blockIds] so um, dass die Gesamtfahrzeit (inkl. Anfahrt und
/// Heimweg, soweit bekannt) moeglichst klein wird.
///
/// Verfahren: Naechster-Nachbar-Heuristik als Startloesung, danach
/// 2-opt-Verbesserung. Zusaetzlich wird 2-opt auch auf die **Eingangs**-
/// reihenfolge angewendet und am Ende die guenstigere der beiden Loesungen
/// zurueckgegeben. Grund: Naechster-Nachbar kann sich am Schluss einer Tour
/// verrennen (der letzte, weit entfernte Block bleibt uebrig) und dabei
/// schlechter werden als das, was der Nutzer schon von Hand geplant hatte.
/// Dieser Vergleich garantiert: **das Ergebnis ist nie schlechter als die
/// Eingabe.** Bei Gleichstand gewinnt die Eingangsreihenfolge — ohne echten
/// Gewinn wird die Liste des Nutzers nicht durcheinandergebracht.
///
/// [fixiert] enthaelt Block-Ids, die ihren Index behalten muessen (Bloecke mit
/// Termin-Anker). Sie werden weder von der Heuristik noch von 2-opt bewegt;
/// die uebrigen Bloecke werden auf die freien Plaetze verteilt.
///
/// Deterministisch: keine Zufallszahlen, keine Uhrzeit. Bei gleichwertigen
/// Alternativen entscheidet immer die Eingangsreihenfolge.
///
/// Die uebergebene Liste wird nicht veraendert; das Ergebnis ist eine neue
/// Liste mit denselben Ids.
List<String> optimiereReihenfolge({
  required List<String> blockIds,
  required int Function(String vonId, String nachId) fahrzeitZwischen,
  int Function(String blockId)? anfahrtVomStart,
  int Function(String blockId)? heimwegZumStart,
  Set<String> fixiert = const {},
}) {
  // 0 oder 1 Block: es gibt nichts zu vertauschen.
  if (blockIds.length < 2) return List<String>.of(blockIds);

  int kosten(List<String> reihenfolge) => gesamtFahrzeit(
    reihenfolge: reihenfolge,
    fahrzeitZwischen: fahrzeitZwischen,
    anfahrtVomStart: anfahrtVomStart,
    heimwegZumStart: heimwegZumStart,
  );

  final ausHeuristik = _zweiOpt(
    _naechsterNachbar(blockIds, fixiert, fahrzeitZwischen, anfahrtVomStart),
    fixiert,
    kosten,
  );
  final ausEingabe = _zweiOpt(List<String>.of(blockIds), fixiert, kosten);

  return kosten(ausEingabe) <= kosten(ausHeuristik) ? ausEingabe : ausHeuristik;
}

/// Startloesung: vom Startort (bzw. vom ersten Block) aus immer zum naechsten
/// noch offenen Block. Fixierte Bloecke sitzen bereits auf ihrem Platz und
/// dienen der Kette nur als Zwischenstation.
///
/// Ohne bekannten Startort gibt es keinen Anhaltspunkt fuer den ersten
/// Besuch — dann bleibt der erste Block der Eingangsreihenfolge der Anker
/// (deterministisch statt willkuerlich).
List<String> _naechsterNachbar(
  List<String> blockIds,
  Set<String> fixiert,
  int Function(String, String) fahrzeitZwischen,
  int Function(String)? anfahrtVomStart,
) {
  final ergebnis = List<String?>.filled(blockIds.length, null);
  final offen = <String>[];
  for (var i = 0; i < blockIds.length; i++) {
    if (fixiert.contains(blockIds[i])) {
      ergebnis[i] = blockIds[i];
    } else {
      offen.add(blockIds[i]);
    }
  }

  String? vorheriger;
  for (var i = 0; i < ergebnis.length; i++) {
    final belegt = ergebnis[i];
    if (belegt != null) {
      vorheriger = belegt;
      continue;
    }

    var besterIndex = 0;
    if (vorheriger != null || anfahrtVomStart != null) {
      int? besteKosten;
      for (var k = 0; k < offen.length; k++) {
        final kosten = vorheriger != null
            ? fahrzeitZwischen(vorheriger, offen[k])
            : anfahrtVomStart!(offen[k]);
        // Strikt kleiner: bei Gleichstand bleibt der frueher genannte Block
        // vorne — das macht das Ergebnis reproduzierbar.
        if (besteKosten == null || kosten < besteKosten) {
          besteKosten = kosten;
          besterIndex = k;
        }
      }
    }

    final gewaehlt = offen.removeAt(besterIndex);
    ergebnis[i] = gewaehlt;
    vorheriger = gewaehlt;
  }

  return ergebnis.cast<String>();
}

/// 2-opt: dreht jeweils einen Teilabschnitt der Tour um und behaelt die
/// Umkehrung, die am meisten spart. Wiederholt, bis keine Verbesserung mehr
/// gefunden wird (hoechstens [_maxDurchlaeufe] mal).
///
/// Jeder Kandidat wird ueber die volle Kostenfunktion bewertet statt ueber die
/// uebliche Vier-Kanten-Differenz. Das ist bei Tagesplan-Groessen (unter 30
/// Bloecken) unmessbar teurer, aber korrekt auch bei **asymmetrischen**
/// Fahrzeiten — dort aendert eine Umkehrung auch die Kosten *innerhalb* des
/// gedrehten Abschnitts, was die Kurzformel unterschlaegt.
List<String> _zweiOpt(
  List<String> start,
  Set<String> fixiert,
  int Function(List<String>) kosten,
) {
  var aktuell = List<String>.of(start);
  var aktuelleKosten = kosten(aktuell);

  // Fixierte Bloecke behalten ihren Index, darum bleibt diese Maske ueber
  // alle Durchlaeufe gueltig.
  final beweglich = List<bool>.generate(
    aktuell.length,
    (i) => !fixiert.contains(aktuell[i]),
  );

  for (var durchlauf = 0; durchlauf < _maxDurchlaeufe; durchlauf++) {
    var besteI = -1;
    var besteJ = -1;
    var besteKosten = aktuelleKosten;

    for (var i = 0; i < aktuell.length - 1; i++) {
      if (!beweglich[i]) continue;
      for (var j = i + 1; j < aktuell.length; j++) {
        // Eine Umkehrung verschiebt jeden Block im Abschnitt — sobald ein
        // fixierter darin liegt, ist auch jeder laengere Abschnitt tabu.
        if (!beweglich[j]) break;

        final kandidat = List<String>.of(aktuell);
        _dreheUm(kandidat, i, j);
        final neueKosten = kosten(kandidat);
        // Strikt besser: Gleichstand aendert nichts, sonst koennte das
        // Verfahren zwischen gleich teuren Touren pendeln.
        if (neueKosten < besteKosten) {
          besteKosten = neueKosten;
          besteI = i;
          besteJ = j;
        }
      }
    }

    if (besteI < 0) break;
    _dreheUm(aktuell, besteI, besteJ);
    aktuelleKosten = besteKosten;
  }

  return aktuell;
}

void _dreheUm(List<String> liste, int von, int bis) {
  var a = von;
  var b = bis;
  while (a < b) {
    final merk = liste[a];
    liste[a] = liste[b];
    liste[b] = merk;
    a++;
    b--;
  }
}
