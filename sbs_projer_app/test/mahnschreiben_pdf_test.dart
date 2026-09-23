import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/pdf/mahnschreiben_pdf_service.dart';

Rechnung _rechnung({
  required String id,
  required String rechnungsnummer,
  DateTime? rechnungsdatum,
  DateTime? faelligkeitsdatum,
  double betragBrutto = 123.45,
  String? qrReferenz,
}) {
  return Rechnung.fromJson({
    'id': id,
    'user_id': 'u1',
    'rechnungsnummer': rechnungsnummer,
    'rechnungstyp': 'kundenrechnung',
    'rechnungsdatum':
        (rechnungsdatum ?? DateTime.utc(2026, 8, 1)).toIso8601String(),
    'faelligkeitsdatum':
        (faelligkeitsdatum ?? DateTime.utc(2026, 8, 31)).toIso8601String(),
    'betrag_brutto': betragBrutto,
    'zahlungsstatus': 'erinnert',
    'qr_referenz': qrReferenz,
  });
}

BetriebLocal _betrieb() {
  final b = BetriebLocal();
  b.userId = 'u1';
  b.name = 'Testbetrieb Gasthaus Sonne';
  b.strasse = 'Musterstrasse';
  b.nr = '12';
  b.plz = '7000';
  b.ort = 'Chur';
  return b;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mahnText', () {
    final frist = DateTime.utc(2026, 10, 3);
    test('Erinnerung freundlich, mit Frist', () {
      final t = MahnschreibenPdfService.mahnText(MahnStufe.erinnerung,
          frist: frist, ersteErinnerung: null);
      expect(t, contains('entgangen'));
      expect(t, contains('03.10.2026'));
    });
    test('Letzte Mahnung droht Betreibung und nennt Zins seit Erinnerung', () {
      final t = MahnschreibenPdfService.mahnText(MahnStufe.letzte,
          frist: frist, ersteErinnerung: DateTime.utc(2026, 9, 1));
      expect(t, contains('Betreibung'));
      expect(t, contains('5 %'));
      expect(t, contains('01.09.2026'));
    });
    test('jede Stufe mit Gegenstandslos-Satz', () {
      for (final s in MahnStufe.values) {
        expect(
          MahnschreibenPdfService.mahnText(s,
              frist: frist, ersteErinnerung: DateTime.utc(2026, 9, 1)),
          contains('gegenstandslos'),
          reason: s.name,
        );
      }
    });
  });

  group('generate', () {
    test('eine Rechnung, ohne Kontoauszug, ohne Muster', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: [(rechnung: r, stufe: MahnStufe.erinnerung)],
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: false,
      );
      expect(bytes.length, greaterThan(0));
    });

    test('drei Rechnungen, ohne Kontoauszug', () async {
      final betrieb = _betrieb();
      final posten = [
        (
          rechnung: _rechnung(id: 'r1', rechnungsnummer: '2026-08-1'),
          stufe: MahnStufe.erinnerung,
        ),
        (
          rechnung: _rechnung(id: 'r2', rechnungsnummer: '2026-08-2'),
          stufe: MahnStufe.mahnung1,
        ),
        (
          rechnung: _rechnung(
            id: 'r3',
            rechnungsnummer: '2026-08-3',
            qrReferenz: '210000000003139471430009017',
          ),
          stufe: MahnStufe.letzte,
        ),
      ];
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: posten,
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: false,
      );
      expect(bytes.length, greaterThan(0));
    });

    test('mit Kontoauszug-Beilage', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: [(rechnung: r, stufe: MahnStufe.erinnerung)],
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: false,
        kontoauszugRechnungen: [r],
        kontoauszugJahr: 2026,
      );
      expect(bytes.length, greaterThan(0));
    });

    test('mit Muster-Aufdruck (Schreiben + QR + Kontoauszug)', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: [(rechnung: r, stufe: MahnStufe.letzte)],
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: true,
        kontoauszugRechnungen: [r],
      );
      expect(bytes.length, greaterThan(0));
    });
  });
}
