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

  /// Rote Bestätigung einer unumkehrbaren Aktion (Löschen, Verwerfen).
  ///
  /// WARUM eigens ausgewiesen: Am 20.06.2026 blieb genau so ein
  /// Bestätigen-Knopf auf CanvasKit unsichtbar (camt-Import). Bei einem
  /// Speichern-Knopf merkt man das sofort; bei einer Löschbestätigung steht
  /// man vor einem Dialog, der sich scheinbar nicht bedienen lässt.
  /// `gefahr: true` färbt rot UND hält die Bauart, die zuverlässig rendert —
  /// `test/gefahr_knopf_waechter_test.dart` hält die Regel fest.
  final bool gefahr;

  const TapKnopf({
    super.key,
    required this.text,
    required this.onTap,
    this.primaer = true,
    this.icon,
    this.laeuft = false,
    this.gefahr = false,
  });

  @override
  Widget build(BuildContext context) {
    final farbe = gefahr
        ? AppColors.error
        : primaer
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    final textFarbe = (gefahr || primaer)
        ? Colors.white
        : AppColors.textPrimary;
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
              border: (primaer || gefahr)
                  ? null
                  : Border.all(color: Colors.grey.shade400),
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
                // Flexible, damit der Text umbricht statt überzulaufen:
                // bei vergrösserter Systemschrift oder in einem engen
                // Dialog wurde sonst genau die Beschriftung abgeschnitten,
                // an der man den Knopf erkennt.
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: textFarbe,
                      fontWeight: FontWeight.w600,
                    ),
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
