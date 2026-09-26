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
}) =>
    Rechnung.fromJson({
      'id': 'r1',
      'user_id': 'u',
      'rechnungsnummer': '2026-09-26-0001',
      'rechnungstyp': 'kundenrechnung',
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
  });
}
