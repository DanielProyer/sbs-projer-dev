import 'package:flutter/material.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Rückfrage vor einer unumkehrbaren Aktion: «Abbrechen» + roter
/// Bestätigen-Knopf, beide als [TapKnopf].
///
/// WARUM TapKnopf: Material-Buttons rendern auf CanvasKit-Web nicht
/// zuverlässig (CLAUDE.md). Bei einer Löschbestätigung stünde man sonst vor
/// einem Dialog, der sich scheinbar nicht bedienen lässt —
/// `test/gefahr_knopf_waechter_test.dart` hält die Regel fest.
///
/// Liefert `true` nur, wenn ausdrücklich bestätigt wurde; Wegtippen neben
/// den Dialog oder «Abbrechen» ergeben `false`.
Future<bool> gefahrRueckfrage(
  BuildContext context, {
  required String titel,
  required String text,
  required String bestaetigen,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titel),
      content: Text(text),
      actions: [
        TapKnopf(
          text: 'Abbrechen',
          primaer: false,
          onTap: () => Navigator.pop(ctx, false),
        ),
        TapKnopf(
          text: bestaetigen,
          gefahr: true,
          onTap: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return ok == true;
}
