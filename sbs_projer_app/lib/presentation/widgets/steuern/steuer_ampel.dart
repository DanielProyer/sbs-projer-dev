import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

/// Ampelfarbe für den Soll/Ist-Stand eines Steuerjahres — von Übersicht und
/// Jahresdetail gemeinsam genutzt, damit dieselbe Lage nicht in zwei Screens
/// in zwei Farben erscheint.
Color ampelFarbe(SteuerAmpel a) => switch (a) {
  SteuerAmpel.ausgeglichen => AppColors.success,
  SteuerAmpel.schuld => AppColors.error,
  SteuerAmpel.guthaben => AppColors.info,
};

/// Farbiger Punkt vor einer Statuszeile.
class AmpelPunkt extends StatelessWidget {
  final Color farbe;
  final double groesse;

  const AmpelPunkt({super.key, required this.farbe, this.groesse = 10});

  @override
  Widget build(BuildContext context) => Container(
    width: groesse,
    height: groesse,
    decoration: BoxDecoration(shape: BoxShape.circle, color: farbe),
  );
}
