import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_kategorie.dart';

/// Kennung für «Ohne Kategorie» in Chip-Zeile und Filter (kein echter
/// Kategorie-Schlüssel).
const kOhneKategorie = 'ohne';

/// Ein Chip der Kategorie-Zeile auf dem Material-Screen.
class KategorieChip {
  /// Kategorie-ID oder [kOhneKategorie].
  final String id;
  final String name;
  final int anzahl;

  const KategorieChip({
    required this.id,
    required this.name,
    required this.anzahl,
  });
}

/// Nur Kategorien, die in [materialien] vorkommen, nach `sortierung` (dann
/// Name); am Ende «Ohne Kategorie», wenn es Artikel ohne kategorieId gibt.
///
/// Leere Kategorien fehlen bewusst: Ein Chip, der zu «0 Ergebnisse» führt,
/// kostet in einer horizontal scrollenden Zeile nur Platz.
List<KategorieChip> kategorieChips(
  List<MaterialKategorie> kategorien,
  List<Lager> materialien,
) {
  final zaehler = <String, int>{};
  var ohne = 0;
  for (final m in materialien) {
    final id = m.kategorieId;
    if (id == null) {
      ohne++;
    } else {
      zaehler[id] = (zaehler[id] ?? 0) + 1;
    }
  }

  final belegt = kategorien.where((k) => zaehler.containsKey(k.id)).toList()
    ..sort((a, b) {
      final s = a.sortierung.compareTo(b.sortierung);
      return s != 0 ? s : a.name.compareTo(b.name);
    });

  return [
    for (final k in belegt)
      KategorieChip(id: k.id, name: k.name, anzahl: zaehler[k.id]!),
    if (ohne > 0)
      KategorieChip(id: kOhneKategorie, name: 'Ohne Kategorie', anzahl: ohne),
  ];
}

/// Gewählte Kategorie nur, wenn sie noch als Chip existiert (Zombie-Schutz),
/// sonst null.
///
/// WARUM nicht einfach übernehmen: Eine gemerkte Kategorie, deren letzter
/// Artikel inzwischen umgehängt wurde, hätte keinen Chip mehr — der Filter
/// wäre aktiv, aber nirgends sichtbar abwählbar, und die Liste bliebe leer.
String? wirksameKategorie(String? gewaehlt, List<KategorieChip> chips) {
  if (gewaehlt == null) return null;
  return chips.any((c) => c.id == gewaehlt) ? gewaehlt : null;
}

class MaterialFilter {
  final String suche;

  /// Kategorie-ID, [kOhneKategorie] oder null (= alle).
  final String? kategorieId;
  final bool nurNiedrig;

  /// Artikel-IDs, die der Niedrig-Filter nicht ausblendet.
  ///
  /// WARUM: Auf der Karte hebt «+» einen Artikel über den Mindestbestand.
  /// Verschwände er nach dem Neuladen aus der Niedrig-Auswahl, rückte der
  /// nächste Artikel an dieselbe Stelle — und der nächste schnelle Tipp
  /// landete auf dessen «+». Der Screen führt hier, was auf ihm geändert
  /// wurde, bis der Filter wechselt.
  final Set<String> behalten;

  const MaterialFilter({
    this.suche = '',
    this.kategorieId,
    this.nurNiedrig = false,
    this.behalten = const {},
  });
}

/// Filtert (Suche über name/dboNr/sapNr/beschreibung/notizen/lieferant,
/// case-insensitiv; kategorieId == [kOhneKategorie] → nur Artikel ohne
/// Kategorie; nurNiedrig → bestandNiedrig == true) und sortiert: mit DBO
/// zuerst (nach DBO), ohne DBO danach nach Name.
List<Lager> filtereMaterial(List<Lager> alle, MaterialFilter f) {
  final query = f.suche.trim().toLowerCase();
  bool enthaelt(String? feld) => feld?.toLowerCase().contains(query) ?? false;

  final treffer = alle.where((l) {
    if (f.nurNiedrig &&
        l.bestandNiedrig != true &&
        !f.behalten.contains(l.id)) {
      return false;
    }
    final kat = f.kategorieId;
    if (kat == kOhneKategorie) {
      if (l.kategorieId != null) return false;
    } else if (kat != null && l.kategorieId != kat) {
      return false;
    }
    if (query.isEmpty) return true;
    return enthaelt(l.name) ||
        enthaelt(l.dboNr) ||
        enthaelt(l.sapNr) ||
        enthaelt(l.beschreibung) ||
        enthaelt(l.notizen) ||
        enthaelt(l.lieferant);
  }).toList();

  treffer.sort((a, b) {
    final aDbo = a.dboNr ?? '';
    final bDbo = b.dboNr ?? '';
    if (aDbo.isEmpty && bDbo.isEmpty) return a.name.compareTo(b.name);
    if (aDbo.isEmpty) return 1;
    if (bDbo.isEmpty) return -1;
    return aDbo.compareTo(bDbo);
  });
  return treffer;
}
