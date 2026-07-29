import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/besuch_dauer.dart';

BesuchHistorie h(int anlagen, int minuten) =>
    (anlagenZahl: anlagen, dauerMinuten: minuten);

void main() {
  group('geschaetzteDauer (Spec 2026-07-29, Kaskade)', () {
    test('Median der Besuche mit gleicher Anlagenzahl', () {
      final hist = [h(1, 30), h(1, 34), h(1, 200), h(2, 50)];
      // Median von 30/34/200 = 34 — der Langlaeufer verzerrt nicht.
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 1), 34);
    });
    test('keine passende Anlagenzahl: Betriebs-Median ueber Kurve skaliert', () {
      final hist = [h(1, 30), h(1, 40)]; // Betriebs-Median (1 Anlage) = 35
      // Kurve 1->28, 2->33: 35 * 33/28 = 41.25 -> 41
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 2), 41);
    });
    test('Kurve ueber 4 Anlagen linear fortgeschrieben', () {
      // Stuetzwerte 3->54, 4->86, Schritt 32: 5 Anlagen -> 118 (global, ohne Historie
      // greift Default — also Historie mit 4er-Besuch: Median 86 -> 5er = 86*118/86)
      final hist = [h(4, 86)];
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 5), 118);
    });
    test('nur Werte 5-300 min zaehlen', () {
      final hist = [h(1, 2), h(1, 400), h(1, 30)];
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 1), 30);
    });
    test('ohne Historie: 60 min Default', () {
      expect(geschaetzteDauer(historie: [], anlagenZahl: 3), 60);
    });
    test('gemischte Anlagenzahl: gleicher Zahl-Median gewinnt vor Skalierung', () {
      final hist = [h(2, 44), h(2, 48), h(1, 20)];
      expect(geschaetzteDauer(historie: hist, anlagenZahl: 2), 46);
    });
  });

  group('dauerAusReinigung', () {
    test('dauer_minuten hat Vorrang', () {
      expect(dauerAusReinigung(dauerMinuten: 42, start: '08:00', ende: '09:30'), 42);
    });
    test('sonst aus Start/Ende gerechnet', () {
      expect(dauerAusReinigung(dauerMinuten: null, start: '08:00', ende: '09:30'), 90);
    });
    test('unbrauchbare Zeiten -> null', () {
      expect(dauerAusReinigung(dauerMinuten: null, start: '09:00', ende: '08:00'), null);
      expect(dauerAusReinigung(dauerMinuten: null, start: null, ende: '08:00'), null);
    });
  });
}
