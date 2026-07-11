import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Dezente, app-weit einheitliche Umrahmung für Filter-Bedienelemente:
/// weisse Füllung + grauer Rahmen (wie Cards/Inputs), abgerundet. Hebt Filter
/// vom hellgrauen Seitenhintergrund ab, damit sie schnell als Bedienelement
/// erkennbar sind.
///
/// Beispiel: `FilterChrome(child: DropdownButton(...))`.
class FilterChrome extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FilterChrome({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
  });

  /// Gemeinsame Rahmen-Optik, auch für Widgets, die den Rahmen selbst setzen
  /// (z.B. `TextButton.styleFrom(side: FilterChrome.side)`).
  static const BorderSide side = BorderSide(color: AppColors.filterBorder);
  static final BorderRadius radius = BorderRadius.circular(8);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: radius,
        border: Border.all(color: AppColors.filterBorder),
      ),
      child: child,
    );
  }
}
