import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Karte für einen Abschnitt auf einem Detail-Screen: Icon + Titel im Kopf,
/// darunter die `kinder` (meist `InfoZeile`n). Rendert nichts, wenn `kinder`
/// leer ist.
///
/// Ersetzt die textgleiche private `_SectionCard`, die vorher in 11 Dateien
/// kopiert war (Vorlage: `anlage_detail_screen.dart`).
class DetailKarte extends StatelessWidget {
  final String titel;
  final IconData icon;
  final List<Widget> kinder;
  final Widget? aktion;

  const DetailKarte({
    super.key,
    required this.titel,
    required this.icon,
    required this.kinder,
    this.aktion,
  });

  @override
  Widget build(BuildContext context) {
    if (kinder.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (aktion != null) aktion!,
              ],
            ),
            const SizedBox(height: 12),
            ...kinder,
          ],
        ),
      ),
    );
  }
}

/// Eine Label/Wert-Zeile innerhalb einer `DetailKarte`. Ist `label` leer,
/// wird nur `wert` gezeigt (z. B. für Freitext-Absätze).
///
/// Ersetzt die textgleiche private `_InfoRow`, die vorher in 13 Dateien
/// kopiert war (Vorlage: `anlage_detail_screen.dart`).
class InfoZeile extends StatelessWidget {
  final String label;
  final String wert;
  final double labelBreite;

  const InfoZeile(this.label, this.wert, {super.key, this.labelBreite = 130});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(wert, style: const TextStyle(fontSize: 14)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelBreite,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(wert, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
