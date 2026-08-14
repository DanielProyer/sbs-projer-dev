import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/events/typenschild_service.dart';

void main() {
  group('TypenschildErgebnis.fromJson', () {
    test('vollstaendige Antwort wird gelesen', () {
      final ergebnis = TypenschildErgebnis.fromJson({
        'hersteller': 'Lindr',
        'typ_bezeichnung': 'KONTAKT 40/K',
        'seriennummer': '2024-1234',
        'baujahr': 2024,
        'unsicher_bei': <String>[],
        'sicherheit': 'hoch',
      });

      expect(ergebnis.hersteller, 'Lindr');
      expect(ergebnis.typBezeichnung, 'KONTAKT 40/K');
      expect(ergebnis.seriennummer, '2024-1234');
      expect(ergebnis.baujahr, 2024);
      expect(ergebnis.unsicherBei, isEmpty);
      expect(ergebnis.sicherheit, 'hoch');
    });

    test('sparse Antwort: unlesbare Felder null, unsicher_bei gefuellt', () {
      final ergebnis = TypenschildErgebnis.fromJson({
        'hersteller': 'Lindr',
        'typ_bezeichnung': null,
        'seriennummer': null,
        'baujahr': null,
        'unsicher_bei': ['typ_bezeichnung', 'seriennummer'],
        'sicherheit': 'tief',
      });

      expect(ergebnis.hersteller, 'Lindr');
      expect(ergebnis.typBezeichnung, isNull);
      expect(ergebnis.seriennummer, isNull);
      expect(ergebnis.baujahr, isNull);
      expect(ergebnis.unsicherBei, ['typ_bezeichnung', 'seriennummer']);
      expect(ergebnis.sicherheit, 'tief');
    });

    test('fehlende Felder fallen auf Default zurueck statt zu crashen', () {
      final ergebnis = TypenschildErgebnis.fromJson(<String, dynamic>{});

      expect(ergebnis.hersteller, isNull);
      expect(ergebnis.typBezeichnung, isNull);
      expect(ergebnis.seriennummer, isNull);
      expect(ergebnis.baujahr, isNull);
      expect(ergebnis.unsicherBei, isEmpty);
      expect(ergebnis.sicherheit, 'tief');
    });

    test('baujahr als String wird geparst', () {
      final ergebnis = TypenschildErgebnis.fromJson({'baujahr': '2019'});
      expect(ergebnis.baujahr, 2019);
    });

    test('numerische Seriennummer crasht nicht (Normalfall auf Typenschildern)', () {
      final ergebnis = TypenschildErgebnis.fromJson({
        'seriennummer': 12345,
        'baujahr': 2019,
      });
      expect(ergebnis.seriennummer, '12345');
      expect(ergebnis.baujahr, 2019);
    });

    test('echte Function-Response mit verbrauch + unbekanntem Feld wird toleriert', () {
      final ergebnis = TypenschildErgebnis.fromJson({
        'hersteller': 'Lindr',
        'typ_bezeichnung': 'KONTAKT 40/K',
        'seriennummer': 987654,
        'baujahr': 2022,
        'unsicher_bei': <String>[],
        'sicherheit': 'hoch',
        'verbrauch': {'input_tokens': 1423, 'output_tokens': 87},
        'irgendein_neues_feld': 'unbekannt',
      });

      expect(ergebnis.hersteller, 'Lindr');
      expect(ergebnis.typBezeichnung, 'KONTAKT 40/K');
      expect(ergebnis.seriennummer, '987654');
      expect(ergebnis.baujahr, 2022);
      expect(ergebnis.unsicherBei, isEmpty);
      expect(ergebnis.sicherheit, 'hoch');
    });
  });

  group('vorschlagTyp', () {
    test('beide Felder gesetzt -> zusammengefuegt', () {
      const ergebnis = TypenschildErgebnis(
        hersteller: 'Lindr',
        typBezeichnung: 'KONTAKT 40/K',
      );
      expect(ergebnis.vorschlagTyp(), 'Lindr KONTAKT 40/K');
    });

    test('nur Hersteller gesetzt', () {
      const ergebnis = TypenschildErgebnis(hersteller: 'Lindr');
      expect(ergebnis.vorschlagTyp(), 'Lindr');
    });

    test('nur Typbezeichnung gesetzt', () {
      const ergebnis = TypenschildErgebnis(typBezeichnung: 'KONTAKT 40/K');
      expect(ergebnis.vorschlagTyp(), 'KONTAKT 40/K');
    });

    test('keines gesetzt -> null', () {
      const ergebnis = TypenschildErgebnis();
      expect(ergebnis.vorschlagTyp(), isNull);
    });
  });

  group('toJson', () {
    test('Roundtrip: fromJson(toJson(x)) liefert dieselben Werte', () {
      final original = TypenschildErgebnis.fromJson({
        'hersteller': 'Lindr',
        'typ_bezeichnung': 'KONTAKT 40/K',
        'seriennummer': '2024-1234',
        'baujahr': 2024,
        'unsicher_bei': ['baujahr'],
        'sicherheit': 'mittel',
      });

      final rekonstruiert = TypenschildErgebnis.fromJson(original.toJson());

      expect(rekonstruiert.hersteller, original.hersteller);
      expect(rekonstruiert.typBezeichnung, original.typBezeichnung);
      expect(rekonstruiert.seriennummer, original.seriennummer);
      expect(rekonstruiert.baujahr, original.baujahr);
      expect(rekonstruiert.unsicherBei, original.unsicherBei);
      expect(rekonstruiert.sicherheit, original.sicherheit);
    });

    test('toJson enthaelt die Snake-Case-Schluessel der Edge Function', () {
      const ergebnis = TypenschildErgebnis(
        hersteller: 'Lindr',
        baujahr: 2024,
        unsicherBei: ['seriennummer'],
        sicherheit: 'mittel',
      );

      final json = ergebnis.toJson();

      expect(json['hersteller'], 'Lindr');
      expect(json['typ_bezeichnung'], isNull);
      expect(json['seriennummer'], isNull);
      expect(json['baujahr'], 2024);
      expect(json['unsicher_bei'], ['seriennummer']);
      expect(json['sicherheit'], 'mittel');
    });
  });
}
