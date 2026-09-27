import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgaben_am_tag.dart';

/// Eigene Aufgaben, die am gewählten Tag fällig sind — unter den
/// Saison-Terminen im Tourenplan (27.09.2026).
///
/// Nur Anzeige: Der Haken zeigt «erledigt», abgehakt wird im
/// Aufgaben-Screen ([onTap]). Gleicher Aufbau wie `SaisonTermineSektion`:
/// startet zugeklappt (Daniel 06.09.2026: Sektionen über dem Tagesplan
/// «brauchen zu viel Platz»), die Anzahl im Titel sagt, dass etwas ansteht.
///
/// Kein `ExpansionTile`/`ListTile`: zeichnen auf dem produktiven
/// CanvasKit-Web unzuverlässig (CLAUDE.md) — Kopf und Zeilen als `InkWell`.
class AufgabenTagSektion extends StatefulWidget {
  final List<AufgabeAmTag> aufgaben;
  final VoidCallback onTap;

  const AufgabenTagSektion({
    super.key,
    required this.aufgaben,
    required this.onTap,
  });

  @override
  State<AufgabenTagSektion> createState() => _AufgabenTagSektionState();
}

class _AufgabenTagSektionState extends State<AufgabenTagSektion> {
  bool _offen = false;

  @override
  Widget build(BuildContext context) {
    if (widget.aufgaben.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _offen = !_offen),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.task_alt,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Aufgaben (${widget.aufgaben.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _offen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_offen) ...[
            for (final a in widget.aufgaben)
              _AufgabeZeile(aufgabe: a, onTap: widget.onTap),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _AufgabeZeile extends StatelessWidget {
  final AufgabeAmTag aufgabe;
  final VoidCallback onTap;

  const _AufgabeZeile({required this.aufgabe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final erledigt = aufgabe.erledigt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Nur Anzeige — kein Tippziel für sich.
            Icon(
              erledigt ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: erledigt ? AppColors.success : AppColors.textSecondary,
              semanticLabel: erledigt ? 'erledigt' : 'offen',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                aufgabe.titel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: erledigt
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  decoration: erledigt ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
