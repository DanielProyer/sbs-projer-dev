import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Fälligkeits-Filter der Tourenplanung: fünf Knöpfe auf einer Zeile.
///
/// Bewusst eine [Row] mit [Expanded] statt eines umbrechenden `Wrap`: Daniel
/// will die Leiste einzeilig (29.07.2026), auch auf schmalen Handys. Die
/// Labels schrumpfen im Notfall über [FittedBox], statt umzubrechen.
class TourFilterLeiste extends StatelessWidget {
  final Set<TourFilter> ausgewaehlt;
  final ValueChanged<Set<TourFilter>> onChanged;

  const TourFilterLeiste({
    super.key,
    required this.ausgewaehlt,
    required this.onChanged,
  });

  static Color _farbe(TourFilter f) => switch (f) {
        TourFilter.ueberfaellig =>
          faelligkeitFarbe(FaelligkeitsStatus.ueberfaellig),
        TourFilter.faellig => faelligkeitFarbe(FaelligkeitsStatus.faellig),
        TourFilter.bald => faelligkeitFarbe(FaelligkeitsStatus.baldFaellig),
        TourFilter.saison =>
          faelligkeitFarbe(FaelligkeitsStatus.eroeffnungFaellig),
        TourFilter.alle => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      // Flexible statt Expanded: jeder Knopf nimmt nur die Breite, die sein
      // Label braucht — sonst staucht das lange «Überfällig», während «Alle»
      // Platz verschenkt. Die Obergrenze pro Knopf bleibt ein Fünftel der
      // Zeile, damit auch bei grosser Systemschrift nichts überläuft.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final f in TourFilter.values) ...[
            if (f != TourFilter.values.first) const SizedBox(width: 4),
            Flexible(fit: FlexFit.loose, child: _chip(f)),
          ],
        ],
      ),
    );
  }

  Widget _chip(TourFilter f) {
    final aktiv = ausgewaehlt.contains(f);
    final farbe = _farbe(f);
    // GestureDetector statt FilterChip: Material-Buttons rendern unter
    // CanvasKit nicht zuverlässig.
    return GestureDetector(
      onTap: () => onChanged(nachTipp(ausgewaehlt, f)),
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: aktiv ? farbe.withAlpha(45) : Colors.transparent,
          border: Border.all(
            color: aktiv ? farbe : AppColors.divider,
            width: aktiv ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            tourFilterLabel(f),
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: aktiv ? farbe : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
