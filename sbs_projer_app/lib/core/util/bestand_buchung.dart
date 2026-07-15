import 'package:sbs_projer_app/data/models/material_bestellung.dart';

/// Eine Kategorie-Gruppe für den Abhol-Dialog (gleiche Gliederung wie das
/// Bestell-PDF).
class KategorieGruppe {
  final String name;
  final List<MaterialBestellposition> positionen;
  const KategorieGruppe({required this.name, required this.positionen});
}

/// Sammelname für Positionen ohne Kategorie.
const String kUebrigeKategorie = 'Übrige';

/// True, wenn die Position auf einen Lager-Artikel gebucht werden kann.
/// Freitext-Positionen ohne `lagerId` haben keinen Lager-Bezug.
bool istBuchbar(MaterialBestellposition p) =>
    p.lagerId != null && p.lagerId!.isNotEmpty;

/// Filtert die im Kontroll-Dialog erfassten Mengen auf die tatsächlich
/// buchbaren Positionen — die Nutzlast (`p_mengen`) für die Abhol-RPC.
///
/// [mengen]: positionId → erhaltene Menge. Fehlt der Eintrag oder ist er <= 0,
/// gilt die Position als „nicht erhalten" und wird übersprungen.
///
/// Bewusst **positionId-basiert**: die RPC schreibt `menge_erhalten` pro
/// Position und bucht relativ — mehrere Positionen auf denselben Lager-Artikel
/// summieren sich dort automatisch korrekt.
Map<String, double> abholPayload({
  required List<MaterialBestellposition> positionen,
  required Map<String, double> mengen,
}) {
  final payload = <String, double>{};
  for (final p in positionen) {
    if (!istBuchbar(p)) continue;
    final menge = mengen[p.id];
    if (menge == null || menge <= 0) continue;
    payload[p.id] = menge;
  }
  return payload;
}

/// Gruppiert die Positionen nach `kategorieName` — Gruppen in der Reihenfolge
/// ihres ersten Auftretens (= Reihenfolge der Bestellung), innerhalb der Gruppe
/// die eingehende Reihenfolge. Positionen ohne Kategorie kommen als „Übrige"
/// ganz am Schluss.
List<KategorieGruppe> positionenNachKategorie(
    List<MaterialBestellposition> positionen) {
  final nachName = <String, List<MaterialBestellposition>>{};
  final uebrige = <MaterialBestellposition>[];
  for (final p in positionen) {
    final kat = p.kategorieName;
    if (kat == null || kat.isEmpty) {
      uebrige.add(p);
    } else {
      nachName.putIfAbsent(kat, () => []).add(p);
    }
  }
  final gruppen = nachName.entries
      .map((e) => KategorieGruppe(name: e.key, positionen: e.value))
      .toList();
  if (uebrige.isNotEmpty) {
    gruppen.add(KategorieGruppe(name: kUebrigeKategorie, positionen: uebrige));
  }
  return gruppen;
}
