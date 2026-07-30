import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/swisstopo.dart';

/// Kompakter Umschalter der Kartenhintergründe für eine flutter_map
/// (als Overlay). Seit 30.07.2026 drei statt zwei: OpenStreetMap (Standard),
/// swisstopo-Landeskarte, swisstopo-Luftbild.
class BasemapUmschalter extends StatelessWidget {
  final Basemap aktiv;
  final ValueChanged<Basemap> onChanged;

  const BasemapUmschalter({
    super.key,
    required this.aktiv,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: AppColors.surface,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Basemap.osm, Icons.public, 'OpenStreetMap'),
          _btn(Basemap.karte, Icons.map, 'Landeskarte'),
          _btn(Basemap.luftbild, Icons.satellite_alt, 'Luftbild'),
        ],
      ),
    );
  }

  Widget _btn(Basemap wert, IconData icon, String tip) {
    final istAktiv = aktiv == wert;
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: () => onChanged(wert),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: istAktiv
                ? AppColors.primary.withAlpha(30)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: istAktiv ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
