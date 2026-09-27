import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/file_download_export.dart';
import 'package:sbs_projer_app/services/pdf/pdf_tab_oeffner_export.dart';

/// Öffnet [bytes] im neuen Browser-Tab — und bietet einen Download an, wenn
/// der Browser das Fenster blockiert ([pdfBlockiertMelden]).
///
/// Für Aufrufer, die die Bytes SCHON haben und im Tipp-Handler öffnen
/// (Mahnlauf «Druck-PDF öffnen», Event-Abschluss «Vorschau»):
/// `oeffnePdfImNeuenTab` ruft `window.open` noch synchron, vor dem ersten
/// `await` hier — das Fenster gilt so als Folge des Tippens. Wer erst
/// herunterlädt, öffnet zweistufig (`pdfTabVorbereiten` + `zeigePdfImTab`)
/// und wertet deren Ergebnis selbst mit [pdfBlockiertMelden] aus
/// (Dokumentliste).
///
/// WARUM (Review 27.09.2026, K6): `oeffnePdfImNeuenTab` meldet seit dem
/// 27.09. «blockiert» mit `false`, aber nur die Dokumentliste wertete das
/// aus. Mahnlauf und Event-Abschluss endeten dann stumm — man tippte und
/// sah nichts.
Future<void> pdfOeffnenOderHerunterladen(
  BuildContext context,
  Uint8List bytes,
  String dateiname,
) async {
  // Vor dem await holen: danach ist der Kontext vielleicht nicht mehr gültig.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final offen = await oeffnePdfImNeuenTab(bytes, dateiname);
  if (!offen) pdfBlockiertMelden(messenger, bytes, dateiname);
}

/// Der Rückfall, wenn der Browser das PDF-Fenster blockiert hat: eine
/// SnackBar mit «Herunterladen». Ein Download über ein Anker-Element fällt
/// nicht unter den Popup-Blocker.
void pdfBlockiertMelden(
  ScaffoldMessengerState? messenger,
  Uint8List bytes,
  String dateiname,
) {
  messenger?.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 10),
      content: const Text('Browser hat das Fenster blockiert — Download'),
      action: SnackBarAction(
        label: 'Herunterladen',
        onPressed: () =>
            unawaited(pdfHerunterladen(messenger, bytes, dateiname)),
      ),
    ),
  );
}

/// Das PDF als Datei herunterladen. Ein Fehler wird gemeldet, nie still
/// verschluckt.
Future<void> pdfHerunterladen(
  ScaffoldMessengerState? messenger,
  Uint8List bytes,
  String dateiname,
) async {
  try {
    await downloadBytesFile(
      filename: dateiname,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Download fehlgeschlagen: ${kurzeFehlermeldung(e)}'),
      ),
    );
  }
}
