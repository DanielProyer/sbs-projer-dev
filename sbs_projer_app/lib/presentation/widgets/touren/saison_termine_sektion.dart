import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Vorgeschlagene Saison-Termine (Eröffnungs-/Endreinigungen) über dem
/// Tagesplan.
///
/// **Startet zugeklappt** (Daniel, 06.09.2026: «brauchen zu viel Platz»): Bei
/// einem Saisonwechsel stehen schnell zehn Vorschläge an, und aufgeklappt
/// schoben sie den eigentlichen Tagesplan auf dem Handy aus dem Bild. Die
/// Anzahl im Titel sagt weiterhin, dass etwas ansteht.
///
/// Kein `ExpansionTile`: das zeichnet auf dem produktiven CanvasKit-Web
/// unzuverlässig (siehe CLAUDE.md) — Kopfzeile deshalb als `InkWell`.
class SaisonTermineSektion extends StatefulWidget {
  final List<TourEintrag> eintraege;
  final void Function(TourEintrag) onUebernehmen;
  final VoidCallback onAlleUebernehmen;
  final void Function(TourEintrag) onTap;

  const SaisonTermineSektion({
    super.key,
    required this.eintraege,
    required this.onUebernehmen,
    required this.onAlleUebernehmen,
    required this.onTap,
  });

  @override
  State<SaisonTermineSektion> createState() => _SaisonTermineSektionState();
}

class _SaisonTermineSektionState extends State<SaisonTermineSektion> {
  bool _offen = false;

  @override
  Widget build(BuildContext context) {
    if (widget.eintraege.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _offen = !_offen),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              // Zugeklappt ist die Kopfzeile die ganze Sektion — dann rundum
              // gleich viel Luft, damit sie einhändig sicher zu treffen ist.
              padding: EdgeInsets.fromLTRB(12, 10, _offen ? 4 : 12, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Saison-Termine (${widget.eintraege.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                  const Spacer(),
                  // «Alle übernehmen» erst, wenn man auch sieht, was man
                  // übernimmt.
                  if (_offen)
                    TextButton(
                      onPressed: widget.onAlleUebernehmen,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Alle übernehmen',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  Icon(
                    _offen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
          ),
          if (_offen) ...[
            for (final e in widget.eintraege)
              _AutoTerminKarte(
                eintrag: e,
                onUebernehmen: () => widget.onUebernehmen(e),
                onTap: () => widget.onTap(e),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _AutoTerminKarte extends StatelessWidget {
  final TourEintrag eintrag;
  final VoidCallback onUebernehmen;
  final VoidCallback onTap;

  const _AutoTerminKarte({
    required this.eintrag,
    required this.onUebernehmen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = eintrag.faelligkeit != null
        ? faelligkeitFarbe(eintrag.faelligkeit!)
        : AppColors.info;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eintrag.betriebName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    eintrag.beschreibung,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.primary,
              ),
              onPressed: onUebernehmen,
              tooltip: 'Zum Tagesplan',
              iconSize: 22,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
