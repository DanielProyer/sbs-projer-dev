import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/material_filter.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/data/models/material_kategorie.dart';

/// Filter- und Chip-Logik des Material-Screens (Kategorie-Chips in einer
/// Zeile statt Dropdown, 27.09.2026).

MaterialKategorie _kat(String id, String name, int sortierung) =>
    MaterialKategorie(id: id, userId: 'u', name: name, sortierung: sortierung);

Lager _lager(
  String id,
  String name, {
  String? kategorieId,
  String? dboNr,
  String? sapNr,
  String? beschreibung,
  String? notizen,
  String? lieferant,
  bool? niedrig,
}) =>
    Lager(
      id: id,
      userId: 'u',
      name: name,
      kategorieId: kategorieId,
      dboNr: dboNr,
      sapNr: sapNr,
      beschreibung: beschreibung,
      notizen: notizen,
      lieferant: lieferant,
      bestandNiedrig: niedrig,
    );

void main() {
  // Einfüge-Reihenfolge absichtlich anders als die Sortierung.
  final kategorien = [
    _kat('k-reiniger', 'Reiniger', 30),
    _kat('k-hahn', 'Zapfhahn', 10),
    _kat('k-leer', 'Unbenutzt', 5),
    _kat('k-dicht', 'Dichtungen', 20),
  ];

  group('kategorieChips', () {
    test('nur belegte Kategorien, nach Sortierung, mit Zählern', () {
      final materialien = [
        _lager('1', 'A', kategorieId: 'k-reiniger'),
        _lager('2', 'B', kategorieId: 'k-hahn'),
        _lager('3', 'C', kategorieId: 'k-hahn'),
        _lager('4', 'D', kategorieId: 'k-dicht'),
      ];
      final chips = kategorieChips(kategorien, materialien);
      expect(chips.map((c) => c.id), ['k-hahn', 'k-dicht', 'k-reiniger']);
      expect(chips.map((c) => c.name), ['Zapfhahn', 'Dichtungen', 'Reiniger']);
      expect(chips.map((c) => c.anzahl), [2, 1, 1]);
    });

    test('gleiche Sortierung → nach Name', () {
      final chips = kategorieChips(
        [_kat('b', 'Beta', 1), _kat('a', 'Alpha', 1)],
        [_lager('1', 'x', kategorieId: 'b'), _lager('2', 'y', kategorieId: 'a')],
      );
      expect(chips.map((c) => c.name), ['Alpha', 'Beta']);
    });

    test('«Ohne Kategorie» nur wenn nötig und ganz hinten', () {
      final ohne = kategorieChips(kategorien, [
        _lager('1', 'A'),
        _lager('2', 'B', kategorieId: 'k-hahn'),
        _lager('3', 'C'),
      ]);
      expect(ohne.map((c) => c.id), ['k-hahn', kOhneKategorie]);
      expect(ohne.last.name, 'Ohne Kategorie');
      expect(ohne.last.anzahl, 2);

      final mit = kategorieChips(kategorien, [
        _lager('2', 'B', kategorieId: 'k-hahn'),
      ]);
      expect(mit.map((c) => c.id), isNot(contains(kOhneKategorie)));
    });

    test('Kategorie-ID ohne Stammsatz zählt nicht als «Ohne Kategorie»', () {
      // Verwaiste ID (Kategorie gelöscht): kein Chip, aber auch nicht still
      // unter «Ohne Kategorie» gezählt — das wäre ein falscher Zähler.
      final chips = kategorieChips(kategorien, [
        _lager('1', 'A', kategorieId: 'weg'),
      ]);
      expect(chips, isEmpty);
    });
  });

  group('wirksameKategorie', () {
    final chips = [
      const KategorieChip(id: 'k-hahn', name: 'Zapfhahn', anzahl: 2),
      const KategorieChip(id: kOhneKategorie, name: 'Ohne Kategorie', anzahl: 1),
    ];

    test('bekannte ID bleibt', () {
      expect(wirksameKategorie('k-hahn', chips), 'k-hahn');
    });

    test('unbekannte ID → null (Zombie-Schutz)', () {
      expect(wirksameKategorie('k-weg', chips), isNull);
    });

    test('kOhneKategorie bleibt, wenn der Chip existiert', () {
      expect(wirksameKategorie(kOhneKategorie, chips), kOhneKategorie);
    });

    test('kOhneKategorie ohne Chip → null', () {
      expect(wirksameKategorie(kOhneKategorie, chips.take(1).toList()), isNull);
    });

    test('null bleibt null', () {
      expect(wirksameKategorie(null, chips), isNull);
    });
  });

  group('filtereMaterial', () {
    final alle = [
      _lager('1', 'Zapfhahn Chrom', kategorieId: 'k-hahn', dboNr: '200'),
      _lager('2', 'Kompensator', kategorieId: 'k-hahn', dboNr: '100',
          niedrig: true),
      _lager('3', 'Bürste', beschreibung: 'für Leitungen'),
      _lager('4', 'Alkalireiniger', kategorieId: 'k-reiniger',
          sapNr: 'SAP-778', lieferant: 'Brauerei-Shop', niedrig: true),
      _lager('5', 'Dichtung', notizen: 'im Handschuhfach', niedrig: false),
    ];

    List<String> ids(MaterialFilter f) =>
        filtereMaterial(alle, f).map((l) => l.id).toList();

    test('ohne Filter: alle, mit DBO zuerst (nach DBO), dann nach Name', () {
      expect(ids(const MaterialFilter()), ['2', '1', '4', '3', '5']);
    });

    test('Kategorie', () {
      expect(ids(const MaterialFilter(kategorieId: 'k-hahn')), ['2', '1']);
    });

    test('Ohne Kategorie', () {
      expect(ids(const MaterialFilter(kategorieId: kOhneKategorie)),
          ['3', '5']);
    });

    test('nur niedrig', () {
      expect(ids(const MaterialFilter(nurNiedrig: true)), ['2', '4']);
    });

    test('nur niedrig: «behalten» bleibt sichtbar, auch wenn nicht mehr niedrig',
        () {
      // Wer im Niedrig-Filter auf der Karte «+» tippt, hebt den Artikel über
      // den Mindestbestand. Verschwände er nach dem Neuladen, landete der
      // nächste Tipp auf dem «+» des nachrückenden Artikels.
      expect(
        ids(const MaterialFilter(nurNiedrig: true, behalten: {'5'})),
        ['2', '4', '5'],
      );
      // Ohne Niedrig-Filter hat «behalten» keine Wirkung auf andere Kriterien.
      expect(
        ids(const MaterialFilter(kategorieId: 'k-hahn', behalten: {'5'})),
        ['2', '1'],
      );
    });

    test('Kategorie und niedrig kombiniert', () {
      expect(
        ids(const MaterialFilter(kategorieId: 'k-hahn', nurNiedrig: true)),
        ['2'],
      );
    });

    test('Suche case-insensitiv über Name', () {
      expect(ids(const MaterialFilter(suche: 'zapfHAHN')), ['1']);
    });

    test('Suche findet DBO, SAP-Nr, Lieferant, Beschreibung, Notizen', () {
      expect(ids(const MaterialFilter(suche: '100')), ['2']);
      expect(ids(const MaterialFilter(suche: 'sap-778')), ['4']);
      expect(ids(const MaterialFilter(suche: 'brauerei')), ['4']);
      expect(ids(const MaterialFilter(suche: 'leitungen')), ['3']);
      expect(ids(const MaterialFilter(suche: 'handschuh')), ['5']);
    });

    test('Suche ohne Treffer → leer', () {
      expect(ids(const MaterialFilter(suche: 'gibtsnicht')), isEmpty);
    });

    test('Eingangsliste bleibt unverändert', () {
      final kopie = List<Lager>.from(alle);
      filtereMaterial(alle, const MaterialFilter());
      expect(alle, kopie);
    });
  });
}
