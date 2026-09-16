import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgabe_zeile.dart';

/// «Was ist offen?» — der Büro-Ausschnitt der einen Aufgabenliste (B3).
///
/// WARUM hier keine eigene Liste: Die Buchhaltungs-Startseite zeigte vier
/// Jahres-Kennzahlen und 13 Ziele, aber nirgends, was heute offen ist
/// (Befund 4 der App-Analyse 09/2026). Die Zeilen dafür gibt es längst — als
/// Detektoren der Aufgabenliste aus B6. Eine zweite Liste wäre genau der
/// Fehler, den B6 behoben hat.
///
/// Fristen zuerst, dann Vorräte: Ein Stichtag drängt, ein Stapel wartet.
class BueroOffenBlock extends StatelessWidget {
  final List<AufgabenEintrag> eintraege;
  final DateTime heute;
  final ValueChanged<AufgabenEintrag> onDorthin;
  final void Function(AufgabenEintrag, int tage) onSnooze;
  final ValueChanged<AufgabenEintrag> onErledigt;

  const BueroOffenBlock({
    super.key,
    required this.eintraege,
    required this.heute,
    required this.onDorthin,
    required this.onSnooze,
    required this.onErledigt,
  });

  @override
  Widget build(BuildContext context) {
    final sortiert = [...eintraege]
      ..sort((a, b) {
        final art = (a.istVorrat ? 1 : 0) - (b.istVorrat ? 1 : 0);
        if (art != 0) return art;
        if (a.faellig == null && b.faellig == null) {
          return a.titel.compareTo(b.titel);
        }
        if (a.faellig == null) return 1;
        if (b.faellig == null) return -1;
        return a.faellig!.compareTo(b.faellig!);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Was ist offen?',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (sortiert.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nichts offen 🎉',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final a in sortiert)
            AufgabeZeile(
              eintrag: a,
              heute: heute,
              onDorthin: () => onDorthin(a),
              onSnooze: (t) => onSnooze(a, t),
              onErledigt: () => onErledigt(a),
              onEinplanen: () {},
              onBestaetigen: () {},
            ),
      ],
    );
  }
}
