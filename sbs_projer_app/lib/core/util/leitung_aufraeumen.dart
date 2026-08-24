import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';

/// Leitungen, die nach dem Löschen von [standServerId] lokal nachgezogen
/// werden müssen — Ziel-Stand und Gerätezeile genullt.
///
/// **Warum es das braucht:** Serverseitig regelt der FK
/// `event_leitungen.stand_id → event_staende` mit `ON DELETE SET NULL` den
/// Fall selbst (ebenso `stand_anlage_id`). Die **lokale Isar-Kopie** erfährt
/// davon aber nichts: Sie zeigt weiter auf den verschwundenen Stand, bis ein
/// inkrementeller Pull die Zeile zufällig wieder mitbringt. Bis dahin nennt
/// die App — namentlich die Nummernsuche und die Gegenrichtung «7, 9 ←
/// Anstich A» auf der Stand-Karte — ein Ziel, das es nicht mehr gibt. Genau
/// das ist im Feld die falsche Auskunft ans Pikett.
///
/// Die zurückgegebenen Objekte sind **dieselben Instanzen** aus [alle], bereits
/// bereinigt — der Aufrufer schreibt sie nur noch in Isar zurück.
///
/// `isSynced` bleibt bewusst unangetastet: Der Server hat die Änderung schon
/// vollzogen, ein erneuter Push wäre grundlos.
///
/// Gefunden im Review zu v0.87.0 (F4, Web nicht betroffen — dort kennt die
/// App keine lokalen Kopien), behoben am 24.08.2026.
List<EventLeitungLocal> leitungenNachStandLoeschung(
  List<EventLeitungLocal> alle,
  String standServerId,
) {
  final betroffen =
      alle.where((l) => l.standId == standServerId).toList();
  for (final l in betroffen) {
    l.standId = null;
    l.standAnlageId = null;
  }
  return betroffen;
}
