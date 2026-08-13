/// Ein Montage-Anlass-Slot: Freitext (wird als material_id gespeichert) + Stunden.
typedef MontageSlot = ({String text, double stunden});

/// Kategorien der Zeit-/Spesen-Zeilen (E4) — eine Wahrheit für Formular und
/// Slot-Texte. Die Reihenfolge ist zugleich die Anzeige-Reihenfolge in den
/// generierten Slots.
const kAufwandKategorien = <String, String>{
  'anfahrt': 'Anfahrt',
  'inbetriebnahme': 'Inbetriebnahme',
  'pikett': 'Pikett',
  'spesen': 'Spesen',
};

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String _tagLabel(DateTime d) =>
    '${_wochentage[d.weekday - 1]} ${d.day}.${d.month}.';

/// «8h» / «2.5h» — ohne Nachkomma-Müll.
String _h(double stunden) {
  final ganz = stunden.truncateToDouble();
  return stunden == ganz
      ? '${stunden.toStringAsFixed(0)}h'
      : '${stunden.toStringAsFixed(1)}h';
}

/// Aggregiert Zeit-/Spesen-Zeilen pro Tag zu Montage-Anlass-Slots (max 5).
///
/// Der Slot-Text trägt die DETAILS (Wunsch Daniel 13.08.2026 — vorher stand
/// nur das Datum, Kategorie und Notiz gingen verloren):
///   «Mi 22.7. — Anfahrt 1h · Inbetriebnahme 2h (Augenschein)»
/// Mehrere Zeilen derselben Kategorie am selben Tag werden summiert, ihre
/// Notizen zusammengeführt. Die Slot-Stunden bleiben die Tagessumme — die
/// Abrechnung (Summe × Stundensatz) ändert sich nicht.
///
/// Bei mehr als 5 Tagen: die ersten 4 einzeln, der Rest als Sammel-Slot
/// «Weitere Tage — Pikett 24h · Spesen 2h», damit die Gesamtstundenzahl
/// stimmt und die Verteilung trotzdem erkennbar bleibt.
List<MontageSlot> montageSlotsAusAufwand(
    List<({DateTime datum, double stunden, String kategorie, String? notiz})>
        zeilen) {
  // Pro Tag und Kategorie summieren, Notizen sammeln.
  final proTag =
      <DateTime, Map<String, ({double stunden, List<String> notizen})>>{};
  for (final z in zeilen) {
    final tag = DateTime(z.datum.year, z.datum.month, z.datum.day);
    final kat = proTag.putIfAbsent(tag, () => {});
    final bisher = kat[z.kategorie];
    final notiz = z.notiz?.trim();
    kat[z.kategorie] = (
      stunden: (bisher?.stunden ?? 0) + z.stunden,
      notizen: [
        ...?bisher?.notizen,
        if (notiz != null && notiz.isNotEmpty) notiz,
      ],
    );
  }
  final tage = proTag.keys.toList()..sort();
  if (tage.isEmpty) return [];

  // Feste Kategorie-Reihenfolge; Unbekanntes hinten, roh benannt.
  List<String> sortiert(Iterable<String> kats) {
    final bekannt = kAufwandKategorien.keys.toList();
    final l = kats.toList()
      ..sort((a, b) {
        final ia = bekannt.indexOf(a), ib = bekannt.indexOf(b);
        return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
      });
    return l;
  }

  String label(String kategorie) => kAufwandKategorien[kategorie] ?? kategorie;

  MontageSlot tagesSlot(DateTime t) {
    final kats = proTag[t]!;
    final teile = <String>[];
    var summe = 0.0;
    for (final k in sortiert(kats.keys)) {
      final e = kats[k]!;
      summe += e.stunden;
      final notiz = e.notizen.isEmpty ? '' : ' (${e.notizen.join(', ')})';
      teile.add('${label(k)} ${_h(e.stunden)}$notiz');
    }
    return (text: '${_tagLabel(t)} — ${teile.join(' · ')}', stunden: summe);
  }

  if (tage.length <= 5) {
    return [for (final t in tage) tagesSlot(t)];
  }

  final slots = <MontageSlot>[for (final t in tage.take(4)) tagesSlot(t)];

  // Sammel-Slot: Kategorie-Summen über die restlichen Tage (ohne Notizen —
  // der Platz ist begrenzt, die Verteilung bleibt trotzdem sichtbar).
  final rest = <String, double>{};
  var restSumme = 0.0;
  for (final t in tage.skip(4)) {
    for (final e in proTag[t]!.entries) {
      rest[e.key] = (rest[e.key] ?? 0) + e.value.stunden;
      restSumme += e.value.stunden;
    }
  }
  final restTeile = [
    for (final k in sortiert(rest.keys)) '${label(k)} ${_h(rest[k]!)}',
  ];
  slots.add((
    text: 'Weitere Tage — ${restTeile.join(' · ')}',
    stunden: restSumme,
  ));
  return slots;
}
