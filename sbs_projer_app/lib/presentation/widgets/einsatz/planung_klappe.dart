import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Klappe «Planung & Arbeitszeit» im Störungsformular (Runde 5,
/// 27.09.2026): Kopfzeile mit Chevron, darunter bei [offen] die [children]
/// (Schalter «Erst geplant» + `ArbeitszeitBlock`). Wann sie offen ist,
/// entscheidet `planungAufgeklappt` (core/util/planung_aufgeklappt.dart).
///
/// Aus GestureDetector + Container + Row gebaut, kein ExpansionTile —
/// CanvasKit-Regel (CLAUDE.md): ein ExpansionTile zeichnete title/subtitle
/// am 13.08.2026 gar nicht.
class PlanungKlappe extends StatelessWidget {
  const PlanungKlappe({
    super.key,
    required this.offen,
    required this.zuklappbar,
    required this.onUmschalten,
    required this.zusammenfassung,
    required this.children,
  });

  final bool offen;

  /// `false`, solange die Klappe offen bleiben MUSS (Schalter an oder
  /// Arbeitszeit erfasst) — dann kein Chevron und kein Tipp.
  final bool zuklappbar;

  final VoidCallback onUmschalten;

  /// Zeile unter dem Titel, solange zu (was ohne Aufklappen gilt).
  final String zusammenfassung;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tippbar = zuklappbar || !offen;
    final kopf = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            offen ? Icons.event_note : Icons.check_circle_outline,
            color: offen ? AppColors.info : AppColors.success,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Planung & Arbeitszeit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (!offen)
                  Text(
                    zusammenfassung,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (tippbar)
            Icon(
              offen ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: tippbar,
          expanded: offen,
          child: GestureDetector(
            key: const Key('planung_klappe_kopf'),
            behavior: HitTestBehavior.opaque,
            onTap: tippbar ? onUmschalten : null,
            child: kopf,
          ),
        ),
        if (offen) ...children,
      ],
    );
  }
}
