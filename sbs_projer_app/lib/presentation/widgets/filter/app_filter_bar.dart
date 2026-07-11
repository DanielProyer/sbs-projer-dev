import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/filter_chrome.dart';

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

  /// Füllt die verfügbare Breite (für gleich breite Spalten in einer Row).
  final bool isExpanded;
  AppFilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.nullable = true,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        );
    final overflow = isExpanded ? TextOverflow.ellipsis : null;
    return FilterChrome(
      child: DropdownButton<T?>(
        value: value,
        hint: Text(hint, style: style, overflow: overflow),
        isDense: true,
        isExpanded: isExpanded,
        underline: const SizedBox.shrink(),
        style: style,
        borderRadius: BorderRadius.circular(8),
        items: [
          if (nullable)
            DropdownMenuItem<T?>(
                value: null,
                child: Text(hint, style: style, overflow: overflow)),
          for (final (v, label) in options)
            DropdownMenuItem<T?>(
                value: v, child: Text(label, style: style, overflow: overflow)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Mehrfach-Auswahl-Dropdown (kompakt, einhändig): zeigt 'Alle …' bzw.
/// '… (n)' und öffnet ein Checkbox-Menü, das beim Mehrfach-Tippen offen bleibt.
/// Vertikales Scrollen im Menü ist ok; horizontales Chip-Scrollen wird vermieden.
class AppFilterMultiDropdown<T> extends AppFilterItem {
  final String label; // z.B. 'Regionen'
  final List<(T, String)> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  AppFilterMultiDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  String _kurz(T v) =>
      options.firstWhere((o) => o.$1 == v, orElse: () => (v, label)).$2;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        );
    final anzeige = selected.isEmpty
        ? 'Alle $label'
        : selected.length == 1
            ? _kurz(selected.first)
            : '$label (${selected.length})';
    return MenuAnchor(
      menuChildren: [
        for (final (v, l) in options)
          MenuItemButton(
            closeOnActivate: false,
            leadingIcon: Icon(
              selected.contains(v)
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 20,
              color: selected.contains(v) ? AppColors.primary : null,
            ),
            onPressed: () {
              final u = Set<T>.from(selected);
              if (!u.add(v)) u.remove(v);
              onChanged(u);
            },
            child: Text(l),
          ),
      ],
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Text(anzeige, style: style),
        label: const Icon(Icons.arrow_drop_down, size: 20),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          visualDensity: VisualDensity.compact,
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surfaceCard,
          side: FilterChrome.side,
          shape: RoundedRectangleBorder(borderRadius: FilterChrome.radius),
        ),
      ),
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

  /// Verteilung der Chips innerhalb der Zeile. `spaceBetween` verteilt den
  /// freien Platz gleichmässig (bricht bei Bedarf trotzdem um).
  final WrapAlignment alignment;
  const AppMultiToggleChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.spacing = 6,
    this.alignment = WrapAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 4,
      alignment: alignment,
      children: [for (final o in options) _chip(o)],
    );
  }

  Widget _chip(AppMultiOption<T> o) {
    final istAktiv = selected.contains(o.value);
    final farbe = o.color ?? AppColors.primary;
    return FilterChip(
      label: Text(
        o.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          // Aktiv: kräftige Kategorie-Farbe. Inaktiv: neutral grau.
          color: istAktiv ? farbe : AppColors.textSecondary,
        ),
      ),
      selected: istAktiv,
      showCheckmark: false,
      // Aktiv: farbige Tönung als Füllung. Inaktiv: keine Füllung.
      selectedColor: farbe.withAlpha(45),
      // Aktiv: kräftiger farbiger Rand (1.5px). Inaktiv: dezenter grauer Rand.
      side: BorderSide(
        color: istAktiv ? farbe : AppColors.divider,
        width: istAktiv ? 1.5 : 1.0,
      ),
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
