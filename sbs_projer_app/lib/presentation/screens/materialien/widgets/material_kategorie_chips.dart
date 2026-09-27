import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/material_filter.dart';

/// Chip-Zeile des Material-Screens: «Niedrig» als eigener Schalter, dann
/// «Alle» und je belegte Kategorie ein Chip — in EINER horizontal
/// scrollenden Zeile, damit am Handy keine Chip-Wand die Liste nach unten
/// drückt (Smartphone-first).
class MaterialKategorieChips extends StatefulWidget {
  final List<KategorieChip> chips;

  /// null = Alle.
  final String? gewaehlt;
  final bool nurNiedrig;
  final int niedrigAnzahl;
  final ValueChanged<String?> onKategorie;
  final ValueChanged<bool> onNurNiedrig;

  const MaterialKategorieChips({
    super.key,
    required this.chips,
    required this.gewaehlt,
    required this.nurNiedrig,
    required this.niedrigAnzahl,
    required this.onKategorie,
    required this.onNurNiedrig,
  });

  @override
  State<MaterialKategorieChips> createState() => _MaterialKategorieChipsState();
}

class _MaterialKategorieChipsState extends State<MaterialKategorieChips> {
  static const _alle = '__alle__';
  final _schluessel = <String, GlobalKey>{};

  GlobalKey _key(String id) => _schluessel.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _zeigeGewaehlten();
  }

  @override
  void didUpdateWidget(MaterialKategorieChips alt) {
    super.didUpdateWidget(alt);
    if (alt.gewaehlt != widget.gewaehlt) _zeigeGewaehlten();
  }

  /// Die gemerkte Kategorie kann Chip Nr. 15 sein — ohne Nachscrollen wäre
  /// der Filter aktiv, aber der aktive Chip ausserhalb des Bildes, und man
  /// wüsste nicht, warum die Liste so kurz ist.
  void _zeigeGewaehlten() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _schluessel[widget.gewaehlt ?? _alle]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip(
            label: 'Niedrig · ${widget.niedrigAnzahl}',
            aktiv: widget.nurNiedrig,
            farbe: AppColors.error,
            onTap: () => widget.onNurNiedrig(!widget.nurNiedrig),
          ),
          const SizedBox(width: 8),
          // Trennt den Niedrig-Schalter sichtbar von der Einzelauswahl:
          // er kombiniert sich mit jeder Kategorie, statt sie abzulösen.
          Container(width: 1, height: 20, color: AppColors.divider),
          const SizedBox(width: 8),
          _chip(
            key: _key(_alle),
            label: 'Alle',
            aktiv: widget.gewaehlt == null,
            onTap: () => widget.onKategorie(null),
          ),
          for (final c in widget.chips) ...[
            const SizedBox(width: 6),
            _chip(
              key: _key(c.id),
              label: '${c.name} · ${c.anzahl}',
              aktiv: widget.gewaehlt == c.id,
              // Aktiven Chip nochmals antippen = abwählen (zurück zu «Alle»).
              onTap: () =>
                  widget.onKategorie(widget.gewaehlt == c.id ? null : c.id),
            ),
          ],
        ],
      ),
    );
  }

  /// Optik wie `AppMultiToggleChips._chip` (app_filter_bar.dart), aber
  /// Einzelauswahl und mit gepolstertem Tippziel: `padded` + vertikale
  /// Dichte −1 ergibt 44 px Tippfläche bei nur 2 px höherem Chip (kompakt +
  /// padded wären 40 px). Die Zeile wird am Handy einhändig bedient.
  Widget _chip({
    Key? key,
    required String label,
    required bool aktiv,
    required VoidCallback onTap,
    Color farbe = AppColors.primary,
  }) {
    return FilterChip(
      key: key,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: aktiv ? farbe : AppColors.textSecondary,
        ),
      ),
      selected: aktiv,
      showCheckmark: false,
      selectedColor: farbe.withAlpha(45),
      side: BorderSide(
        color: aktiv ? farbe : AppColors.divider,
        width: aktiv ? 1.5 : 1.0,
      ),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (_) => onTap(),
    );
  }
}
