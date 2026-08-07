import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';

void main() {
  test('Stichtag 11.03.2026 ist EXKLUSIV — der Tag selbst ist aus Excel gebucht', () {
    // Off-by-One-Befund 05.08.2026: Der 11.03. war der letzte Excel-Banktag
    // (SVA 5'962.20 + Kehricht 153.00 bereits gebucht) — camt übernimmt ab
    // dem 12.03. Ein inklusiver Stichtag hätte den Tag doppelt gebucht.
    expect(CamtStichtag.stichtag, DateTime(2026, 3, 11));
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 10)), isFalse);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 11)), isFalse);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 12)), isTrue);
  });
}
