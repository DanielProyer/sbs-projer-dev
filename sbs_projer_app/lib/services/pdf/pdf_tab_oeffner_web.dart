import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Öffnet PDF-Bytes in einem neuen Browser-Tab (Blob-URL) — sauberes
/// Anschauen/Zoomen statt Druckdialog (Regel Daniel 26.07.2026).
///
/// Nur für Aufrufer, die die Bytes SCHON haben und synchron im Tipp-Handler
/// öffnen. Wer erst herunterlädt, nimmt [pdfTabVorbereiten] +
/// [zeigePdfImTab] — sonst blockiert der Browser das Fenster.
///
/// `true` = der Tab ist offen; `false` = der Browser hat ihn blockiert
/// (`window.open` liefert dann kein Fenster). Der Aufrufer entscheidet, ob
/// er stattdessen einen Download anbietet — bis 27.09.2026 endete dieser
/// Fall stumm: man tippte aufs Dokument und sah nichts.
Future<bool> oeffnePdfImNeuenTab(Uint8List bytes, String dateiname) async {
  final url = _blobUrl(bytes);
  final fenster = web.window.open(url, '_blank');
  if (fenster == null || fenster.closed) {
    web.URL.revokeObjectURL(url);
    return false;
  }
  _spaeterFreigeben(url);
  return true;
}

/// Griff auf einen vorab geöffneten, noch leeren Browser-Tab.
class PdfTabHandle {
  PdfTabHandle._(this._fenster);

  final web.Window _fenster;

  /// Schliesst den vorbereiteten Tab (z. B. wenn der Download scheiterte).
  void close() {
    try {
      if (!_fenster.closed) _fenster.close();
    } catch (_) {
      // Tab schon weg oder nicht mehr erreichbar — nichts zu tun.
    }
  }
}

/// Stufe 1: öffnet SYNCHRON im Tipp-Handler einen leeren Tab — vor dem
/// ersten `await`.
///
/// WARUM: Ein `window.open` nach einem `await` gilt nicht mehr als Folge
/// der Nutzer-Geste. iOS-Safari blockiert es dann immer, Chrome nach rund
/// fünf Sekunden — der Nutzer tippt aufs Dokument und sieht nichts.
///
/// `null` = der Browser hat auch dieses Fenster blockiert;
/// [zeigePdfImTab] fällt dann auf [oeffnePdfImNeuenTab] zurück.
PdfTabHandle? pdfTabVorbereiten() {
  final fenster = web.window.open('', '_blank');
  if (fenster == null) return null;
  try {
    // Kurzer Hinweis statt einer weissen Seite, solange der Download läuft.
    fenster.document.title = 'PDF wird geladen …';
    fenster.document.body?.textContent = 'PDF wird geladen …';
  } catch (_) {
    // Rein kosmetisch — ein gesperrtes Dokument hält nichts auf.
  }
  return PdfTabHandle._(fenster);
}

/// Stufe 2: zeigt die heruntergeladenen Bytes im vorbereiteten Tab.
///
/// `true` = das PDF steht in einem Tab. `false` = kein vorbereiteter Tab
/// (blockiert oder inzwischen geschlossen) UND der Rückfall
/// [oeffnePdfImNeuenTab] wurde nach dem `await` ebenfalls blockiert — dann
/// muss der Aufrufer etwas anbieten (Dokumentliste: Download).
Future<bool> zeigePdfImTab(
  PdfTabHandle? handle,
  Uint8List bytes,
  String dateiname,
) async {
  if (handle == null || handle._fenster.closed) {
    return oeffnePdfImNeuenTab(bytes, dateiname);
  }
  final url = _blobUrl(bytes);
  handle._fenster.location.href = url;
  _spaeterFreigeben(url);
  return true;
}

String _blobUrl(Uint8List bytes) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  return web.URL.createObjectURL(blob);
}

/// Objekt-URL erst nach einer Minute freigeben — der Tab lädt das PDF
/// asynchron; sofortiges Revoke würde ihn leer lassen.
void _spaeterFreigeben(String url) {
  Future.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );
}
