/// Ein Montage-Anlass-Slot: Freitext (wird als material_id gespeichert) + Stunden.
typedef MontageSlot = ({String text, double stunden});

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String _tagLabel(DateTime d) =>
    '${_wochentage[d.weekday - 1]} ${d.day}.${d.month}.';

/// Aggregiert Aufwand-Zeilen pro Tag zu Montage-Anlass-Slots (max 5).
/// [zeilen] = (datum, stunden). Ergebnis nach Datum aufsteigend. Bei > 5 Tagen
/// werden die ersten 4 Tage einzeln ausgewiesen und der Rest in einem
/// Sammel-Slot „Weitere Tage" summiert, damit die Gesamt-Stundenzahl stimmt.
List<MontageSlot> montageSlotsAusAufwand(
    List<({DateTime datum, double stunden})> zeilen) {
  // Pro Kalendertag summieren.
  final proTag = <DateTime, double>{};
  for (final z in zeilen) {
    final tag = DateTime(z.datum.year, z.datum.month, z.datum.day);
    proTag[tag] = (proTag[tag] ?? 0) + z.stunden;
  }
  final tage = proTag.keys.toList()..sort();
  if (tage.isEmpty) return [];

  if (tage.length <= 5) {
    return [for (final t in tage) (text: _tagLabel(t), stunden: proTag[t]!)];
  }

  final slots = <MontageSlot>[
    for (final t in tage.take(4)) (text: _tagLabel(t), stunden: proTag[t]!),
  ];
  var rest = 0.0;
  for (final t in tage.skip(4)) {
    rest += proTag[t]!;
  }
  slots.add((text: 'Weitere Tage', stunden: rest));
  return slots;
}
