import 'package:flutter/material.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/diagram_components.dart';

class HeigenieDiagram extends StatelessWidget {
  final List<String> highlightKomponenten;

  const HeigenieDiagram({super.key, this.highlightKomponenten = const []});

  @override
  Widget build(BuildContext context) {
    return DiagramContainer(
      label: 'Heigenie-System',
      child: Column(
        children: [
          // Obere Reihe: Gasflasche → Manometer → Tank → Zapfkopf
          Row(
            children: [
              DiagramBox(
                id: 'gasflasche',
                label: 'Gas-\nflasche',
                subtitle: 'Aligal 2/13',
                icon: Icons.propane_tank,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'manometer',
                label: 'Mano-\nmeter',
                icon: Icons.speed,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'tank',
                label: 'Tank',
                icon: Icons.local_drink,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'zapfkopf',
                label: 'Zapf-\nkopf',
                icon: Icons.settings_input_component,
                highlights: highlightKomponenten,
              ),
            ],
          ),
          const DiagramArrowDown(),
          // Mitte: Durchlaufkühler + Leitung-in-Leitung
          DiagramGroup(
            label: 'Leitung-in-Leitung — optimale Kühlung',
            isHighlighted:
                highlightKomponenten.contains('leitung_in_leitung') ||
                    highlightKomponenten.contains('durchlaufkuehler'),
            child: Row(
              children: [
                DiagramBox(
                  id: 'durchlaufkuehler',
                  label: 'Durchlauf-\nkühler',
                  subtitle: 'Mit Pumpe',
                  icon: Icons.kitchen,
                  highlights: highlightKomponenten,
                ),
                const DiagramArrow(),
                DiagramBox(
                  id: 'leitung_in_leitung',
                  label: 'Leitung-in-\nLeitung',
                  subtitle: 'Bier in Kühll.',
                  icon: Icons.circle_outlined,
                  highlights: highlightKomponenten,
                ),
              ],
            ),
          ),
          const DiagramArrowDown(),
          // Untere Reihe: Zapfhahn
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                child: DiagramBox(
                  id: 'zapfhahn',
                  label: 'Heigenie-Hahn',
                  subtitle: 'Kein Kompensator',
                  icon: Icons.water_drop,
                  highlights: highlightKomponenten,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
