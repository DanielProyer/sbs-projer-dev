import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/betrieb_reinigung.dart';

/// Fragt vor dem Eintragen in Google Kalender ab, welche Saison-/Ferien-
/// Reinigungen übernommen werden sollen. Gibt bei Bestätigung die Items
/// (slot_key/art/datum/aktiv) zurück, sonst null.
class SaisonReinigungDialog extends StatefulWidget {
  final List<BetriebReinigung> reinigungen;
  const SaisonReinigungDialog({super.key, required this.reinigungen});

  @override
  State<SaisonReinigungDialog> createState() => _SaisonReinigungDialogState();
}

class _SaisonReinigungDialogState extends State<SaisonReinigungDialog> {
  late final List<bool> _aktiv =
      List<bool>.filled(widget.reinigungen.length, true);

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EE, d. MMM yyyy', 'de_CH');
    return AlertDialog(
      title: const Text('In Google Kalender eintragen?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reinigungs-Termine aus Saison/Ferien:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.reinigungen.length,
                itemBuilder: (_, i) {
                  final r = widget.reinigungen[i];
                  final art =
                      r.art == 'endreinigung' ? 'Endreinigung' : 'Eröffnung';
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _aktiv[i],
                    onChanged: (v) => setState(() => _aktiv[i] = v ?? false),
                    title: Text('$art — ${r.label}'),
                    subtitle: Text(df.format(r.datum)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: () {
            final items = <Map<String, dynamic>>[
              for (var i = 0; i < widget.reinigungen.length; i++)
                {
                  'slot_key': widget.reinigungen[i].slotKey,
                  'art': widget.reinigungen[i].art,
                  'datum': widget.reinigungen[i].datum
                      .toIso8601String()
                      .split('T')
                      .first,
                  'aktiv': _aktiv[i],
                },
            ];
            Navigator.pop(context, items);
          },
          child: const Text('In Google eintragen'),
        ),
      ],
    );
  }
}
