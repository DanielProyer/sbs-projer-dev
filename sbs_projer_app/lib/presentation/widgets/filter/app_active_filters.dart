import 'package:flutter/material.dart';

/// Zeigt aktive Filter als löschbare Chips. Leere Liste -> nichts.
class AppActiveFilters extends StatelessWidget {
  final List<(String, VoidCallback)> chips;
  final EdgeInsetsGeometry padding;
  const AppActiveFilters({
    super.key,
    required this.chips,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 4),
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (label, onRemove) in chips)
            Chip(
              label: Text(label),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: onRemove,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }
}
