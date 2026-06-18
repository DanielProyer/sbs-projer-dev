// lib/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';

final _df = DateFormat('dd.MM.yyyy');
DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);
const _monatNamen = ['', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];

/// Stichtag-Auswahl für die Bilanz: Presets + freie Datumswahl.
class StichtagPicker extends StatelessWidget {
  final DateTime stichtag;
  final ValueChanged<DateTime> onChanged;
  const StichtagPicker({super.key, required this.stichtag, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            label: Text('Per 31.12.${jetzt.year - 1}'),
            onPressed: () => onChanged(DateTime(jetzt.year - 1, 12, 31)),
          ),
          ActionChip(
            label: const Text('Heute'),
            onPressed: () => onChanged(_d(jetzt)),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_df.format(stichtag)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: stichtag,
                firstDate: DateTime(2019, 1, 1),
                lastDate: jetzt,
              );
              if (picked != null) onChanged(_d(picked));
            },
          ),
        ],
      ),
    );
  }
}

/// Zeitraum-Auswahl für die Erfolgsrechnung: Presets + freie von/bis-Wahl.
class ZeitraumPicker extends StatelessWidget {
  final Zeitraum zeitraum;
  final ValueChanged<Zeitraum> onChanged;
  const ZeitraumPicker({super.key, required this.zeitraum, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    final j = zeitraum.von.year;
    final q = ((zeitraum.von.month - 1) ~/ 3) + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            label: Text('Geschäftsjahr $j'),
            onPressed: () => onChanged((von: DateTime(j, 1, 1), bis: DateTime(j, 12, 31))),
          ),
          ActionChip(
            label: Text('Q$q $j'),
            onPressed: () {
              final start = DateTime(j, (q - 1) * 3 + 1, 1);
              final end = DateTime(j, q * 3 + 1, 0);
              onChanged((von: start, bis: end));
            },
          ),
          ActionChip(
            label: Text('${_monatNamen[zeitraum.von.month]} $j'),
            onPressed: () {
              final start = DateTime(j, zeitraum.von.month, 1);
              final end = DateTime(j, zeitraum.von.month + 1, 0);
              onChanged((von: start, bis: end));
            },
          ),
          ActionChip(
            label: const Text('YTD'),
            onPressed: () => onChanged((von: DateTime(jetzt.year, 1, 1), bis: _d(jetzt))),
          ),
          OutlinedButton(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(start: zeitraum.von, end: zeitraum.bis),
                firstDate: DateTime(2019, 1, 1),
                lastDate: jetzt,
              );
              if (picked != null) {
                onChanged((von: _d(picked.start), bis: _d(picked.end)));
              }
            },
            child: Text('${_df.format(zeitraum.von)} – ${_df.format(zeitraum.bis)}'),
          ),
        ],
      ),
    );
  }
}
