import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/reinigung_korrektur_regel.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung _rg({
  String status = 'offen',
  DateTime? versendetAm,
  DateTime? uebergebenAm,
  DateTime? zahlungEingegangenAm,
  int mahnungStufe = 0,
  DateTime? rechnungsdatum,
  String typ = 'kundenrechnung',
}) =>
    Rechnung.fromJson({
      'id': 'r1',
      'user_id': 'u',
      'rechnungsnummer': '2026-09-26-0001',
      'rechnungstyp': typ,
      'rechnungsdatum':
          (rechnungsdatum ?? DateTime(2026, 9, 26)).toIso8601String(),
      'faelligkeitsdatum': DateTime(2026, 10, 26).toIso8601String(),
      'betrag_netto': 100,
      'mwst_betrag': 8.1,
      'betrag_brutto': 108.1,
      'zahlungsstatus': status,
      'versendet_am': versendetAm?.toIso8601String(),
      'uebergeben_am': uebergebenAm?.toIso8601String(),
      'zahlung_eingegangen_am': zahlungEingegangenAm?.toIso8601String(),
      'mahnung_stufe': mahnungStufe,
    });

ReinigungLocal _rein({
  double? grundtarif = 100,
  int eigen = 0,
  int fremd = 0,
  String? serviceTyp = 'konventionell',
  String? zahlungsart = 'rechnung_mail',
  bool kulanz = false,
  String notizen = '',
}) => ReinigungLocal()
  ..anlageId = '' // native: late — Altfall-Vergleich liest es
  ..datum = DateTime(2026, 9, 26)
  ..preisGrundtarif = grundtarif
  ..anzahlHaehneEigen = eigen
  ..anzahlHaehneFremd = fremd
  ..serviceTyp = serviceTyp
  ..zahlungsart = zahlungsart
  ..istKulanz = kulanz
  ..notizen = notizen;

void main() {
  final grenze = DateTime(2026, 1, 1);

  group('korrekturSperre', () {
    test('keine Rechnung -> keine Sperre', () {
      expect(
        korrekturSperre(rechnung: null, hatZahlungsbuchung: false,
            imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.keine,
      );
    });
    test('offen, unversendet, unbezahlt -> keine Sperre', () {
      expect(
        korrekturSperre(rechnung: _rg(), hatZahlungsbuchung: false,
            imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.keine,
      );
    });
    test('bezahlt schlaegt alles', () {
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'bezahlt', versendetAm: DateTime(2026, 9, 26)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
      expect(
        korrekturSperre(rechnung: _rg(), hatZahlungsbuchung: true,
            imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(zahlungEingegangenAm: DateTime(2026, 9, 27)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
      expect(
        korrekturSperre(rechnung: _rg(status: 'abgeschrieben'),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
    });
    test('Mahnfall vor gemahnt vor versendet', () {
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'mahnung_1', mahnungStufe: 2,
                versendetAm: DateTime(2026, 8, 1)),
            hatZahlungsbuchung: false, imMahnfall: true, nachbuchGrenze: grenze),
        KorrekturSperre.mahnfall,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'erinnert', mahnungStufe: 1,
                versendetAm: DateTime(2026, 8, 1)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.gemahnt,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(status: 'gesendet', versendetAm: DateTime(2026, 9, 26)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.versendet,
      );
      expect(
        korrekturSperre(
            rechnung: _rg(uebergebenAm: DateTime(2026, 9, 26)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.versendet,
      );
    });
    test('abgeschlossenes Jahr', () {
      expect(
        korrekturSperre(
            rechnung: _rg(rechnungsdatum: DateTime(2025, 12, 15)),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.abgeschlossenesJahr,
      );
    });
    test('sperrText nennt die Rechnungsnummer und den Ausweg', () {
      final t = sperrText(KorrekturSperre.versendet, '2026-09-26-0001');
      expect(t, contains('2026-09-26-0001'));
      expect(t, contains('Notiz'));
      expect(sperrText(KorrekturSperre.keine, null), '');
    });
  });

  group('preisrelevantGeaendert', () {
    test('nur Notiz -> false', () {
      expect(preisrelevantGeaendert(_rein(), _rein(notizen: 'Hahn tropft')), false);
    });
    test('Grundtarif, Haehne, Servicetyp, Zahlungsart, Kulanz, Datum -> true', () {
      expect(preisrelevantGeaendert(_rein(), _rein(grundtarif: 120)), true);
      expect(preisrelevantGeaendert(_rein(), _rein(eigen: 2)), true);
      expect(preisrelevantGeaendert(_rein(), _rein(fremd: 1)), true);
      expect(preisrelevantGeaendert(_rein(), _rein(serviceTyp: 'orion')), true);
      expect(preisrelevantGeaendert(_rein(), _rein(zahlungsart: 'barzahlung')), true);
      expect(preisrelevantGeaendert(_rein(), _rein(kulanz: true)), true);
      final anderesDatum = _rein()..datum = DateTime(2026, 9, 27);
      expect(preisrelevantGeaendert(_rein(), anderesDatum), true);
    });
    test('Schnappschuss ist eine Kopie, kein Verweis (r == _existing im Formular)', () {
      final r = _rein(eigen: 3, grundtarif: 90, zahlungsart: 'rechnung_mail')
        ..anlageIdsJson = '["a1","a2"]';
      final alt = preisSchnappschuss(r);
      expect(identical(alt, r), false);
      expect(preisrelevantGeaendert(alt, r), false);
      r.notizen = 'nur Notiz';
      expect(preisrelevantGeaendert(alt, r), false);
      r.anzahlHaehneEigen = 4;
      expect(preisrelevantGeaendert(alt, r), true);
      r.anzahlHaehneEigen = 3;
      r.istKulanz = true;
      expect(preisrelevantGeaendert(alt, r), true);
    });
    test('Altfall ohne anlageIdsJson vs. gleiche Anlage als JSON, nur Notiz -> false', () {
      final alt = _rein()..anlageId = 'a1';
      final neu = _rein(notizen: 'neu')
        ..anlageId = 'a1'
        ..anlageIdsJson = '["a1"]';
      expect(preisrelevantGeaendert(alt, neu), false);
      expect(anlagenMenge(neu), {'a1'});
    });
    test('Bergkunde umgeschaltet -> true (Zuschlag muss neu)', () {
      final neu = _rein()..istBergkunde = true;
      expect(preisrelevantGeaendert(_rein(), neu), true);
      expect(preisrelevantGeaendert(preisSchnappschuss(neu), neu), false);
    });
    test('andere Anlage -> true, Reihenfolge egal', () {
      final alt = _rein()..anlageIdsJson = '["a1","a2"]';
      final gedreht = _rein()..anlageIdsJson = '["a2","a1"]';
      final anders = _rein()..anlageIdsJson = '["a1","a3"]';
      expect(preisrelevantGeaendert(alt, gedreht), false);
      expect(preisrelevantGeaendert(alt, anders), true);
    });
  });

  group('Jahresrechnung', () {
    test('offene Jahresrechnung -> jahresrechnung', () {
      expect(
        korrekturSperre(
            rechnung: _rg(typ: 'jahresrechnung'),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.jahresrechnung,
      );
    });
    test('bezahlte Jahresrechnung -> bezahlt', () {
      expect(
        korrekturSperre(
            rechnung: _rg(typ: 'jahresrechnung', status: 'bezahlt'),
            hatZahlungsbuchung: false, imMahnfall: false, nachbuchGrenze: grenze),
        KorrekturSperre.bezahlt,
      );
    });
    test('sperrText ohne Ausweg', () {
      final t = sperrText(KorrekturSperre.jahresrechnung, 'J-1');
      expect(t, contains('Jahresrechnung'));
      expect(t, contains('Notiz'));
      final ohne = sperrText(KorrekturSperre.bezahlt, 'J-1', mitAusweg: false);
      expect(ohne, isNot(contains('Notiz')));
    });
  });
}
