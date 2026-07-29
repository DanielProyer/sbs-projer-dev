import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/util/google_fehler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Zeigt einen Google-Fehler im Klartext — mit Knopf zur Seite, die ihn behebt.
///
/// Nimmt den [messenger] statt eines BuildContext, damit die Meldung auch dann
/// noch erscheint, wenn das auslösende Formular sich bereits geschlossen hat
/// (Hintergrund-Sync nach dem Speichern).
void zeigeGoogleFehler(ScaffoldMessengerState messenger, GoogleFehler fehler) {
  final link = fehler.link;
  messenger.showSnackBar(
    SnackBar(
      content: Text(fehler.text),
      duration: const Duration(seconds: 10),
      action: link == null
          ? null
          : SnackBarAction(
              label: 'Öffnen',
              onPressed: () => launchUrl(
                Uri.parse(link),
                mode: LaunchMode.externalApplication,
              ),
            ),
    ),
  );
}
