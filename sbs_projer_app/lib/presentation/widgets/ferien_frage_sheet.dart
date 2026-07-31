import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Antwort auf die Ferienfrage beim Reinigungs-Abschluss (Baustein B,
/// docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md).
sealed class FerienFrageAntwort {
  const FerienFrageAntwort();
}

/// "Keine geplant" -> `keine_betriebsferien = true` + `ferien_bestaetigt_am`.
class FerienFrageKeineGeplant extends FerienFrageAntwort {
  const FerienFrageKeineGeplant();
}

/// "Von–bis" -> neue Ferien-Periode (`quelle: 'kunde'`) + `ferien_bestaetigt_am`.
class FerienFrageVonBis extends FerienFrageAntwort {
  final DateTime von;
  final DateTime bis;
  const FerienFrageVonBis({required this.von, required this.bis});
}

/// "Weiss nicht" -> `ferien_frage_ruht_bis = heute + 30 Tage`.
class FerienFrageWeissNicht extends FerienFrageAntwort {
  const FerienFrageWeissNicht();
}

/// Zeigt die Ferienfrage als Bottom-Sheet. Liefert `null`, wenn der Nutzer
/// die Frage übersprungen hat (weggetippt / Sheet zugezogen) — das ist
/// AUSDRÜCKLICH ein gültiger Ausgang und darf den Reinigungs-Abschluss nie
/// aufhalten; der Aufrufer speichert bei `null` einfach nichts zusätzlich.
Future<FerienFrageAntwort?> zeigeFerienFrageSheet(
  BuildContext context, {
  required String betriebName,
}) {
  return showModalBottomSheet<FerienFrageAntwort>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FerienFrageSheet(betriebName: betriebName),
  );
}

class _FerienFrageSheet extends StatelessWidget {
  final String betriebName;

  const _FerienFrageSheet({required this.betriebName});

  Future<void> _vonBisWaehlen(BuildContext context) async {
    final heute = DateTime.now();
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: heuteTag,
      lastDate: heuteTag.add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(
        start: heuteTag,
        end: heuteTag.add(const Duration(days: 14)),
      ),
      helpText: 'Betriebsferien — Zeitraum wählen',
    );
    // Abbruch im Datumsauswahl-Dialog: Sheet bleibt offen, Nutzer kann eine
    // andere Antwort wählen oder erneut versuchen.
    if (range == null || !context.mounted) return;
    Navigator.pop(context, FerienFrageVonBis(von: range.start, bis: range.end));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Nächste Betriebsferien?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                betriebName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            _FerienFrageZeile(
              icon: Icons.check_circle_outline,
              text: 'Keine geplant',
              onTap: () =>
                  Navigator.pop(context, const FerienFrageKeineGeplant()),
            ),
            _FerienFrageZeile(
              icon: Icons.date_range_outlined,
              text: 'Von – bis',
              onTap: () => _vonBisWaehlen(context),
            ),
            _FerienFrageZeile(
              icon: Icons.help_outline,
              text: 'Weiss nicht',
              onTap: () =>
                  Navigator.pop(context, const FerienFrageWeissNicht()),
            ),
            const Divider(height: 20),
            _FerienFrageZeile(
              icon: Icons.close,
              text: 'Überspringen',
              farbe: AppColors.textSecondary,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tippbare Zeile im Sheet — bewusst GestureDetector + Container statt eines
/// Material-Buttons (CanvasKit-Regel: Material-Buttons in Sheets werden auf
/// Web nicht zuverlässig gezeichnet, siehe tourenplanung_screen.dart).
class _FerienFrageZeile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color farbe;
  final VoidCallback onTap;

  const _FerienFrageZeile({
    required this.icon,
    required this.text,
    required this.onTap,
    this.farbe = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: farbe),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: farbe,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
