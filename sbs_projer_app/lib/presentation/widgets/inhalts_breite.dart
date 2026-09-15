import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Begrenzt die App-Breite am PC auf eine lesbare Spalte (A5).
///
/// WARUM: Die App ist fürs Handy gebaut und läuft produktiv im Browser. Am
/// grossen Bildschirm zog jede Fläche mit — die Startseiten-Kacheln wurden zu
/// leeren Kästen von 950 × 450 Pixeln, Listenzeilen spannten über die ganze
/// Breite, und das Auge musste bei jeder Zeile zurückspringen (App-Analyse
/// 08.09.2026, Befund 4).
///
/// Zentral im `MaterialApp.builder` statt in 101 Screens einzeln: Die
/// Begrenzung gilt damit auch für Dialoge und Sheets, die im selben Navigator
/// liegen — auch die wurden am PC unnötig breit.
///
/// Unterhalb von [maxBreite] ändert sich nichts; auf dem Pixel 9 ist dieses
/// Widget wirkungslos.
class InhaltsBreite extends StatelessWidget {
  final Widget child;

  /// 720 px — schmal genug für ruhige Zeilen, breit genug für die
  /// Buchhaltungs-Tabellen mit Konto, Text und Betrag.
  static const maxBreite = 720.0;

  const InhaltsBreite({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Der Rand neben der Spalte bekommt denselben Grauton wie der
      // Seitenhintergrund — sonst stünde die App als weisse Insel auf Weiss.
      color: AppColors.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxBreite),
          child: child,
        ),
      ),
    );
  }
}
