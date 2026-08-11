import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// «Beenden» im laufenden Zeit-Band von Montage und Störung.
///
/// Bis 11.08.2026 gab es diesen Knopf nicht: Nach «Arbeit beginnen» stand dort
/// nur ein grünes Band ohne Aktion, und der einzige Weg zum Abschluss war der
/// Schalter «Erst geplant» — dessen Beschriftung nichts mit «fertig» zu tun
/// hat. Die Montage Sartons stand deshalb acht Tage lang im Tourenplan,
/// obwohl der Rapport längst vollständig war.
///
/// Bewusst `GestureDetector` statt `FilledButton`: Material-Buttons rendern
/// auf manchen CanvasKit-Screens nicht zuverlässig (Vorfall 20.06.2026) — und
/// gerade dieser Knopf darf nicht unsichtbar sein.
class ArbeitBeendenKnopf extends StatelessWidget {
  final VoidCallback onTap;

  /// Blockiert den Knopf, solange ein Speichervorgang läuft.
  final bool laeuft;

  const ArbeitBeendenKnopf({
    super.key,
    required this.onTap,
    required this.laeuft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: laeuft ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_circle_outlined, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Beenden',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
