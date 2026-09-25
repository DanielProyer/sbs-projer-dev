/// Rechnungen, gebündelt pro Betrieb.
///
/// WARUM es das gibt (21.09.2026): Der Forderungen-Hub gruppiert nach Monat und
/// Tag. Das beantwortet «was lief im März?», nicht «wer schuldet mir wie viel?».
/// Für ein Telefonat beim Wirt braucht es die zweite Sicht — alle Posten eines
/// Betriebs auf einem Blick, mit der Frage daneben, ob die Rechnung überhaupt
/// bei ihm angekommen ist.
library;

import 'package:sbs_projer_app/core/util/rechnung_status.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

// `istOffen`/`kErledigteStatus` leben seit 25.09.2026 in rechnung_status.dart —
// eine Quelle zusammen mit `istZahlbar` (Bankabgleich). Hier weitergereicht,
// damit bestehende Aufrufer unverändert bleiben.
export 'package:sbs_projer_app/core/util/rechnung_status.dart'
    show istOffen, kErledigteStatus;

/// Welche Rechnungen sollen in die Auswertung?
enum RechnungsAuswahl {
  /// Nur unbezahlte — die Mahn- und Telefonliste.
  offen,

  /// Auch bezahlte und abgeschriebene — die Jahresübersicht je Kunde.
  alle,
}

/// Ein Betrieb mit seinen Rechnungen.
class BetriebRechnungen {
  /// null bei Rechnungen ohne Betriebsbezug (z. B. Heineken-Monatsrechnung).
  final String? betriebId;
  final String name;
  final String? ort;

  /// Absteigend nach Rechnungsdatum — die jüngste zuoberst.
  final List<Rechnung> rechnungen;

  const BetriebRechnungen({
    required this.betriebId,
    required this.name,
    required this.ort,
    required this.rechnungen,
  });

  int get anzahl => rechnungen.length;

  /// Summe aller angezeigten Rechnungen (bei [RechnungsAuswahl.alle] also der
  /// Jahresumsatz dieses Betriebs, bezahlt und unbezahlt zusammen).
  double get summe => rechnungen.fold<double>(0, (s, r) => s + r.betragBrutto);

  /// Davon noch nicht bezahlt. Bei [RechnungsAuswahl.offen] gleich [summe].
  double get summeOffen =>
      rechnungen.where(istOffen).fold<double>(0, (s, r) => s + r.betragBrutto);

  int get anzahlOffen => rechnungen.where(istOffen).length;

  /// Ältestes Rechnungsdatum — je weiter zurück, desto dringender.
  DateTime get aeltestes => rechnungen
      .map((r) => r.rechnungsdatum)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  /// OFFENE Rechnungen ohne jeden Zustellnachweis. Das ist KEIN Zahlungsverzug,
  /// sondern der Verdacht auf eine nie gestellte Rechnung — mahnen wäre hier
  /// der falsche Schritt (Lehre aus Blue Cinema: 32 Rechnungen über vier Jahre,
  /// keine einzige je versendet).
  ///
  /// Bezahlte Rechnungen zählen bewusst NICHT mit: Ist das Geld da, ist die
  /// Frage «kam sie an?» beantwortet, auch ohne Stempel. Sonst meldete die
  /// Liste hunderte Tresen-Rechnungen, die längst erledigt sind.
  int get ohneZustellung => rechnungen
      .where(
        (r) => istOffen(r) && r.uebergebenAm == null && r.versendetAm == null,
      )
      .length;
}

/// Bündelt [alle] Rechnungen pro Betrieb.
///
/// [jahr] null bedeutet «alle Jahre». Gefiltert wird über `rechnungsdatum`,
/// nicht über `created_at` — massgebend ist, wann die Leistung verrechnet
/// wurde, nicht wann die Zeile entstand (die Historik-Importe von 2019–2023
/// wurden alle 2026 angelegt).
///
/// Sortiert nach Betrag absteigend: Wer am meisten aussteht bzw. am meisten
/// Umsatz macht, steht oben. Bei gleichem Betrag alphabetisch, damit die
/// Reihenfolge zwischen zwei Aufrufen stabil bleibt.
List<BetriebRechnungen> rechnungenProBetrieb({
  required List<Rechnung> alle,
  required int? jahr,
  required Map<String, String> namen,
  required Map<String, String> orte,
  RechnungsAuswahl auswahl = RechnungsAuswahl.offen,
}) {
  final gruppen = <String, List<Rechnung>>{};
  for (final r in alle) {
    if (auswahl == RechnungsAuswahl.offen && !istOffen(r)) continue;
    if (jahr != null && r.rechnungsdatum.year != jahr) continue;
    gruppen.putIfAbsent(r.betriebId ?? _ohneBetrieb, () => []).add(r);
  }

  final result = <BetriebRechnungen>[];
  for (final eintrag in gruppen.entries) {
    final id = eintrag.key == _ohneBetrieb ? null : eintrag.key;
    final liste = eintrag.value
      ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));
    result.add(
      BetriebRechnungen(
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
