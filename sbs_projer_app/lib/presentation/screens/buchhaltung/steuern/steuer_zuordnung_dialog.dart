import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/repositories/steuerzahlung_repository.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart'
    show kSteuerJahrAb, steuerartVorschlag;

/// Ergebnis der Dialog-Bedienung (nicht des Speicherns).
enum _Aktion { zuordnen, entfernen }

/// Ordnet eine Steuerbuchung Jahr + Steuerart zu — oder nimmt eine bestehende
/// Zuordnung zurück. Rückgabe true = etwas geändert und gespeichert.
///
/// Ist [b] bereits zugeordnet, sind die Felder mit ihren gespeicherten Werten
/// vorbelegt; sonst kommt der Vorschlag aus [vorschlagJahr] bzw. aus dem
/// Buchungstext. Fehler beim Speichern werden bewusst durchgereicht — die
/// SnackBar zeigt der aufrufende Screen, der auch den passenden Messenger hat.
Future<bool> showSteuerZuordnungDialog(
  BuildContext context,
  Buchung b, {
  int? vorschlagJahr,
}) async {
  final istZugeordnet = b.steuerjahr != null;
  // Steuern werden im Folgejahr bezahlt — ohne plausiblen Vorschlag von aussen
  // ist das Vorjahr der Buchung die wahrscheinlichste Zuordnung.
  int jahr = b.steuerjahr ?? vorschlagJahr ?? b.datum.year - 1;
  String art = b.steuerart ?? steuerartVorschlag(b.beschreibung);
  final df = DateFormat('dd.MM.yyyy');
  final aktion = await showDialog<_Aktion>(
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
              // Nur bei noch nicht zugeordneten Buchungen: dort stammen die
              // Werte aus der Heuristik. Bei einer Korrektur stehen die
              // gespeicherten Werte da, kein Vorschlag.
              if (!istZugeordnet)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Vorschlag aus dem Buchungstext — bitte prüfen',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          if (istZugeordnet)
            TextButton(
              onPressed: () => Navigator.pop(ctx, _Aktion.entfernen),
              child: const Text('Zuordnung entfernen'),
            ),
          TapKnopf(
            text: 'Zuordnen',
            onTap: () => Navigator.pop(ctx, _Aktion.zuordnen),
          ),
        ],
      ),
    ),
  );
  if (aktion == null) return false;
  if (aktion == _Aktion.entfernen) {
    await SteuerzahlungRepository.zuordnungLoeschen(b.id);
    return true;
  }
  await SteuerzahlungRepository.zuordnen(
    b.id,
    steuerjahr: jahr,
    steuerart: art,
  );
  return true;
}
