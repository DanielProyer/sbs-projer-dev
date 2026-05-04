import 'package:flutter/material.dart';
import 'package:sbs_projer_app/presentation/widgets/system_diagram/diagram_components.dart';

class OrionDiagram extends StatelessWidget {
  final List<String> highlightKomponenten;

  const OrionDiagram({super.key, this.highlightKomponenten = const []});

  @override
  Widget build(BuildContext context) {
    return DiagramContainer(
      label: 'Orion-System',
      child: Column(
        children: [
          // Obere Reihe: Grosstank + Kühlung + Kompressor
          Row(
            children: [
              DiagramBox(
                id: 'grosstank',
                label: 'Grosstank',
                subtitle: '500/1000l',
                icon: Icons.storage,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'kuehlung',
                label: 'Kühlung',
                subtitle: 'Kühlzelle/passiv',
                icon: Icons.ac_unit,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'kompressor',
                label: 'Kompressor',
                subtitle: 'Druckgas',
                icon: Icons.air,
                highlights: highlightKomponenten,
              ),
            ],
          ),
          const DiagramArrowDown(),
          // Mitte: Füllstandsmessung + Durchlaufkühler
          Row(
            children: [
              DiagramBox(
                id: 'fuellstandsmessung',
                label: 'Füllstands-\nmessung',
                subtitle: 'Elektronisch',
                icon: Icons.sensors,
                highlights: highlightKomponenten,
              ),
              const SizedBox(width: 20),
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
                icon: Icons.vertical_align_top,
                highlights: highlightKomponenten,
              ),
              const DiagramArrow(),
              DiagramBox(
                id: 'zapfhahn',
                label: 'Zapfhahn',
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
