/// Offene Rechnungen, gebündelt pro Betrieb.
///
/// WARUM es das gibt (21.09.2026): Der Forderungen-Hub gruppiert nach Monat und
/// Tag. Das beantwortet «was lief im März?», nicht «wer schuldet mir wie viel?».
/// Für ein Telefonat beim Wirt braucht es die zweite Sicht — alle offenen
/// Posten eines Betriebs auf einem Blick, mit der Frage daneben, ob die
/// Rechnung überhaupt bei ihm angekommen ist.
library;

import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Gilt eine Rechnung als offen? Bewusst als Negativliste: Jeder neue
/// Zwischenstatus (erinnert, mahnung_1, …) zählt automatisch als offen, statt
/// still aus der Liste zu fallen.
const kErledigteStatus = {'bezahlt', 'abgeschrieben'};

bool istOffen(Rechnung r) => !kErledigteStatus.contains(r.zahlungsstatus);

/// Ein Betrieb mit seinen offenen Rechnungen.
class BetriebOffen {
  /// null bei Rechnungen ohne Betriebsbezug (z. B. Heineken-Monatsrechnung).
  final String? betriebId;
  final String name;
  final String? ort;

  /// Absteigend nach Rechnungsdatum — die jüngste zuoberst.
  final List<Rechnung> rechnungen;

  const BetriebOffen({
    required this.betriebId,
    required this.name,
    required this.ort,
    required this.rechnungen,
  });

  int get anzahl => rechnungen.length;

  double get summe => rechnungen.fold<double>(0, (s, r) => s + r.betragBrutto);

  /// Ältestes Rechnungsdatum — je weiter zurück, desto dringender.
  DateTime get aeltestes => rechnungen
      .map((r) => r.rechnungsdatum)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  /// Rechnungen ohne jeden Zustellnachweis. Das ist KEIN Zahlungsverzug,
  /// sondern der Verdacht auf eine nie gestellte Rechnung — mahnen wäre hier
  /// der falsche Schritt (Lehre aus Blue Cinema: 32 Rechnungen über vier Jahre,
  /// keine einzige je versendet).
  int get ohneZustellung => rechnungen
      .where((r) => r.uebergebenAm == null && r.versendetAm == null)
      .length;
}

/// Bündelt [alle] Rechnungen zu offenen Posten pro Betrieb.
///
/// [jahr] null bedeutet «alle Jahre». Gefiltert wird über `rechnungsdatum`,
/// nicht über `created_at` — massgebend ist, wann die Leistung verrechnet
/// wurde, nicht wann die Zeile entstand (die Historik-Importe von 2019–2023
/// wurden alle 2026 angelegt).
///
/// Sortiert nach offenem Betrag absteigend: Wer am meisten schuldet, steht
/// oben. Bei gleichem Betrag alphabetisch, damit die Reihenfolge zwischen zwei
/// Aufrufen stabil bleibt.
List<BetriebOffen> offeneProBetrieb({
  required List<Rechnung> alle,
  required int? jahr,
  required Map<String, String> namen,
  required Map<String, String> orte,
}) {
  final gruppen = <String, List<Rechnung>>{};
  for (final r in alle) {
    if (!istOffen(r)) continue;
    if (jahr != null && r.rechnungsdatum.year != jahr) continue;
    gruppen.putIfAbsent(r.betriebId ?? _ohneBetrieb, () => []).add(r);
  }

  final result = <BetriebOffen>[];
  for (final eintrag in gruppen.entries) {
    final id = eintrag.key == _ohneBetrieb ? null : eintrag.key;
    final liste = eintrag.value
      ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));
    result.add(
      BetriebOffen(
        betriebId: id,
        name: _name(id, liste, namen),
        ort: id == null ? null : orte[id],
        rechnungen: liste,
      ),
    );
  }

  result.sort((a, b) {
    final nachBetrag = b.summe.compareTo(a.summe);
    if (nachBetrag != 0) return nachBetrag;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return result;
}

const _ohneBetrieb = '__ohne_betrieb__';

String _name(String? id, List<Rechnung> liste, Map<String, String> namen) {
  if (id == null) {
    // Die Heineken-Monatsrechnung hängt bewusst an keinem Betrieb. Sie als
    // «Ohne Betrieb» zu zeigen wäre richtig, aber nichtssagend.
    return liste.every((r) => r.rechnungstyp == 'heineken_monat')
        ? 'Heineken-Monatsrechnung'
        : 'Ohne Betrieb';
  }
  // Ein Betrieb, den die Namensliste nicht kennt (gelöscht oder noch nicht
  // geladen), darf nicht als leere Zeile erscheinen — sonst sucht man den
  // Fehler in der Summe statt im Stammdatensatz.
  return namen[id] ?? 'Unbekannter Betrieb';
}

/// Kurzform der Versandart für die Listenzeile. Die ausführlichen Texte in
/// `zahlungsartKlartext()` erklären, was ein Abschluss AUSLÖST — hier geht es
/// nur darum, was mit der fertigen Rechnung geschah.
String versandartKurz(String? art) => switch (art) {
  'rechnung_tresen' => 'Tresen',
  'rechnung_mail' => 'E-Mail',
  'rechnung_post' => 'Post',
  'barzahlung' => 'Bar',
  'jahresrechnung' => 'Jahresrechnung',
  'heineken' => 'Heineken',
  null || '' => 'ohne Angabe',
  _ => art,
};
