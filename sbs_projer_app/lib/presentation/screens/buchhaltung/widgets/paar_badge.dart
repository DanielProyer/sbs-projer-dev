import 'package:flutter/material.dart';

/// Farbpalette für Zahlung↔Rechnung-Paare in den Zuordnungs-Dialogen.
/// Kräftige, klar unterscheidbare Töne; bewusst ohne Grün (Grün markiert im
/// Dialog bereits den Vermerk-Vorschlag) und ohne Rot (Fehler-Semantik).
const List<Color> kPaarFarben = [
  Color(0xFF1565C0), // Blau
  Color(0xFFE65100), // Orange
  Color(0xFF6A1B9A), // Violett
  Color(0xFF00838F), // Petrol
  Color(0xFFAD1457), // Beere
  Color(0xFF4E342E), // Braun
  Color(0xFF283593), // Indigo
  Color(0xFF9E9D24), // Oliv
];

/// Nummerierter Farb-Punkt, der ein Zahlung↔Rechnung-Paar markiert: Die
/// Zahlung ❶ und die Rechnung(en), die sie begleicht, tragen denselben Punkt.
class PaarBadge extends StatelessWidget {
  /// 1-basierte Paar-Nummer; bestimmt auch die Farbe.
  final int nummer;

  const PaarBadge({super.key, required this.nummer});

  Color get farbe => kPaarFarben[(nummer - 1) % kPaarFarben.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
      child: Text(
        '$nummer',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
