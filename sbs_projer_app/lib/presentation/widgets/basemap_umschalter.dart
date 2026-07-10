import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Kompakter Umschalter Luftbild ↔ Karte für eine flutter_map (als Overlay).
class BasemapUmschalter extends StatelessWidget {
  final bool luftbild;
  final ValueChanged<bool> onChanged;

  const BasemapUmschalter({
    super.key,
    required this.luftbild,
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
          _btn(true, Icons.satellite_alt, 'Luftbild'),
          _btn(false, Icons.map, 'Karte'),
        ],
      ),
    );
  }

  Widget _btn(bool value, IconData icon, String tip) {
    final aktiv = luftbild == value;
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: aktiv ? AppColors.primary.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 20,
              color: aktiv ? AppColors.primary : AppColors.textSecondary),
        ),
      ),
    );
  }
}
