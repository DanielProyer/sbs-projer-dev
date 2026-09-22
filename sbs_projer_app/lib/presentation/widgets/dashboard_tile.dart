import 'package:flutter/material.dart';

/// Kachel mit Symbol, optionalem Zähler und Beschriftung — bis v0.130.0 auf
/// der Startseite, seit v0.131.0 in der Gruppe «Unterwegs» der Mehr-Seite.
class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;
  final Color color;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Zähler oben neben dem Symbol, Name darunter über die ganze
              // Kachelbreite.
              //
              // WARUM: Solange beide in einer Zeile standen, teilten sie sich
              // die halbe Kachelbreite — und «Reinigungen» wurde zu
              // «Reinigung…» gekürzt, selbst wenn im Chip nur «87» stand
              // (im Browser geprüft, 15.09.2026). Der Zählertext war also gar
              // nicht die Ursache; kürzen allein hätte den Namen nicht
              // gerettet. Oben ist neben dem 20-px-Symbol reichlich Platz.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (count != null) ...[
                    const SizedBox(width: 4),
                    // Flexible ist hier zwingend, nicht nur Kosmetik: ohne
                    // sie bekommt der Container im Row keinerlei Breiten-
                    // grenze und maxLines/overflow am Text greifen nie — das
                    // Ergebnis ist ein RenderFlex-Overflow, kein Ellipsis
                    // (mit einer Probe verifiziert, 13.09.2026). Die neuen
                    // Zähler-Texte ("12 diese Woche") sind deutlich länger
                    // als die alten reinen Zahlen und laufen bei 360 px
                    // (Pixel 9, 2 Spalten) sonst über die Kachel hinaus —
                    // Schriftgrösse bleibt 11 px (Lesbarkeits-Untergrenze),
                    // stattdessen kürzt hier die Ellipse.
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count!,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
