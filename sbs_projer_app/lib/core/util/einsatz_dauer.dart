/// Dauer-Vorgaben für Störungen und Montagen im Tagesplan.
///
/// Bisher galt für beide pauschal [kDauerDefaultMinuten] = 60 Minuten,
/// unabhängig davon, ob ein Zapfhahn tropft oder eine ganze Anlage neu
/// montiert wird. Diese Datei schätzt differenzierter.
///
/// **Warum feste Werte und kein Median wie bei den Reinigungen?** Weil es
/// nichts zu mitteln gibt: Von 1'108 Störungen und 810 Montagen hat keine
/// einzige eine erfasste Arbeitszeit (Stand 31.07.2026). Erst wenn über
/// `arbeit_von`/`arbeit_bis` genug Ist-Zeiten zusammengekommen sind, lässt
/// sich das durch echte Mediane ersetzen — so wie es `besuch_dauer.dart`
/// für Reinigungen aus 8'472 Datensätzen tut. Bis dahin sind das begründete
/// Anhaltspunkte, keine Messwerte.
library;

import 'package:sbs_projer_app/core/util/besuch_dauer.dart'
    show kDauerDefaultMinuten;

/// Grundzeit einer Störung: Ankommen, Anlage anschauen, Werkzeug holen.
const int _stoerungGrundMin = 20;

/// Aufschlag je betroffenem Störungsbereich (Zapfhahn, Leitung, Kühler,
/// Zapfkopf, Gas). Der zweite Bereich kostet weniger als der erste, weil
/// man ohnehin schon vor Ort und an der Anlage ist.
const List<int> _stoerungBereichAufschlag = [25, 20, 20, 15, 15];

/// Obergrenze für Störungen — darüber ist es keine Schätzung mehr, sondern
/// ein Tagesprojekt, das Daniel ohnehin von Hand plant.
const int _stoerungMaxMin = 180;

/// Vorgaben je Montage-Typ. `spesen` und `aufwandsentschaedigung` sind reine
/// Abrechnungsposten ohne Einsatz beim Kunden und brauchen keinen Block.
const Map<String, int> _montageVorgabe = {
  'neumontage': 120,
  'demontage': 75,
  'abaenderung': 90,
  'heigenie_service': 45,
  'anlass': 240,
  'spesen': 0,
  'aufwandsentschaedigung': 0,
};

/// Voraussichtliche Dauer eines Einsatzes in Minuten.
///
/// [art] ist `stoerung` oder `montage`. Für Störungen zählen die
/// [stoerungBereiche] (1–5), für Montagen der [montageTyp]. Fehlt die
/// Angabe oder ist sie unbekannt, gilt die Standarddauer.
///
/// Das Ergebnis ist immer ein Vielfaches von 5 Minuten — der Tagesplan
/// rechnet in 5-Minuten-Schritten.
int einsatzDauerVorgabe({
  required String art,
  String? montageTyp,
  List<int>? stoerungBereiche,
}) {
  if (art == 'montage') {
    if (montageTyp == null) return kDauerDefaultMinuten;
    final vorgabe = _montageVorgabe[montageTyp];
    return vorgabe ?? kDauerDefaultMinuten;
  }

  if (art == 'stoerung') {
    final bereiche = stoerungBereiche ?? const [];
    if (bereiche.isEmpty) return kDauerDefaultMinuten;
    var minuten = _stoerungGrundMin;
    for (var i = 0; i < bereiche.length; i++) {
      minuten += i < _stoerungBereichAufschlag.length
          ? _stoerungBereichAufschlag[i]
          : _stoerungBereichAufschlag.last;
    }
    return _auf5(minuten.clamp(0, _stoerungMaxMin));
  }

  return kDauerDefaultMinuten;
}

int _auf5(int minuten) => (minuten / 5).round() * 5;
