/// Reine Vergleichslogik gegen die Doppelanzeige zwischen den automatisch
/// berechneten Eröffnungs-/Endreinigungs-Vorschlägen (`autoTermineProvider`
/// in `tour_providers.dart`) und bereits bestätigten Terminen (Tabelle
/// `termine`).
///
/// Leitgedanke (Etappe 4): «Berechnet bleibt berechnet, bestätigt wird
/// gespeichert.» Die Saison-Automatik rechnet immer weiter und kann ihr
/// Zieldatum leicht verschieben (z.B. wenn nachträglich Betriebsferien
/// erfasst werden) — ein bereits bestätigter Termin für denselben Betrieb
/// und Typ soll deshalb nicht knapp daneben ein zweites Mal als Vorschlag
/// auftauchen. Toleranz: ±7 Tage.
library;

/// Minimaler Ausschnitt eines bestehenden Termins für den Abgleich.
class TerminVergleich {
  final String betriebId;

  /// 'eroeffnungsreinigung' | 'endreinigung' (siehe `TerminDto.typ`).
  final String typ;
  final DateTime datum;

  const TerminVergleich({
    required this.betriebId,
    required this.typ,
    required this.datum,
  });
}

const _toleranzTage = 7;

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

/// Deckt einer der [bestehendeTermine] den Vorschlag
/// ([vorschlagBetriebId]/[vorschlagTyp]/[vorschlagDatum]) bereits ab?
///
/// Ja, wenn ein Termin mit demselben Betrieb, demselben Typ existiert und
/// dessen Datum höchstens 7 Tage vom Vorschlags-Datum abweicht (in beide
/// Richtungen).
bool terminDecktVorschlagAb({
  required String vorschlagBetriebId,
  required String vorschlagTyp,
  required DateTime vorschlagDatum,
  required Iterable<TerminVergleich> bestehendeTermine,
}) {
  final vTag = _tag(vorschlagDatum);
  for (final t in bestehendeTermine) {
    if (t.betriebId != vorschlagBetriebId) continue;
    if (t.typ != vorschlagTyp) continue;
    final diffTage = vTag.difference(_tag(t.datum)).inDays.abs();
    if (diffTage <= _toleranzTage) return true;
  }
  return false;
}
