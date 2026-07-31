import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz_betrieb_match.dart';

void main() {
  const betriebe = [
    (id: 'a', name: 'Sunset Seehotel', ort: 'Eich'),
    (id: 'b', name: 'Sunset Bar', ort: 'Chur'),
    (id: 'c', name: 'Restaurant Rössli', ort: 'Ilanz'),
    (id: 'd', name: 'Berggasthaus Arflina', ort: 'Fideris'),
    (id: 'e', name: 'Hotel Sport', ort: 'Klosters'),
    (id: 'f', name: 'Migros Golfpark', ort: 'Otelfingen'),
  ];

  group('betriebKandidaten', () {
    test('eindeutiger Name wird gefunden', () {
      final t = betriebKandidaten(
        text: 'Störung im Rössli',
        betriebe: betriebe,
      );
      expect(t.length, 1);
      expect(t.first.id, 'c');
    });

    test('Umlaute und Schreibvarianten stören nicht', () {
      // Die Spracherkennung schreibt oft "Roessli" oder "Rossli".
      expect(
        betriebKandidaten(text: 'Montage Roessli', betriebe: betriebe).first.id,
        'c',
      );
      expect(
        betriebKandidaten(text: 'Montage Rossli', betriebe: betriebe).first.id,
        'c',
      );
    });

    test('mehrdeutiger Teilname liefert mehrere Kandidaten', () {
      // "Sunset" passt auf zwei Betriebe — die App muss nachfragen,
      // statt zu raten. Ein falsch zugeordneter Betrieb heisst: umsonst
      // hingefahren.
      final t = betriebKandidaten(
        text: 'Störung beim Sunset',
        betriebe: betriebe,
      );
      expect(t.length, 2);
      expect(t.map((k) => k.id), containsAll(['a', 'b']));
    });

    test('der Ort entscheidet bei sonst gleichem Namen', () {
      final t = betriebKandidaten(
        text: 'Störung Sunset in Chur',
        betriebe: betriebe,
      );
      expect(t.first.id, 'b');
    });

    test('Gattungswörter allein reichen nicht', () {
      // "Hotel" oder "Restaurant" darf nicht irgendeinen Betrieb kapern.
      final t = betriebKandidaten(text: 'Störung im Hotel', betriebe: betriebe);
      expect(t, isEmpty);
    });

    test('kleiner Tippfehler wird verziehen', () {
      final t = betriebKandidaten(text: 'Montage Arflena', betriebe: betriebe);
      expect(t.first.id, 'd');
    });

    test('unbekannter Name ergibt keinen Treffer', () {
      expect(
        betriebKandidaten(text: 'Störung im Adler', betriebe: betriebe),
        isEmpty,
      );
    });

    test('leerer Text ergibt keinen Treffer', () {
      expect(betriebKandidaten(text: '', betriebe: betriebe), isEmpty);
      expect(betriebKandidaten(text: '   ', betriebe: betriebe), isEmpty);
    });

    test('leere Betriebsliste ergibt keinen Treffer', () {
      expect(betriebKandidaten(text: 'Rössli', betriebe: const []), isEmpty);
    });

    test('mehrteiliger Name wird als Ganzes erkannt', () {
      final t = betriebKandidaten(
        text: 'Montage im Migros Golfpark',
        betriebe: betriebe,
      );
      expect(t.first.id, 'f');
    });

    test('höchstens drei Kandidaten', () {
      final viele = [
        for (var i = 0; i < 8; i++) (id: '$i', name: 'Sonne $i', ort: 'Chur'),
      ];
      final t = betriebKandidaten(text: 'Störung Sonne', betriebe: viele);
      expect(t.length, lessThanOrEqualTo(3));
    });
  });

  group('eindeutigerBetrieb', () {
    test('genau ein Kandidat -> Id', () {
      expect(eindeutigerBetrieb(text: 'Rössli', betriebe: betriebe), 'c');
    });

    test('mehrere Kandidaten -> null (lieber nachfragen)', () {
      expect(eindeutigerBetrieb(text: 'Sunset', betriebe: betriebe), isNull);
    });

    test('kein Kandidat -> null', () {
      expect(eindeutigerBetrieb(text: 'Adler', betriebe: betriebe), isNull);
    });
  });
}
