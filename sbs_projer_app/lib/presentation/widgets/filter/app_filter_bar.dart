import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Ein Element der [AppFilterBar].
abstract class AppFilterItem {
  Widget build(BuildContext context);
}

/// Randloser Auswahl-Dropdown im 'Alle …'-Stil.
class AppFilterDropdown<T> extends AppFilterItem {
  final String hint;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;
  final bool nullable;
  AppFilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.nullable = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        );
    return DropdownButton<T?>(
      value: value,
      hint: Text(hint, style: style),
      isDense: true,
      underline: const SizedBox.shrink(),
      style: style,
      borderRadius: BorderRadius.circular(8),
      items: [
        if (nullable)
          DropdownMenuItem<T?>(value: null, child: Text(hint, style: style)),
        for (final (v, label) in options)
          DropdownMenuItem<T?>(value: v, child: Text(label, style: style)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Binärer An/Aus-Filter als schlichter FilterChip.
class AppFilterToggle extends AppFilterItem {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  AppFilterToggle(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Öffnet ein Multi-Select-Sheet; Label zeigt die Auswahl (z.B. 'Regionen (3)').
class AppFilterSheetButton extends AppFilterItem {
  final String label;
  final VoidCallback onTap;
  AppFilterSheetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.filter_list, size: 16),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Eine Option einer [AppMultiToggleChips]-Gruppe (optional farbig).
class AppMultiOption<T> {
  final T value;
  final String label;
  final Color? color;
  const AppMultiOption(this.value, this.label, {this.color});
}

/// Gruppe von Mehrfach-Auswahl-Chips (optional farbig), im Wrap. Für
/// Filter mit mehreren gleichzeitig aktivierbaren Werten (z.B. Fälligkeit).
class AppMultiToggleChips<T> extends StatelessWidget {
  final List<AppMultiOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final double spacing;
  const AppMultiToggleChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 4,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(
              o.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: o.color != null && selected.contains(o.value)
                    ? o.color
                    : null,
              ),
            ),
            selected: selected.contains(o.value),
            showCheckmark: false,
            selectedColor: o.color?.withAlpha(30),
            side: o.color != null
                ? BorderSide(
                    color: selected.contains(o.value)
                        ? o.color!.withAlpha(120)
                        : Colors.transparent)
                : null,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (v) {
              final updated = Set<T>.from(selected);
              if (v) {
                updated.add(o.value);
              } else {
                updated.remove(o.value);
              }
              onChanged(updated);
            },
          ),
      ],
    );
  }
}

/// Einheitliche Filter-Leiste (unter der SearchBar).
class AppFilterBar extends StatelessWidget {
  final List<AppFilterItem> items;
  final EdgeInsetsGeometry padding;
  const AppFilterBar({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [for (final i in items) i.build(context)],
      ),
    );
  }
}
