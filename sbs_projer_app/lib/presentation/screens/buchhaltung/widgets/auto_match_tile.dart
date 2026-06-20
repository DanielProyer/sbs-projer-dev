import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Eine Auto-Treffer-Zeile im Forderungs-Abgleich.
///
/// Responsiv:
/// - **breit** (Desktop): eine Zeile — Betrag · Beschreibung · Button.
/// - **schmal** (Smartphone, < 460px): Betrag + Beschreibung gestapelt,
///   Button rechts darunter.
///
/// Betrag und Beschreibung sind strikt **einzeilig** (`maxLines: 1` +
/// Ellipsis) — dadurch kann der Text nie mehr buchstabenweise senkrecht
/// umbrechen, egal wie schmal der verfügbare Platz wird.
class AutoMatchTile extends StatelessWidget {
  final String betrag; // z.B. "135.70 CHF"
  final String beschreibung; // z.B. "Hotel Alpina · Rechnung RG-123 · 05.01.2026"
  final VoidCallback onVerbuchen;

  const AutoMatchTile({
    super.key,
    required this.betrag,
    required this.beschreibung,
    required this.onVerbuchen,
  });

  @override
  Widget build(BuildContext context) {
    final betragText = Text(
      betrag,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    );
    final beschreibungText = Text(
      beschreibung,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );
    final button = FilledButton(
      onPressed: onVerbuchen,
      child: const Text('Verbuchen'),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          // Schmal (Smartphone): gestapelt, Button rechts darunter.
          if (c.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                betragText,
                const SizedBox(height: 2),
                beschreibungText,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            );
          }
          // Breit (Desktop): eine Zeile.
          return Row(
            children: [
              betragText,
              const SizedBox(width: 16),
              Expanded(child: beschreibungText),
              const SizedBox(width: 16),
              button,
            ],
          );
        },
      ),
    );
  }
}
