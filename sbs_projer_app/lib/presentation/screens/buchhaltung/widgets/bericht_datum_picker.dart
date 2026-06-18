// lib/presentation/screens/buchhaltung/widgets/bericht_datum_picker.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';

final _df = DateFormat('dd.MM.yyyy');
DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Stichtag-Auswahl für die Bilanz: Geschäftsjahr-Dropdown (je 31.12.) +
/// „Heute" + freie Datumswahl.
class StichtagPicker extends StatelessWidget {
  final DateTime stichtag;
  final ValueChanged<DateTime> onChanged;
  const StichtagPicker({super.key, required this.stichtag, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    // Dropdown zeigt das Jahr nur, wenn der Stichtag exakt auf den 31.12. fällt.
    final jahr31 =
        (stichtag.month == 12 && stichtag.day == 31) ? stichtag.year : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<int>(
            value: jahr31,
            hint: const Text('Geschäftsjahr'),
            items: [
              for (int y = jetzt.year; y >= 2019; y--)
                DropdownMenuItem(value: y, child: Text('Geschäftsjahr $y')),
            ],
            onChanged: (y) {
              if (y != null) onChanged(DateTime(y, 12, 31));
            },
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

/// Zeitraum-Auswahl für die Erfolgsrechnung: Geschäftsjahr-Dropdown +
/// Quartal-Dropdown (Q1–Q4, ohne Auswahl = ganzes Jahr) + freie von/bis-Wahl.
class ZeitraumPicker extends StatelessWidget {
  final Zeitraum zeitraum;
  final ValueChanged<Zeitraum> onChanged;
  const ZeitraumPicker({super.key, required this.zeitraum, required this.onChanged});

  Zeitraum _ganzesJahr(int j) => (von: DateTime(j, 1, 1), bis: DateTime(j, 12, 31));
  Zeitraum _quartal(int j, int q) =>
      (von: DateTime(j, (q - 1) * 3 + 1, 1), bis: DateTime(j, q * 3 + 1, 0));

  @override
  Widget build(BuildContext context) {
    final jetzt = DateTime.now();
    final jahr = zeitraum.von.year;

    // Auswahl im Dropdown: 0 = Ganzes Jahr, 1–4 = Quartal, null = eigener
    // Zeitraum (über die freie Datumswahl gesetzt).
    int? auswahl;
    if (zeitraum.von == _ganzesJahr(jahr).von && zeitraum.bis == _ganzesJahr(jahr).bis) {
      auswahl = 0;
    } else {
      for (int i = 1; i <= 4; i++) {
        final qz = _quartal(jahr, i);
        if (zeitraum.von == qz.von && zeitraum.bis == qz.bis) {
          auswahl = i;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<int>(
            value: jahr,
            items: [
              for (int y = jetzt.year; y >= 2019; y--)
                DropdownMenuItem(value: y, child: Text('Geschäftsjahr $y')),
            ],
            onChanged: (y) {
              if (y == null) return;
              // Quartals-/Ganzes-Jahr-Auswahl beibehalten (schneller Jahresvergleich);
              // bei eigenem Zeitraum (null) auf ganzes Jahr fallen.
              onChanged(auswahl == null || auswahl == 0
                  ? _ganzesJahr(y)
                  : _quartal(y, auswahl));
            },
          ),
          DropdownButton<int>(
            value: auswahl,
            hint: const Text('Eigener Zeitraum'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Ganzes Jahr')),
              DropdownMenuItem(value: 1, child: Text('Q1')),
              DropdownMenuItem(value: 2, child: Text('Q2')),
              DropdownMenuItem(value: 3, child: Text('Q3')),
              DropdownMenuItem(value: 4, child: Text('Q4')),
            ],
            onChanged: (q) {
              if (q == null) return;
              onChanged(q == 0 ? _ganzesJahr(jahr) : _quartal(jahr, q));
            },
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
