import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/bestand_buchung.dart';
import 'package:sbs_projer_app/data/models/material_bestellung.dart';

/// Kontroll-Dialog „Material abgeholt": Positionen nach Kategorie gruppiert,
/// Mengen mit der Bestellmenge vorbefüllt und korrigierbar, Zeilen abwählbar.
///
/// Liefert das RPC-Payload (positionId → Menge) oder null bei Abbruch.
Future<Map<String, double>?> zeigeAbholDialog(
  BuildContext context, {
  required MaterialBestellung bestellung,
  required List<MaterialBestellposition> positionen,
}) {
  return showDialog<Map<String, double>>(
    context: context,
    builder: (_) => _AbholDialog(bestellung: bestellung, positionen: positionen),
  );
}

class _AbholDialog extends StatefulWidget {
  final MaterialBestellung bestellung;
  final List<MaterialBestellposition> positionen;
  const _AbholDialog({required this.bestellung, required this.positionen});

  @override
  State<_AbholDialog> createState() => _AbholDialogState();
}

class _AbholDialogState extends State<_AbholDialog> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  final _gewaehlt = <String>{};
  final _controller = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final p in widget.positionen) {
      if (!istBuchbar(p)) continue;
      _gewaehlt.add(p.id); // default: erhalten
      _controller[p.id] =
          TextEditingController(text: p.menge.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (final c in _controller.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double> get _payload {
    final mengen = <String, double>{};
    for (final id in _gewaehlt) {
      final val = double.tryParse(_controller[id]?.text ?? '');
      if (val != null) mengen[id] = val;
    }
    return abholPayload(positionen: widget.positionen, mengen: mengen);
  }

  @override
  Widget build(BuildContext context) {
    final gruppen = positionenNachKategorie(widget.positionen);
    final anzahl = _payload.length;
    return AlertDialog(
      title: Text('Material abgeholt — ${widget.bestellung.bestellNr}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bestellung vom ${_dateFormat.format(widget.bestellung.datum)} — '
                'Mengen prüfen, dann buchen.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final g in gruppen) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(g.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ),
                for (final p in g.positionen) _zeile(p),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed:
              anzahl == 0 ? null : () => Navigator.pop(context, _payload),
          child: Text('Bestände buchen ($anzahl)'),
        ),
      ],
    );
  }

  Widget _zeile(MaterialBestellposition p) {
    final buchbar = istBuchbar(p);
    final nr = p.sapNr ?? p.dboNr;
    if (!buchbar) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  const Text('kein Lager-Bezug — wird nicht gebucht',
                      style: TextStyle(
                          fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _gewaehlt.contains(p.id),
      onChanged: (sel) => setState(() {
        if (sel == true) {
          _gewaehlt.add(p.id);
        } else {
          _gewaehlt.remove(p.id);
        }
      }),
      title: Text(nr != null ? '$nr – ${p.name}' : p.name,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text('bestellt: ${p.menge.toStringAsFixed(0)} ${p.einheit}',
          style: const TextStyle(fontSize: 11)),
      secondary: Builder(builder: (_) {
        final ungueltig = _gewaehlt.contains(p.id) &&
            (double.tryParse(_controller[p.id]?.text ?? '') ?? 0) <= 0;
        return SizedBox(
          width: 64,
          height: 40,
          child: TextFormField(
            controller: _controller[p.id],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: ungueltig ? AppColors.error : null),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: ungueltig ? AppColors.error : Colors.grey,
                    width: ungueltig ? 2 : 1),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        );
      }),
    );
  }
}
