import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/pause_pruefung.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/presentation/widgets/zeit_auswahl.dart';

/// Antwort auf die «vergessene Pause»-Nachfrage (Daniel 31.07.2026).
sealed class PausePruefenAntwort {
  const PausePruefenAntwort();
}

/// Pause zum gewählten Zeitpunkt (Vorschlag oder frei gewählt) beenden.
class PausePruefenEnde extends PausePruefenAntwort {
  final int endeMinuten;
  const PausePruefenEnde(this.endeMinuten);
}

/// Pause verwerfen — Zustand zurücksetzen, ohne Minuten zu zählen (die
/// Dauer ist nicht mehr verlässlich rekonstruierbar).
class PausePruefenVerwerfen extends PausePruefenAntwort {
  const PausePruefenVerwerfen();
}

/// Zeigt die «Pause noch offen»-Nachfrage als Bottom-Sheet. Liefert `null`,
/// wenn weggetippt wurde — das ist ein gültiger Ausgang: die Pause läuft
/// dann einfach weiter, nichts wird verändert.
Future<PausePruefenAntwort?> zeigePausePruefenSheet(
  BuildContext context, {
  required String pauseStart,
  required PauseBefund befund,
  required int vorschlagMinuten,
}) {
  return showModalBottomSheet<PausePruefenAntwort>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PausePruefenSheet(
      pauseStart: pauseStart,
      befund: befund,
      vorschlagMinuten: vorschlagMinuten,
    ),
  );
}

class _PausePruefenSheet extends StatelessWidget {
  final String pauseStart;
  final PauseBefund befund;
  final int vorschlagMinuten;

  const _PausePruefenSheet({
    required this.pauseStart,
    required this.befund,
    required this.vorschlagMinuten,
  });

  Future<void> _andereZeitWaehlen(BuildContext context) async {
    final jetzt = DateTime.now();
    final gewaehlt = await zeigeZeitauswahl(
      context,
      initial: TimeOfDay(hour: jetzt.hour, minute: jetzt.minute),
    );
    if (gewaehlt == null || !context.mounted) return;
    Navigator.pop(
      context,
      PausePruefenEnde(gewaehlt.hour * 60 + gewaehlt.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vorschlagText = hhmmAusMinuten(vorschlagMinuten);
    final hinweis = befund == PauseBefund.zuLang
        ? 'Pause läuft seit $pauseStart schon sehr lange. Wann war Schluss?'
        : 'Pause läuft seit $pauseStart. Du warst seither unterwegs — '
              'wann war Schluss?';
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
                'Pause noch offen?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                hinweis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            _PausePruefenZeile(
              icon: Icons.check_circle_outline,
              text: 'Schluss um $vorschlagText',
              onTap: () =>
                  Navigator.pop(context, PausePruefenEnde(vorschlagMinuten)),
            ),
            _PausePruefenZeile(
              icon: Icons.schedule,
              text: 'Andere Zeit wählen',
              onTap: () => _andereZeitWaehlen(context),
            ),
            _PausePruefenZeile(
              icon: Icons.delete_outline,
              text: 'Pause verwerfen',
              farbe: AppColors.error,
              onTap: () =>
                  Navigator.pop(context, const PausePruefenVerwerfen()),
            ),
            const Divider(height: 20),
            _PausePruefenZeile(
              icon: Icons.close,
              text: 'Pause läuft weiter',
              farbe: AppColors.textSecondary,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tippbare Zeile — GestureDetector + Container statt Material-Button
/// (CanvasKit-Regel: Material-Buttons in Sheets werden auf Web nicht
/// zuverlässig gezeichnet, siehe einplanen_sheet.dart).
class _PausePruefenZeile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color farbe;
  final VoidCallback onTap;

  const _PausePruefenZeile({
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
