import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/zahlung_kern_plan.dart';
import 'package:sbs_projer_app/core/util/zahlungsdifferenz_text.dart';

String mehrzahlungText(MehrzahlungZiel z) => switch (z) {
  MehrzahlungZiel.aoErtrag => 'a.o. Ertrag 8000 (Trinkgeld/Rundung)',
  MehrzahlungZiel.guthaben =>
    'Kundenguthaben 2030 (mit der nächsten Rechnung verrechnen)',
};

String mehrzahlungHinweis(double betrag) =>
    'Mehrzahlung CHF ${betrag.toStringAsFixed(2)} — Vorgabe: bis CHF '
    '${kMehrzahlungGuthabenAb.toStringAsFixed(2)} Trinkgeld, darüber Guthaben.';

/// Differenz-Text mit dem GEWÄHLTEN Mehrzahlungs-Ziel statt des Standards —
/// sonst stünde über der Wahl «a.o. Ertrag», obwohl Guthaben angetippt ist.
String differenzTextMitWahl(DifferenzInfo info, MehrzahlungZiel? wahl) =>
    info.art != DifferenzArt.mehr || wahl == null
    ? info.text
    : DifferenzInfo(
        info.art,
        info.betrag,
        info.istBagatelle,
        guthabenHinweis: info.guthabenHinweis,
        mehrzahlungZiel: wahl,
      ).text;

/// Wahl, wohin eine Mehrzahlung geht (Runde 3, Entscheid 26.09.2026). Zwei
/// Zeilen aus InkWell/Container — kein RadioListTile (CanvasKit-Falle).
class MehrzahlungWahl extends StatelessWidget {
  final double betrag;
  final MehrzahlungZiel wert;
  final ValueChanged<MehrzahlungZiel> onChanged;
  const MehrzahlungWahl({
    super.key,
    required this.betrag,
    required this.wert,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            mehrzahlungHinweis(betrag),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final z in MehrzahlungZiel.values)
          InkWell(
            onTap: () => onChanged(z),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: z == wert
                      ? AppColors.primary
                      : Theme.of(context).dividerColor,
                  width: z == wert ? 2 : 1,
                ),
                color: z == wert
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    z == wert
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: z == wert ? AppColors.primary : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(mehrzahlungText(z))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
