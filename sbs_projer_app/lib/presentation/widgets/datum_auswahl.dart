import 'package:flutter/material.dart';

/// EINE Datumsauswahl für die ganze App (Analyse-Runde 4). Grenzen
/// standardmässig 2019 … heute + 2 Jahre; initial wird in die Grenzen
/// geklemmt (sonst wirft showDatePicker). Wächter:
/// test/datumsauswahl_waechter_test.dart.
Future<DateTime?> zeigeDatumsauswahl(
  BuildContext context, {
  required DateTime initial,
  DateTime? erstes,
  DateTime? letztes,
  String? hilfetext,
}) {
  final first = erstes ?? DateTime(2019);
  final last = letztes ?? DateTime.now().add(const Duration(days: 730));
  var init = initial;
  if (init.isBefore(first)) init = first;
  if (init.isAfter(last)) init = last;
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: first,
    lastDate: last,
    helpText: hilfetext,
  );
}

/// Anzeige- und Auswahlfeld für ein Datum (ersetzt die privaten
/// _DatePickerField/_DatumFeld-Kopien). InkWell + InputDecorator —
/// CanvasKit-sicher.
class DatumFeld extends StatelessWidget {
  final String label;
  final DateTime? wert;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? erstes;
  final DateTime? letztes;
  final bool loeschbar;
  const DatumFeld({super.key, required this.label, required this.wert, required this.onChanged,
      this.erstes, this.letztes, this.loeschbar = true});

  static String text(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await zeigeDatumsauswahl(context,
            initial: wert ?? DateTime.now(), erstes: erstes, letztes: letztes);
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: loeschbar && wert != null
              ? InkWell(onTap: () => onChanged(null), child: const Icon(Icons.clear, size: 18))
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(text(wert)),
      ),
    );
  }
}
