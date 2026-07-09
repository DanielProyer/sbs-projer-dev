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
  final VoidCallback? onKorrigieren; // optional: „Anders zuordnen"

  const AutoMatchTile({
    super.key,
    required this.betrag,
    required this.beschreibung,
    required this.onVerbuchen,
    this.onKorrigieren,
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
    // GestureDetector statt TextButton: Material-Buttons rendern in CanvasKit
    // auf manchen Screen-Bodies nicht (bekannter Bug).
    final korrigieren = onKorrigieren == null
        ? null
        : GestureDetector(
            onTap: onKorrigieren,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text('Anders zuordnen',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          // Schmal (Smartphone): gestapelt, Buttons rechts darunter.
          if (c.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                betragText,
                const SizedBox(height: 2),
                beschreibungText,
                const SizedBox(height: 8),
                // Ohne Korrigieren-Button exakt wie vorher (nur Button);
                // mit Korrigieren als Wrap (umbricht bei wenig Platz).
                Align(
                  alignment: Alignment.centerRight,
                  child: korrigieren == null
                      ? button
                      : Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [korrigieren, button],
                        ),
                ),
              ],
            );
          }
          // Breit (Desktop): eine Zeile.
          return Row(
            children: [
              betragText,
              const SizedBox(width: 16),
              Expanded(child: beschreibungText),
              const SizedBox(width: 8),
              if (korrigieren != null) korrigieren,
              if (korrigieren != null) const SizedBox(width: 4),
              button,
            ],
          );
        },
      ),
    );
  }
}
