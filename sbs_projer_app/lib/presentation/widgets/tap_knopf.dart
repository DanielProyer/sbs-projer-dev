import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Knopf aus GestureDetector + Container: Material-Buttons rendern auf
/// CanvasKit-Web nicht zuverlässig (CLAUDE.md, Vorfälle 20.06./13.08.2026).
class TapKnopf extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool primaer;
  final IconData? icon;

  const TapKnopf({
    super.key,
    required this.text,
    required this.onTap,
    this.primaer = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final farbe = primaer
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    final textFarbe = primaer ? Colors.white : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade400 : farbe,
          borderRadius: BorderRadius.circular(8),
          border: primaer ? null : Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textFarbe),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(color: textFarbe, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
