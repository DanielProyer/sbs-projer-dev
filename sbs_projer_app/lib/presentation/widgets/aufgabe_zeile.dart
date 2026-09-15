import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';

/// Eine Zeile der Aufgabenliste — für Sheet und Screen dieselbe (B6).
///
/// CanvasKit: `InkWell` + `Container` + `Row`, kein `ListTile` (CLAUDE.md).
/// Welche Knöpfe erscheinen, folgt aus der Quelle des Eintrags
/// (`erledigbar`, `snoozebar`, `einplanbar`, `bestaetigbar`).
class AufgabeZeile extends StatelessWidget {
  final AufgabenEintrag eintrag;
  final DateTime heute;
  final VoidCallback onDorthin;
  final ValueChanged<int> onSnooze;
  final VoidCallback onErledigt;
  final VoidCallback onEinplanen;
  final VoidCallback onBestaetigen;

  const AufgabeZeile({
    super.key,
    required this.eintrag,
    required this.heute,
    required this.onDorthin,
    required this.onSnooze,
    required this.onErledigt,
    required this.onEinplanen,
    required this.onBestaetigen,
  });

  Widget _icon() {
    final e = eintrag;
    switch (e.quelle) {
      case AufgabenQuelle.einsatz:
        return Icon(
          einsatzTypIcon(e.einsatz!.typ),
          size: 20,
          color: einsatzTypFarbe(e.einsatz!.typ),
        );
      case AufgabenQuelle.saisonVorschlag:
        return const Icon(
          Icons.cleaning_services_outlined,
          size: 20,
          color: AppColors.primary,
        );
      case AufgabenQuelle.termin:
        return const Icon(
          Icons.cleaning_services,
          size: 20,
          color: AppColors.success,
        );
      case AufgabenQuelle.aenderungsVorschlag:
        return const Icon(
          Icons.fact_check_outlined,
          size: 20,
          color: AppColors.info,
        );
      case AufgabenQuelle.detektor:
      case AufgabenQuelle.eigene:
        return Icon(
          Icons.circle,
          size: 12,
          color: e.dringend ? AppColors.error : AppColors.warning,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = eintrag;
    final zeit = faelligText(e.faellig, heute);
    final untertitel = [
      if (e.untertitel != null && e.untertitel!.isNotEmpty) e.untertitel!,
      if (zeit.isNotEmpty) zeit,
    ].join(' · ');
    final ueberfaellig = zeit.startsWith('überfällig');

    return InkWell(
      onTap: e.route == null ? null : onDorthin,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x11000000))),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: _icon())),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.titel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (untertitel.isNotEmpty)
                    Text(
                      untertitel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ueberfaellig
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (e.route != null && e.quelle != AufgabenQuelle.eigene)
              IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                tooltip: 'Dorthin',
                visualDensity: VisualDensity.compact,
                onPressed: onDorthin,
              ),
            if (e.einplanbar)
              IconButton(
                icon: const Icon(Icons.event_outlined, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Einplanen',
                visualDensity: VisualDensity.compact,
                onPressed: onEinplanen,
              ),
            if (e.bestaetigbar)
              IconButton(
                icon: const Icon(Icons.event_available_outlined, size: 20),
                color: AppColors.primary,
                tooltip: 'Termin bestätigen',
                visualDensity: VisualDensity.compact,
                onPressed: onBestaetigen,
              ),
            if (e.snoozebar)
              PopupMenuButton<int>(
                icon: const Icon(Icons.snooze, size: 18),
                tooltip: 'Später erinnern',
                onSelected: onSnooze,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 1, child: Text('1 Tag')),
                  PopupMenuItem(value: 3, child: Text('3 Tage')),
                  PopupMenuItem(value: 7, child: Text('7 Tage')),
                ],
              ),
            if (e.erledigbar)
              IconButton(
                icon: const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: AppColors.success,
                ),
                tooltip: 'Erledigt',
                visualDensity: VisualDensity.compact,
                onPressed: onErledigt,
              ),
          ],
        ),
      ),
    );
  }
}
