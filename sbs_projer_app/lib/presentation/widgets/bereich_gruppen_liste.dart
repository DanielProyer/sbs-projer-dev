import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/dashboard_tile.dart';

/// Zeichnet Bereichs-Gruppen: Kopf, dann Kacheln oder Zeilen.
///
/// CanvasKit: Zeilen aus `InkWell` + `Container` + `Row`, kein `ListTile` —
/// die Mehr-Seite ist nach der Leiste die meistbenutzte Weiche der App, ein
/// nicht rendernder Eintrag fiele erst auf, wenn man ihn braucht (CLAUDE.md,
/// drei bestätigte Vorfälle).
class BereichGruppenListe extends StatelessWidget {
  final List<BereichGruppe> gruppen;
  final String? Function(BereichEintrag) zaehler;
  final ValueChanged<String> onTap;

  const BereichGruppenListe({
    super.key,
    required this.gruppen,
    required this.zaehler,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in gruppen) ...[
          if (g.titel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                g.titel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (g.alsKacheln)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 2.1,
              children: [
                for (final e in g.eintraege)
                  DashboardTile(
                    icon: e.icon,
                    label: e.titel,
                    count: zaehler(e),
                    color: AppColors.primary,
                    onTap: () => onTap(e.ziel),
                  ),
              ],
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < g.eintraege.length; i++)
                    _Zeile(
                      eintrag: g.eintraege[i],
                      zaehler: zaehler(g.eintraege[i]),
                      trennlinie: i < g.eintraege.length - 1,
                      onTap: () => onTap(g.eintraege[i].ziel),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Zeile extends StatelessWidget {
  final BereichEintrag eintrag;
  final String? zaehler;
  final bool trennlinie;
  final VoidCallback onTap;

  const _Zeile({
    required this.eintrag,
    required this.zaehler,
    required this.trennlinie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: trennlinie
              ? const Border(bottom: BorderSide(color: AppColors.divider))
              : null,
        ),
        child: Row(
          children: [
            Icon(eintrag.icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eintrag.titel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (eintrag.untertitel != null)
                    Text(
                      eintrag.untertitel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (zaehler != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  zaehler!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
