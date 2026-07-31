/// Vergessenes Beenden einer Pause erkennen (Daniel 31.07.2026): Beim
/// Znüni wird «Pause» gedrückt, beim Weiterfahren aber oft vergessen,
/// sie zu beenden — die Minuten laufen dann in die Arbeitszeit UND
/// verfälschen die gelernte Fahrzeit zum nächsten Besuch.
///
/// Web-App-Grenze: Kein Hintergrund-GPS, keine laufenden Timer sobald der
/// Tab/Bildschirm einschläft — die Prüfung ist deshalb bewusst NICHT live,
/// sondern rekonstruiert rückwirkend beim nächsten Ereignis (Reinigung
/// abschliessen, Störung/Montage erfassen, Feierabend), aus der Distanz
/// zwischen Pausenort und aktuellem Ort.
library;

import 'package:sbs_projer_app/core/util/fahrzeit.dart';

/// Befund einer laufenden Pause.
enum PauseBefund {
  /// Kurz genug und (soweit bekannt) am selben Ort — nichts zu tun.
  unauffaellig,

  /// Deutliche Distanz zum Pausenort — Daniel war seither unterwegs.
  bewegt,

  /// Am selben Ort (oder Distanz unbekannt), aber schon sehr lange am Laufen.
  zuLang,
}

/// Ab dieser Distanz (km) gilt eine Bewegung als echt — darunter ist es
/// GPS-Rauschen oder ein Gang ums Haus.
const double kPauseBewegtSchwelleKm = 0.5;

/// Prüft eine laufende Pause anhand der Distanz zum aktuellen Ort und der
/// bisherigen Dauer.
///
/// [distanzKm] ist die Luftlinie zwischen dem Pausenort und dem aktuellen
/// Ort; `null`, wenn keiner der beiden Punkte (oder beide) unbekannt sind.
///
/// Regeln:
/// - Distanz über [kPauseBewegtSchwelleKm]: `bewegt`. Das vorgeschlagene
///   Ende ist «jetzt minus geschätzte Fahrzeit» für diese Distanz, aber nie
///   vor dem Pausenbeginn und nie nach jetzt.
/// - Sonst, wenn die Pause länger als [maxPauseMinuten] läuft: `zuLang`,
///   Vorschlag = Pausenbeginn + [maxPauseMinuten].
/// - Sonst `unauffaellig` (kein Vorschlag).
({PauseBefund befund, int? endeMinuten}) pausePruefen({
  required int pauseStartMinuten,
  required int jetztMinuten,
  required double? distanzKm,
  int maxPauseMinuten = 90,
}) {
  if (distanzKm != null && distanzKm > kPauseBewegtSchwelleKm) {
    final fahrzeit = heuristikMinuten(
      luftlinieKm: distanzKm,
      mitRuestzeit: false,
    );
    var ende = jetztMinuten - fahrzeit;
    if (ende < pauseStartMinuten) ende = pauseStartMinuten;
    if (ende > jetztMinuten) ende = jetztMinuten;
    return (befund: PauseBefund.bewegt, endeMinuten: ende);
  }

  if (jetztMinuten - pauseStartMinuten > maxPauseMinuten) {
    return (
      befund: PauseBefund.zuLang,
      endeMinuten: pauseStartMinuten + maxPauseMinuten,
    );
  }

  return (befund: PauseBefund.unauffaellig, endeMinuten: null);
}
