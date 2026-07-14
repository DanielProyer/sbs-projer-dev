import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/filter_chrome.dart';

/// Einheitliche Jahr-Filterzeile (borderloses Dropdown + optionaler
/// Trailing-Text rechts, z.B. Anzahl/Summe). Wie [AppJahrMonatLeiste], aber
/// nur mit Jahr-Auswahl.
///
/// Der aufrufende Screen stellt sicher, dass `selectedJahr` in `jahre`
/// enthalten ist.
class AppJahrLeiste extends StatelessWidget {
  final List<int> jahre;
  final int selectedJahr;
  final ValueChanged<int> onJahrChanged;

  /// Rechtsbündiger Zusatz (z.B. "12 Rechnungen" oder "12 – 3'400 CHF").
  final Widget? trailing;

  const AppJahrLeiste({
    super.key,
    required this.jahre,
    required this.selectedJahr,
    required this.onJahrChanged,
    this.trailing,
  });

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
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
