import 'package:flutter/material.dart';
import 'package:sbs_projer_app/presentation/widgets/zeit_auswahl.dart';

/// Nur-lesbares Eingabefeld für eine Uhrzeit, das die gemeinsame
/// Zeitauswahl öffnet. Ausgelagert aus dem Betriebs-Formular (08.09.2026),
/// damit die Servicezeiten-Durchsicht dasselbe Feld nutzt statt einer Kopie.
class ZeitFeld extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  const ZeitFeld({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? '${value!.hour.toString().padLeft(2, '0')}:'
              '${value!.minute.toString().padLeft(2, '0')}'
        : '';
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(null),
              ),
            IconButton(
              icon: const Icon(Icons.access_time, size: 18),
              onPressed: () => _pick(context),
            ),
          ],
        ),
      ),
      controller: TextEditingController(text: text),
      onTap: () => _pick(context),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await zeigeZeitauswahl(
      context,
      initial: value ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) onChanged(picked);
  }
}

/// «08:30» → TimeOfDay. Leer oder unlesbar ergibt null.
TimeOfDay? zeitAusText(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// TimeOfDay → «08:30». null bleibt null.
String? zeitAlsText(TimeOfDay? time) => time == null
    ? null
    : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
