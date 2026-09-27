import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart' as mr;
import 'package:sbs_projer_app/core/util/offene_pro_betrieb.dart' as opb;
import 'package:sbs_projer_app/core/util/rechnung_status.dart';
import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Welche Rechnung darf eine Bankzahlung bekommen, und wie heisst ihr Status?
///
/// WARUM (Analyse 25.09.2026, R2/R4): Der Bankabgleich nahm nur `offen` und
/// `gesendet` einer `kundenrechnung`. Gemahnte Rechnungen und
/// Jahresrechnungen wären nie per Bank bezahlbar gewesen — die Zahlung wäre
/// als «unbekannte Gutschrift» liegen geblieben.
///
/// Seit Migration 211 (27.09.2026) sagt `zahlungsstatus` nur noch
/// offen/bezahlt/abgeschrieben; Zustellung, Mahnstufe und Heineken-Freigabe
/// sind Felder. Die Regeltests unten bauen jede Anzeige aus FELDERN.
void main() {
  Rechnung rg({String status = 'offen', String typ = 'kundenrechnung'}) =>
      Rechnung(
        id: 'r1',
        userId: 'u1',
        rechnungsnummer: 'R-1',
        rechnungstyp: typ,
        rechnungsdatum: DateTime(2026, 9, 1),
        faelligkeitsdatum: DateTime(2026, 10, 1),
        betragBrutto: 100,
        zahlungsstatus: status,
      );

  group('istZahlbar', () {
    test('offene Kunden- und Jahresrechnung ist zahlbar', () {
      expect(istZahlbar(rg()), isTrue);
      expect(istZahlbar(rg(typ: 'jahresrechnung')), isTrue);
    });

    test('gemahnt oder zugestellt ändert nichts (nur Felder)', () {
      final r = Rechnung(
        id: 'r1',
        userId: 'u1',
        rechnungstyp: 'kundenrechnung',
        rechnungsdatum: DateTime(2026, 9, 1),
        faelligkeitsdatum: DateTime(2026, 10, 1),
        mahnungStufe: 3,
        versendetAm: DateTime(2026, 9, 2),
      );
      expect(istZahlbar(r), isTrue);
    });

    for (final s in ['bezahlt', 'abgeschrieben']) {
      test('Kundenrechnung «$s» ist nicht zahlbar', () {
        expect(istZahlbar(rg(status: s)), isFalse);
      });
    }

    test('Heineken-Monatsrechnung nie — sie hat ihren eigenen Weg', () {
      for (final s in Zahlungsstatus.alle) {
        expect(istZahlbar(rg(status: s, typ: 'heineken_monat')), isFalse,
            reason: s);
      }
    });

    test('unbekannter Status und Altwerte sind nicht zahlbar (Positivliste)',
        () {
      for (final s in Zahlungsstatus.altwerte) {
        expect(istZahlbar(rg(status: s)), isFalse, reason: s);
      }
    });

    test('Status-Listen decken den DB-CHECK vollständig ab', () {
      expect(kZahlbareStatus.intersection(kErledigteStatus), isEmpty);
      expect({...kZahlbareStatus, ...kErledigteStatus}, Zahlungsstatus.alle);
    });
  });

  group('istOffen nutzt dieselbe Quelle', () {
    test('offene_pro_betrieb liefert dieselbe Funktion', () {
      expect(identical(opb.istOffen, istOffen), isTrue);
      expect(identical(opb.kErledigteStatus, kErledigteStatus), isTrue);
      expect(opb.istOffen(rg()), isTrue);
      expect(opb.istOffen(rg(status: 'abgeschrieben')), isFalse);
    });

    test('istZugestellt: mahnregeln liefert dieselbe Funktion (M2)', () {
      expect(identical(mr.istZugestellt, istZugestellt), isTrue);
    });

    test('jede zahlbare Rechnung ist offen', () {
      for (final s in kZahlbareStatus) {
        expect(istOffen(rg(status: s)), isTrue, reason: s);
      }
    });
  });

  group('anzeigeStatus — aus Feldern (Migration 211)', () {
    Rechnung mit({
      String status = 'offen',
      String typ = 'kundenrechnung',
      int stufe = 0,
      DateTime? versendet,
      DateTime? uebergeben,
      DateTime? freigegeben,
      String? versandart,
    }) =>
        Rechnung(
          id: 'r1',
          userId: 'u1',
          rechnungsnummer: 'R-1',
          rechnungstyp: typ,
          rechnungsdatum: DateTime(2026, 9, 1),
          faelligkeitsdatum: DateTime(2026, 10, 1),
          betragBrutto: 100,
          zahlungsstatus: status,
          mahnungStufe: stufe,
          versendetAm: versendet,
          uebergebenAm: uebergeben,
          freigegebenAm: freigegeben,
          versandart: versandart,
        );
    final tag = DateTime(2026, 9, 2);

    // Review M2: 257 offene Tresen-Rechnungen ohne uebergeben_am standen als
    // «Nicht zugestellt» in der Liste, während der Mahnlauf sie mahnte.
    test('Tresen ohne Übergabedatum gilt als übergeben (wie im Mahnwesen)', () {
      final r = mit(versandart: 'rechnung_tresen');
      expect(anzeigeStatus(r), 'Übergeben');
      expect(anzeigeSchluessel(r), RechnungAnzeige.uebergeben);
      expect(istZugestellt(r), isTrue);
    });

    test('Mail/Post ohne Versanddatum bleibt «Nicht zugestellt»', () {
      for (final art in ['rechnung_mail', 'rechnung_post', null]) {
        final r = mit(versandart: art);
        expect(anzeigeSchluessel(r), RechnungAnzeige.nichtZugestellt,
            reason: '$art');
        expect(istZugestellt(r), isFalse, reason: '$art');
      }
    });

    test('Anzeige und istZugestellt sagen dasselbe (EINE Wahrheit)', () {
      const zugestellt = {RechnungAnzeige.gesendet, RechnungAnzeige.uebergeben};
      for (final art in ['rechnung_tresen', 'rechnung_mail', null]) {
        for (final v in [null, tag]) {
          for (final u in [null, tag]) {
            final r = mit(versandart: art, versendet: v, uebergeben: u);
            expect(
              zugestellt.contains(anzeigeSchluessel(r)),
              istZugestellt(r),
              reason: '$art/$v/$u',
            );
          }
        }
      }
    });
    test('bezahlt und abgeschrieben gehen allem vor', () {
      // Auch mit Mahnstufe, Versand und Freigabe: erledigt ist erledigt.
      final b = mit(status: 'bezahlt', stufe: 3, versendet: tag);
      expect(anzeigeStatus(b), 'Bezahlt');
      expect(anzeigeSchluessel(b), RechnungAnzeige.bezahlt);
      final a = mit(status: 'abgeschrieben', stufe: 3, versendet: tag);
      expect(anzeigeStatus(a), 'Abgeschrieben');
      expect(anzeigeSchluessel(a), RechnungAnzeige.abgeschrieben);
      final h = mit(
        status: 'bezahlt',
        typ: 'heineken_monat',
        versendet: tag,
        freigegeben: tag,
      );
      expect(anzeigeSchluessel(h), RechnungAnzeige.bezahlt);
    });

    test('Mahnstufe aus mahnung_stufe (1 erinnert, 2 1. Mahnung, 3 letzte)',
        () {
      expect(anzeigeStatus(mit(stufe: 1, versendet: tag)), 'Erinnert');
      expect(anzeigeStatus(mit(stufe: 2, versendet: tag)), '1. Mahnung');
      expect(anzeigeStatus(mit(stufe: 3, versendet: tag)), 'Letzte Mahnung');
      expect(anzeigeSchluessel(mit(stufe: 2)), RechnungAnzeige.mahnung1);
    });

    test('Mahnstufe geht Zustellung vor', () {
      final r = mit(stufe: 1, versendet: tag, uebergeben: tag);
      expect(anzeigeSchluessel(r), RechnungAnzeige.erinnert);
    });

    test('Stufe ausserhalb 0–3 wird geklemmt', () {
      expect(anzeigeSchluessel(mit(stufe: 7)), RechnungAnzeige.mahnung2);
      expect(anzeigeSchluessel(mit(stufe: -1)), RechnungAnzeige.nichtZugestellt);
      expect(mahnstufeVon(mit(stufe: 7)), 3);
    });

    test('Heineken: freigegeben aus freigegeben_am', () {
      final r = mit(typ: 'heineken_monat', versendet: tag, freigegeben: tag);
      expect(anzeigeStatus(r), 'Freigegeben');
      expect(anzeigeSchluessel(r), RechnungAnzeige.freigegeben);
    });

    test('Heineken: gesendet und nicht zugestellt wie alle anderen', () {
      expect(
        anzeigeStatus(mit(typ: 'heineken_monat', versendet: tag)),
        'Gesendet',
      );
      expect(
        anzeigeStatus(mit(typ: 'heineken_monat')),
        'Nicht zugestellt',
      );
    });

    test('gesendet aus versendet_am', () {
      final r = mit(versendet: tag);
      expect(anzeigeStatus(r), 'Gesendet');
      expect(anzeigeSchluessel(r), RechnungAnzeige.gesendet);
    });

    test('übergeben aus uebergeben_am', () {
      final r = mit(uebergeben: tag);
      expect(anzeigeStatus(r), 'Übergeben');
      expect(anzeigeSchluessel(r), RechnungAnzeige.uebergeben);
    });

    test('versendet geht übergeben vor', () {
      expect(anzeigeStatus(mit(versendet: tag, uebergeben: tag)), 'Gesendet');
    });

    test('sonst «Nicht zugestellt» — nicht mehr das missverständliche «Offen»',
        () {
      final r = mit();
      expect(anzeigeStatus(r), 'Nicht zugestellt');
      expect(anzeigeSchluessel(r), RechnungAnzeige.nichtZugestellt);
    });

    test('unbekannter Status und Altwerte kommen roh durch — sichtbar', () {
      expect(anzeigeStatus(mit(status: 'storniert', versendet: tag)),
          'storniert');
      // Ein `gesendet` kann nach 211 nicht mehr in der DB stehen (CHECK);
      // stünde es doch da, soll es auffallen statt still als «Gesendet».
      expect(anzeigeSchluessel(mit(status: 'gesendet')), 'gesendet');
    });

    test('jeder Anzeige-Schlüssel hat einen deutschen Text', () {
      for (final k in RechnungAnzeige.alle) {
        final text = anzeigeTextFuer(k);
        expect(text, isNot(k), reason: 'roher Schlüssel «$k» statt Text');
        expect(text, isNotEmpty);
      }
    });

    test('jede Rechnung aus gültigen Feldern bekommt einen bekannten Schlüssel',
        () {
      for (final s in Zahlungsstatus.alle) {
        for (final stufe in [0, 1, 2, 3]) {
          for (final v in [null, tag]) {
            for (final f in [null, tag]) {
              final k = anzeigeSchluessel(
                mit(status: s, stufe: stufe, versendet: v, freigegeben: f),
              );
              expect(RechnungAnzeige.alle, contains(k),
                  reason: '$s/$stufe/$v/$f');
            }
          }
        }
      }
    });
  });

  group('istGemahnt', () {
    Rechnung r({String status = 'offen', int stufe = 0}) => Rechnung(
          id: 'r1',
          userId: 'u1',
          rechnungstyp: 'kundenrechnung',
          rechnungsdatum: DateTime(2026, 9, 1),
          faelligkeitsdatum: DateTime(2026, 10, 1),
          zahlungsstatus: status,
          mahnungStufe: stufe,
        );

    test('offen mit Stufe > 0', () {
      expect(istGemahnt(r(stufe: 1)), isTrue);
      expect(istGemahnt(r()), isFalse);
    });

    test('bezahlt nach Mahnung ist nicht mehr «gemahnt»', () {
      expect(istGemahnt(r(status: 'bezahlt', stufe: 3)), isFalse);
    });
  });

  group('naechsteMahnAktion — Kurzsymbol der Liste (Entscheid 3a)', () {
    Rechnung r({
      String status = 'offen',
      String typ = 'kundenrechnung',
      int stufe = 0,
      DateTime? versendet,
      DateTime? uebergeben,
      DateTime? datum,
      String? versandart,
      DateTime? zahlungEingegangen,
      double? zahlungBetrag,
    }) =>
        Rechnung(
          id: 'r1',
          userId: 'u1',
          rechnungstyp: typ,
          rechnungsdatum: datum ?? DateTime(2026, 9, 1),
          faelligkeitsdatum: DateTime(2026, 10, 1),
          zahlungsstatus: status,
          mahnungStufe: stufe,
          versendetAm: versendet,
          uebergebenAm: uebergeben,
          versandart: versandart,
          zahlungEingegangenAm: zahlungEingegangen,
          zahlungBetrag: zahlungBetrag,
        );
    final tag = DateTime(2026, 9, 2);

    // Review K3: ~114 Altrechnungen vor kMahnStart boten ein Mahnsymbol an.
    test('nur im Mahnbereich: Altrechnung vor 2026 → kein Symbol', () {
      expect(
        naechsteMahnAktion(r(datum: DateTime(2025, 12, 31), versendet: tag)),
        isNull,
      );
      expect(
        naechsteMahnAktion(
          r(datum: DateTime(2025, 6, 1), stufe: 2, versendet: tag),
        ),
        isNull,
      );
      expect(
        naechsteMahnAktion(r(datum: DateTime(2026, 1, 1), versendet: tag)),
        RechnungAnzeige.erinnert,
      );
    });

    test('vermerkter Zahlungseingang → kein Symbol (wie der Mahnlauf)', () {
      expect(
        naechsteMahnAktion(r(versendet: tag, zahlungEingegangen: tag)),
        isNull,
      );
      expect(naechsteMahnAktion(r(versendet: tag, zahlungBetrag: 50)), isNull);
    });

    test('Tresen ohne Übergabedatum ist zugestellt → Erinnerung (M2)', () {
      expect(
        naechsteMahnAktion(r(versandart: 'rechnung_tresen')),
        RechnungAnzeige.erinnert,
      );
    });

    test('jede zugestellte offene Rechnung → Erinnerung (auch gesendete)', () {
      expect(naechsteMahnAktion(r(versendet: tag)), RechnungAnzeige.erinnert);
      expect(naechsteMahnAktion(r(uebergeben: tag)), RechnungAnzeige.erinnert);
      expect(
        naechsteMahnAktion(r(typ: 'jahresrechnung', versendet: tag)),
        RechnungAnzeige.erinnert,
      );
    });

    test('Stufe für Stufe weiter, nach der letzten ins Abschreiben', () {
      expect(naechsteMahnAktion(r(stufe: 1, versendet: tag)),
          RechnungAnzeige.mahnung1);
      expect(naechsteMahnAktion(r(stufe: 2, versendet: tag)),
          RechnungAnzeige.mahnung2);
      expect(naechsteMahnAktion(r(stufe: 3, versendet: tag)),
          RechnungAnzeige.abgeschrieben);
    });

    test('nicht zugestellt, erledigt oder Heineken: kein Symbol', () {
      expect(naechsteMahnAktion(r()), isNull);
      expect(naechsteMahnAktion(r(status: 'bezahlt', versendet: tag)), isNull);
      expect(
        naechsteMahnAktion(r(status: 'abgeschrieben', versendet: tag)),
        isNull,
      );
      expect(
        naechsteMahnAktion(r(typ: 'heineken_monat', versendet: tag)),
        isNull,
      );
    });
  });

  group('heinekenStufe — Monatsprüfung aus Feldern', () {
    final tag = DateTime(2026, 9, 2);

    test('offen → gesendet → freigegeben → bezahlt', () {
      expect(heinekenStufe(zahlungsstatus: 'offen'), 'offen');
      expect(heinekenStufe(zahlungsstatus: 'offen', versendetAm: tag),
          'gesendet');
      expect(
        heinekenStufe(
            zahlungsstatus: 'offen', versendetAm: tag, freigegebenAm: tag),
        'freigegeben',
      );
      expect(
        heinekenStufe(
            zahlungsstatus: 'bezahlt', versendetAm: tag, freigegebenAm: tag),
        'bezahlt',
      );
    });

    test('Freigabe ohne Versanddatum zählt als freigegeben (Altbestand)', () {
      expect(heinekenStufe(zahlungsstatus: 'offen', freigegebenAm: tag),
          'freigegeben');
    });
  });

  group('versendetAmNachVersand — das Erstversanddatum bleibt', () {
    final jetzt = DateTime(2026, 9, 27, 14, 30);

    test('erster Versand: heute', () {
      expect(versendetAmNachVersand(null, jetzt), jetzt);
    });

    test('Neuversand: das Datum des ersten Versands bleibt', () {
      final erst = DateTime(2026, 8, 3);
      expect(versendetAmNachVersand(erst, jetzt), erst);
    });

    test('auch ein Neuversand am selben Tag ändert nichts', () {
      final erst = DateTime(2026, 9, 27);
      expect(versendetAmNachVersand(erst, jetzt), erst);
    });
  });

  group('Zahlungsstatus — gespeicherte Stände von vor Migration 211', () {
    test('ausGespeichert: Altwert oder fehlend → offen, gültig bleibt', () {
      for (final alt in ['gesendet', 'erinnert', 'mahnung_2', 'freigegeben']) {
        expect(Zahlungsstatus.ausGespeichert(alt), 'offen', reason: alt);
      }
      expect(Zahlungsstatus.ausGespeichert(null), 'offen');
      expect(Zahlungsstatus.ausGespeichert('bezahlt'), 'bezahlt');
    });

    test('stufeAusAltwert wie rechnung_stufe_aus_altstatus (SQL 211)', () {
      expect(Zahlungsstatus.stufeAusAltwert('erinnert'), 1);
      expect(Zahlungsstatus.stufeAusAltwert('mahnung_1'), 2);
      expect(Zahlungsstatus.stufeAusAltwert('mahnung_2'), 3);
      expect(Zahlungsstatus.stufeAusAltwert('gesendet'), 0);
      expect(Zahlungsstatus.stufeAusAltwert(null), 0);
    });
  });
}
