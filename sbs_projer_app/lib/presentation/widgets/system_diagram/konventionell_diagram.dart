import 'package:flutter/material.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/diagram_components.dart';

class KonventionellDiagram extends StatelessWidget {
  final List<String> highlightKomponenten;

  const KonventionellDiagram({super.key, this.highlightKomponenten = const []});

  @override
  Widget build(BuildContext context) {
    return DiagramContainer(
      label: 'Konventionelles System',
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
          // Optional: Fasskühler / Backpython
          Row(
            children: [
              DiagramBox(
                id: 'fasskuehler',
                label: 'Fass-\nkühler',
                subtitle: 'Kaltanstich',
                icon: Icons.ac_unit,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'backpython',
                label: 'Back-\npython',
                subtitle: 'Optional',
                icon: Icons.swap_vert,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'durchlaufkuehler',
                label: 'Durchlauf-\nkühler',
                icon: Icons.kitchen,
                highlights: highlightKomponenten,
              ),
            ],
          ),
          const DiagramArrowDown(),
          // Untere Reihe: Python → Säule → Zapfhahn
          Row(
            children: [
              DiagramBox(
                id: 'python',
                label: 'Python',
                subtitle: 'Begleitkühlung',
                icon: Icons.cable,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'saeule',
                label: 'Säule',
                subtitle: 'Div. Typen',
                icon: Icons.vertical_align_top,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'zapfhahn',
                label: 'Zapf-\nhahn',
                subtitle: 'Kompensator',
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
