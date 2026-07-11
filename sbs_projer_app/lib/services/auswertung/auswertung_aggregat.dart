import 'auswertung_modell.dart';

/// Gesamt-Aggregat: Jahr → Monat → Werte, mit Auswertungs-Reduktionen.
class AuswertungDaten {
  final Map<int, Map<int, MonatsWerte>> proJahrMonat;
  const AuswertungDaten(this.proJahrMonat);

  /// Alle Jahre mit Daten, aufsteigend.
  List<int> get jahre => proJahrMonat.keys.toList()..sort();

  MonatsWerte? monat(int jahr, int monat) => proJahrMonat[jahr]?[monat];

  /// Alle 12 Monate eines Jahres (fehlende als Leer-Monat).
  List<MonatsWerte> monateVon(int jahr) => List.generate(
        12,
        (i) => proJahrMonat[jahr]?[i + 1] ?? MonatsWerte(jahr, i + 1, const {}),
      );

  /// Jahres-Aggregat (alle Monate summiert, monat = 0).
  MonatsWerte jahresWerte(int jahr) {
    final acc = <AuswertungKategorie, KategorieWert>{};
    for (final m in proJahrMonat[jahr]?.values ?? const <MonatsWerte>[]) {
      m.kategorien.forEach((k, w) {
        final cur = acc[k] ?? KategorieWert.leer;
        acc[k] = KategorieWert(
          cur.anzahl + w.anzahl,
          cur.netto + w.netto,
          cur.brutto + w.brutto,
        );
      });
    }
    return MonatsWerte(jahr, 0, acc);
  }

  /// Ein Monat (1..12) über alle Jahre: jahr → Werte (nur Jahre mit Daten).
  Map<int, MonatsWerte> monatsvergleich(int monat) => {
        for (final j in jahre)
          if (proJahrMonat[j]?[monat] != null) j: proJahrMonat[j]![monat]!,
      };
}

/// Gruppiert normalisierte Posten zu [AuswertungDaten].
AuswertungDaten aggregiere(Iterable<ArbeitsPosten> posten) {
  final map = <int, Map<int, Map<AuswertungKategorie, KategorieWert>>>{};
  for (final p in posten) {
    final jm = map.putIfAbsent(p.jahr, () => {});
    final km = jm.putIfAbsent(p.monat, () => {});
    km[p.kategorie] = (km[p.kategorie] ?? KategorieWert.leer).plus(p.netto, p.brutto);
  }
  return AuswertungDaten({
    for (final j in map.entries)
      j.key: {
        for (final m in j.value.entries) m.key: MonatsWerte(j.key, m.key, m.value),
      },
  });
}
