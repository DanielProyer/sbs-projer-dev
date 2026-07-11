import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/filter_chrome.dart';

/// Einheitliche Jahr/Monat-Filterzeile (borderlose Dropdowns + optionaler
/// Trailing-Text rechts, z.B. Anzahl/Summe).
///
/// `selectedMonat == 0` bedeutet "Alle Monate". Der aufrufende Screen stellt
/// sicher, dass `selectedJahr` in `jahre` enthalten ist.
class AppJahrMonatLeiste extends StatelessWidget {
  final List<int> jahre;
  final int selectedJahr;
  final ValueChanged<int> onJahrChanged;
  final int selectedMonat; // 0 = Alle Monate
  final ValueChanged<int> onMonatChanged;

  /// Rechtsbündiger Zusatz (z.B. "12 Reinigungen" oder "12 – 3'400 CHF").
  final Widget? trailing;

  const AppJahrMonatLeiste({
    super.key,
    required this.jahre,
    required this.selectedJahr,
    required this.onJahrChanged,
    required this.selectedMonat,
    required this.onMonatChanged,
    this.trailing,
  });

  static const monatNamen = [
    '',
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        );
    // Absicherung: value muss in items sein (Screen garantiert das i.d.R.).
    final jahrValue = jahre.contains(selectedJahr)
        ? selectedJahr
        : (jahre.isNotEmpty ? jahre.first : selectedJahr);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          FilterChrome(
            child: DropdownButton<int>(
              value: jahrValue,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: style,
              items: [
                for (final y in jahre)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (y) {
                if (y != null) onJahrChanged(y);
              },
            ),
          ),
          const SizedBox(width: 8),
          FilterChrome(
            child: DropdownButton<int>(
              value: selectedMonat,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: style,
              items: [
                const DropdownMenuItem(value: 0, child: Text('Alle Monate')),
                for (int m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(monatNamen[m])),
              ],
              onChanged: (m) {
                if (m != null) onMonatChanged(m);
              },
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
