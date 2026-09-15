import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

IconData einsatzTypIcon(EinsatzTyp t) => switch (t) {
  EinsatzTyp.reinigung => Icons.cleaning_services,
  EinsatzTyp.stoerung => Icons.warning_amber,
  EinsatzTyp.montage => Icons.build,
  EinsatzTyp.eigenauftrag => Icons.build_circle_outlined,
  EinsatzTyp.saisonreinigung => Icons.cleaning_services_outlined,
  EinsatzTyp.termin => Icons.event,
  EinsatzTyp.pikett => Icons.nightlight_round,
};

Color einsatzTypFarbe(EinsatzTyp t) => switch (t) {
  EinsatzTyp.reinigung => AppColors.success,
  EinsatzTyp.stoerung => AppColors.warning,
  EinsatzTyp.montage => AppColors.info,
  EinsatzTyp.eigenauftrag => const Color(0xFF7C3AED),
  EinsatzTyp.saisonreinigung => AppColors.primary,
  EinsatzTyp.termin => AppColors.primary,
  EinsatzTyp.pikett => Colors.indigo,
};

Color _statusFarbe(EinsatzStatus s) => switch (s) {
  EinsatzStatus.offen => AppColors.warning,
  EinsatzStatus.geplant => AppColors.info,
  EinsatzStatus.inArbeit => AppColors.info,
  EinsatzStatus.erledigt => AppColors.success,
  EinsatzStatus.verrechnet => AppColors.textSecondary,
};

/// Kleiner Chip mit Stufe und, falls vorhanden, Kennzeichen — dieselbe
/// Bauart wie der Zähler-Chip der Startseiten-Kacheln.
class StatusBadge extends StatelessWidget {
  final EinsatzStatus status;
  final EinsatzKennzeichen kennzeichen;
  const StatusBadge({
    super.key,
    required this.status,
    this.kennzeichen = EinsatzKennzeichen.keines,
  });

  @override
  Widget build(BuildContext context) {
    final farbe = _statusFarbe(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: farbe.withAlpha(25),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            einsatzStatusLabel(status),
            style: TextStyle(
              color: farbe,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (kennzeichen != EinsatzKennzeichen.keines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              einsatzKennzeichenLabel(kennzeichen),
              style: const TextStyle(fontSize: 10, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

/// Eine Zeile des Einsätze-Screens (Variante B, wie die Heute-Liste).
///
/// CanvasKit: InkWell + Container + Row — kein Material-Komfort-Widget.
/// Auf dem produktiven CanvasKit-Web haben solche Widgets dreimal nicht
/// gerendert oder nicht reagiert (CLAUDE.md).
class EinsatzZeile extends StatelessWidget {
  final Einsatz einsatz;
  final VoidCallback onTap;
  const EinsatzZeile({super.key, required this.einsatz, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = einsatz;
    final datum =
        '${_wochentage[e.datum.weekday - 1]} '
        '${e.datum.day.toString().padLeft(2, '0')}.'
        '${e.datum.month.toString().padLeft(2, '0')}.';
    final zweiteZeile = [
      e.typLabel,
      if (e.betriebOrt != null && e.betriebOrt!.isNotEmpty) e.betriebOrt!,
      if (e.zeit != null) '$datum ${e.zeit}' else datum,
      if (e.beschreibung != null && e.beschreibung!.isNotEmpty) e.beschreibung!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x11000000))),
        ),
        child: Row(
          children: [
            Icon(
              einsatzTypIcon(e.typ),
              color: einsatzTypFarbe(e.typ),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.betriebName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    zweiteZeile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(status: e.status, kennzeichen: e.kennzeichen),
            if (e.betragCHF != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  chf(e.betragCHF!),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
