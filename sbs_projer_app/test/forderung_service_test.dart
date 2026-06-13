import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';

Rechnung _r({
  required String status,
  required DateTime faellig,
  DateTime? erinnerungAm,
  DateTime? mahnung1Am,
  String typ = 'rechnung_kunde',
}) =>
    Rechnung(
      id: 'x',
      userId: 'u',
      rechnungstyp: typ,
      rechnungsdatum: faellig.subtract(const Duration(days: 30)),
      faelligkeitsdatum: faellig,
      zahlungsstatus: status,
      erinnerungAm: erinnerungAm,
      mahnung1Am: mahnung1Am,
    );

void main() {
  final heute = DateTime(2026, 6, 13);

  test('offen, <5 Tage überfällig → warten', () {
    expect(
      ForderungService.empfohleneAktion(
          _r(status: 'offen', faellig: DateTime(2026, 6, 10)),
          heute: heute),
      'warten',
    );
  });

  test('offen, ≥5 Tage überfällig → erinnerung_faellig', () {
    expect(
      ForderungService.empfohleneAktion(
          _r(status: 'offen', faellig: DateTime(2026, 6, 1)),
          heute: heute),
      'erinnerung_faellig',
    );
  });

  test('erinnert, ≥25 Tage → mahnung_1_faellig', () {
    expect(
      ForderungService.empfohleneAktion(
          _r(
              status: 'erinnert',
              faellig: DateTime(2026, 4, 1),
              erinnerungAm: DateTime(2026, 5, 1)),
          heute: heute),
      'mahnung_1_faellig',
    );
  });

  test('mahnung_1, ≥30 Tage → mahnung_2_faellig', () {
    expect(
      ForderungService.empfohleneAktion(
          _r(
              status: 'mahnung_1',
              faellig: DateTime(2026, 3, 1),
              mahnung1Am: DateTime(2026, 5, 1)),
          heute: heute),
      'mahnung_2_faellig',
    );
  });

  test('mahnung_2 → eskalation', () {
    expect(
      ForderungService.empfohleneAktion(
          _r(status: 'mahnung_2', faellig: DateTime(2026, 1, 1)),
          heute: heute),
      'eskalation',
    );
  });

  test('bezahlt → warten', () {
    expect(
      ForderungService.empfohleneAktion(
          _r(status: 'bezahlt', faellig: DateTime(2026, 1, 1)),
          heute: heute),
      'warten',
    );
  });

  test('heineken_monat → warten', () {
    expect(
      ForderungService.empfohleneAktion(
          _r(
              status: 'offen',
              faellig: DateTime(2026, 1, 1),
              typ: 'heineken_monat'),
          heute: heute),
      'warten',
    );
  });

  test('istMahnfaellig', () {
    expect(
      ForderungService.istMahnfaellig(
          _r(status: 'offen', faellig: DateTime(2026, 6, 1)),
          heute: heute),
      isTrue,
    );
    expect(
      ForderungService.istMahnfaellig(
          _r(status: 'bezahlt', faellig: DateTime(2026, 1, 1)),
          heute: heute),
      isFalse,
    );
  });
}
