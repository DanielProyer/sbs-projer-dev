import 'package:flutter/material.dart';

/// Standardisiertes Multi-Select-Bottom-Sheet. Gibt die neue Auswahl zurück
/// oder null bei Abbruch (Sheet weggewischt).
Future<Set<T>?> showAppFilterSheet<T>({
  required BuildContext context,
  required String titel,
  required List<(T, String)> options,
  required Set<T> selected,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final sel = Set<T>.from(selected);
      return StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(titel, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (v, label) in options)
                      CheckboxListTile(
                        dense: true,
                        value: sel.contains(v),
                        title: Text(label),
                        onChanged: (b) => setSheet(() {
                          if (b == true) {
                            sel.add(v);
                          } else {
                            sel.remove(v);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (sel.isNotEmpty)
                      TextButton(
                        onPressed: () => setSheet(sel.clear),
                        child: const Text('Zurücksetzen'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, sel),
                      child: const Text('Anwenden'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
