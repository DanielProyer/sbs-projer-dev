import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/steuerzahlung_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart'
    show kSteuerJahrAb;

/// Ordnet eine Steuerbuchung Jahr + Steuerart zu. Rückgabe true = gespeichert.
///
/// Fehler beim Speichern werden bewusst durchgereicht — die SnackBar zeigt
/// der aufrufende Screen, der auch den passenden Messenger hat.
Future<bool> showSteuerZuordnungDialog(
  BuildContext context,
  Buchung b, {
  int? vorschlagJahr,
}) async {
  // Steuern werden im Folgejahr bezahlt — ohne Vorschlag ist das Vorjahr die
  // wahrscheinlichste Zuordnung.
  int jahr = vorschlagJahr ?? b.datum.year - 1;
  final t = b.beschreibung.toLowerCase();
  String art = t.contains('eidgen')
      ? 'mwst'
      : (t.contains('busse') ? 'busse' : 'kanton');
  final df = DateFormat('dd.MM.yyyy');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Steuerzahlung zuordnen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${df.format(b.datum)} · '
                '${b.betragBrutto.toStringAsFixed(2)} CHF\n'
                '${b.beschreibung}',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: jahr,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Steuerjahr'),
                items: [
                  for (var j = DateTime.now().year; j >= kSteuerJahrAb; j--)
                    DropdownMenuItem(value: j, child: Text('$j')),
                ],
                onChanged: (v) => setS(() => jahr = v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: art,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Steuerart'),
                items: [
                  for (final e in steuerarten.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setS(() => art = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(text: 'Zuordnen', onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  await SteuerzahlungRepository.zuordnen(
    b.id,
    steuerjahr: jahr,
    steuerart: art,
  );
  return true;
}
