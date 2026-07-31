/// Betriebs-Erkennung aus diktiertem Text (Etappe 2 der Einsatzplanung).
///
/// Daniel diktiert «Störung beim Sunset, Zapfhahn tropft». Diese Datei
/// findet heraus, welcher der rund 300 Betriebe gemeint ist — bevor die
/// KI-Auswertung überhaupt gefragt wird. Zwei Gründe für diese Vorstufe:
/// Sie funktioniert **ohne Netz**, und sie liefert der Auswertung eine
/// kurze Kandidatenliste statt aller Betriebe.
///
/// Die Messlatte: Lieber **keinen** Treffer als einen falschen. Ein falsch
/// zugeordneter Betrieb heisst, dass Daniel umsonst hinfährt — mehrdeutige
/// Fälle gehören deshalb als Rückfrage zurück, nicht als Rateergebnis.
///
/// Nutzt dieselben Bausteine wie das Google-Termin-Matching
/// (`google_termin_match.dart`): Umlaut-Faltung, Editierdistanz und das
/// Ausfiltern von Gattungswörtern wie «Hotel» oder «Gasthof».
library;

import 'package:sbs_projer_app/core/util/google_termin_match.dart'
    show editierDistanz, normalisiereText, unterscheidendeTokens;

/// Ein Betrieb, wie ihn die Erkennung braucht.
typedef BetriebEintrag = ({String id, String name, String ort});

/// Ein Treffer mit seiner Güte (0–1, höher ist besser).
typedef BetriebTreffer = ({String id, String name, double guete});

/// Höchstens so viele Kandidaten zurückgeben — mehr kann niemand sinnvoll
/// auswählen, und wenn es so viele sind, hilft nur Nachfragen.
const int _maxKandidaten = 3;

/// Kandidaten für den in [text] genannten Betrieb, beste zuerst.
///
/// Leer heisst: nichts Verlässliches gefunden. Genau ein Eintrag heisst:
/// eindeutig. Mehrere heissen: nachfragen.
List<BetriebTreffer> betriebKandidaten({
  required String text,
  required List<BetriebEintrag> betriebe,
}) {
  final norm = normalisiereText(text);
  if (norm.trim().isEmpty || betriebe.isEmpty) return const [];
  final textTokens = norm.split(' ').where((t) => t.isNotEmpty).toList();
  if (textTokens.isEmpty) return const [];

  final treffer = <BetriebTreffer>[];
  for (final b in betriebe) {
    final guete = _guete(textTokens, b);
    if (guete > 0) {
      treffer.add((id: b.id, name: b.name, guete: guete));
    }
  }
  if (treffer.isEmpty) return const [];

  treffer.sort((a, b) => b.guete.compareTo(a.guete));

  // Deutlich bessere Treffer verdrängen schwächere: Wer weniger als 60 %
  // der Güte des Besten erreicht, ist kein ernsthafter Kandidat mehr.
  final bester = treffer.first.guete;
  final ernsthaft = treffer.where((t) => t.guete >= bester * 0.6).toList();
  return ernsthaft.take(_maxKandidaten).toList();
}

/// Die Id, wenn die Zuordnung eindeutig ist — sonst `null`.
String? eindeutigerBetrieb({
  required String text,
  required List<BetriebEintrag> betriebe,
}) {
  final k = betriebKandidaten(text: text, betriebe: betriebe);
  return k.length == 1 ? k.first.id : null;
}

/// Güte der Übereinstimmung zwischen den Wörtern des Diktats und einem
/// Betrieb. 0 = kein Treffer.
double _guete(List<String> textTokens, BetriebEintrag b) {
  // Nur unterscheidende Namensteile zählen — «Hotel» allein darf keinen
  // Betrieb kapern, sonst trifft «Störung im Hotel» irgendetwas.
  final namensTokens = unterscheidendeTokens(b.name);
  if (namensTokens.isEmpty) return 0;

  var getroffen = 0;
  var summeGuete = 0.0;
  for (final nt in namensTokens) {
    final beste = _besteTokenGuete(textTokens, nt);
    if (beste > 0) {
      getroffen++;
      summeGuete += beste;
    }
  }
  if (getroffen == 0) return 0;

  // Anteil der getroffenen Namensteile, gewichtet mit ihrer Treffergüte.
  var guete = (summeGuete / namensTokens.length);

  // Der Ort ist ein Zusatzhinweis, kein eigener Treffer: Er hebt einen
  // sonst mehrdeutigen Namen («Sunset in Chur»), begründet aber allein
  // keinen Kandidaten.
  final ortTokens = unterscheidendeTokens(b.ort);
  for (final ot in ortTokens) {
    if (_besteTokenGuete(textTokens, ot) > 0) {
      guete += 0.25;
      break;
    }
  }

  return guete;
}

/// Beste Übereinstimmung eines Namensteils mit irgendeinem Wort des
/// Diktats: 1.0 bei exakter Gleichheit, 0.7 bei Tippfehler-Nähe, sonst 0.
double _besteTokenGuete(List<String> textTokens, String namensToken) {
  var beste = 0.0;
  for (final t in textTokens) {
    if (t == namensToken) return 1.0;
    // Toleranz wächst mit der Wortlänge: Bei kurzen Wörtern wäre schon ein
    // Zeichen Unterschied ein anderes Wort.
    final maxDist = namensToken.length <= 4
        ? 0
        : (namensToken.length <= 7 ? 1 : 2);
    if (maxDist > 0 && editierDistanz(t, namensToken) <= maxDist) {
      beste = beste < 0.7 ? 0.7 : beste;
    }
  }
  return beste;
}
