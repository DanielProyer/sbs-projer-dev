import 'package:flutter/material.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/diagram_components.dart';

class DavidDiagram extends StatelessWidget {
  final List<String> highlightKomponenten;

  const DavidDiagram({super.key, this.highlightKomponenten = const []});

  @override
  Widget build(BuildContext context) {
    return DiagramContainer(
      label: 'David-System',
      child: Column(
        children: [
          // Obere Reihe: Gasflasche → Manometer → Tank
          Row(
            children: [
              DiagramBox(
                id: 'gasflasche',
                label: 'Gasflasche',
                subtitle: 'Aligal 2',
                icon: Icons.propane_tank,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'manometer',
                label: 'Manometer',
                subtitle: '0.45–0.50 Bar',
                icon: Icons.speed,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'tank',
                label: 'Tank (20l)',
                subtitle: '×2, 8h Kühlzeit',
                icon: Icons.local_drink,
                highlights: highlightKomponenten,
              ),
            ],
          ),
          const DiagramArrowDown(),
          // Kühlung umrahmt Tank → Schlauchführung
          DiagramGroup(
            label: 'Kühlung (David) — 1.5–3.0 °C',
            isHighlighted: highlightKomponenten.contains('kuehlung'),
            child: Row(
              children: [
                DiagramBox(
                  id: 'schlauchfuehrung',
                  label: 'Schlauch-\nführung',
                  icon: Icons.linear_scale,
                  highlights: highlightKomponenten,
                ),
                const DiagramArrow(),
                DiagramBox(
                  id: 'plastikleitung',
                  label: 'Plastik-\nleitung',
                  icon: Icons.timeline,
                  highlights: highlightKomponenten,
                ),
              ],
            ),
          ),
          const DiagramArrowDown(),
          // Untere Reihe: Säule → Zapfhahn
          Row(
            children: [
              DiagramBox(
                id: 'saeule',
                label: 'Säule',
                icon: Icons.vertical_align_top,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'zapfhahn',
                label: 'Zapfhahn',
                subtitle: 'Kein Kompensator',
                icon: Icons.water_drop,
                highlights: highlightKomponenten,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
