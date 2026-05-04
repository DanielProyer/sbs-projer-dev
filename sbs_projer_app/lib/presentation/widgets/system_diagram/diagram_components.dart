import 'package:flutter/material.dart';

/// Einzelne Box im Diagramm (ein Bauteil)
class DiagramBox extends StatelessWidget {
  final String id;
  final String label;
  final String? subtitle;
  final IconData icon;
  final List<String> highlights;

  const DiagramBox({
    super.key,
    required this.id,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    final isHighlighted = highlights.contains(id);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted ? Colors.red.shade700 : Colors.green.shade700,
            width: isHighlighted ? 2.5 : 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isHighlighted ? Colors.red.shade700 : Colors.green.shade800,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                color: isHighlighted ? Colors.red.shade900 : Colors.black87,
                height: 1.2,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  color: isHighlighted
                      ? Colors.red.shade700
                      : Colors.grey.shade600,
                  height: 1.1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Horizontaler Pfeil zwischen Boxen
class DiagramArrow extends StatelessWidget {
  const DiagramArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
    );
  }
}

/// Vertikaler Pfeil nach unten
class DiagramArrowDown extends StatelessWidget {
  const DiagramArrowDown({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
    );
  }
}

/// Gruppierung mit gestricheltem Rahmen (z.B. Kühlung)
class DiagramGroup extends StatelessWidget {
  final String label;
  final bool isHighlighted;
  final Widget child;

  const DiagramGroup({
    super.key,
    required this.label,
    required this.isHighlighted,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? Colors.red.shade300 : Colors.blue.shade200,
          width: isHighlighted ? 2 : 1.5,
        ),
        color: isHighlighted
            ? Colors.red.shade50.withAlpha(80)
            : Colors.blue.shade50.withAlpha(80),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? Colors.red.shade700 : Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Container für das gesamte Diagramm
class DiagramContainer extends StatelessWidget {
  final String label;
  final Widget child;

  const DiagramContainer({
    super.key,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
