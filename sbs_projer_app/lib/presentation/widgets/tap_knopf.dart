import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Knopf aus GestureDetector + Container: Material-Buttons rendern auf
/// CanvasKit-Web nicht zuverlässig (CLAUDE.md, Vorfälle 20.06./13.08.2026).
///
/// [laeuft] zeigt einen kleinen Fortschrittskreis vor dem Text und sperrt
/// den Knopf — so bleibt die Beschriftung stehen, statt zu «Lädt…» zu
/// wechseln und die Knopfbreite springen zu lassen.
class TapKnopf extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool primaer;
  final IconData? icon;
  final bool laeuft;

  const TapKnopf({
    super.key,
    required this.text,
    required this.onTap,
    this.primaer = true,
    this.icon,
    this.laeuft = false,
  });

  @override
  Widget build(BuildContext context) {
    final farbe = primaer
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    final textFarbe = primaer ? Colors.white : AppColors.textPrimary;
    final aktiv = onTap != null && !laeuft;
    return Semantics(
      button: true,
      enabled: aktiv,
      label: text,
      child: MouseRegion(
        cursor: aktiv ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: aktiv ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: aktiv ? farbe : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
              border: primaer ? null : Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (laeuft) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textFarbe,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(icon, size: 18, color: textFarbe),
                  const SizedBox(width: 6),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: textFarbe,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
