import 'package:flutter/material.dart';

/// Nicht schliessbarer Fortschrittsdialog für längere Abläufe (z. B. «Alle
/// verbuchen» im camt-Abgleich: 30+ sequenzielle Buchungen, vorher ~10 s ohne
/// jedes Lebenszeichen — Rückmeldung Daniel 01.09.2026).
///
/// Bewusst aus einfachen Widgets gebaut (Dialog/Column/Text — CanvasKit-Regel
/// in CLAUDE.md). Der Stand kommt über einen [ValueNotifier], damit der
/// aufrufende Ablauf ihn ohne setState-Zugriff auf den Dialog erhöhen kann.
class FortschrittsDialog extends StatelessWidget {
  final String titel;
  final ValueNotifier<int> stand;

  /// Gesamtzahl der Schritte. Ohne Angabe wird nur der Titel gezeigt
  /// (unbestimmter Fortschritt).
  final int? total;

  const FortschrittsDialog({
    super.key,
    required this.titel,
    required this.stand,
    this.total,
  });

  /// Zeigt den Dialog nicht-abbrechbar an. Schliessen über
  /// `Navigator.of(context, rootNavigator: true).pop()` im Aufrufer.
  static void zeige(
    BuildContext context, {
    required String titel,
    required ValueNotifier<int> stand,
    int? total,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          FortschrittsDialog(titel: titel, stand: stand, total: total),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(titel, textAlign: TextAlign.center),
            if (total != null) ...[
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: stand,
                builder: (_, n, _) => Text(
                  '$n von $total …',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
