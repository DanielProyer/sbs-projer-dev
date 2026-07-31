import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/pause_pruefung.dart';

void main() {
  group('pausePruefen', () {
    test('kurze Pause am selben Ort -> unauffaellig', () {
      final r = pausePruefen(
        pauseStartMinuten: 840, // 14:00
        jetztMinuten: 855, // 14:15, 15 min
        distanzKm: 0.0,
      );
      expect(r.befund, PauseBefund.unauffaellig);
      expect(r.endeMinuten, isNull);
    });

    test('8 km entfernt nach 60 min -> bewegt, Ende plausibel', () {
      const pauseStart = 840; // 14:00
      const jetzt = 900; // 15:00
      final r = pausePruefen(
        pauseStartMinuten: pauseStart,
        jetztMinuten: jetzt,
        distanzKm: 8.0,
      );
      expect(r.befund, PauseBefund.bewegt);
      expect(r.endeMinuten, isNotNull);
      expect(r.endeMinuten!, greaterThan(pauseStart));
      expect(r.endeMinuten!, lessThan(jetzt));
    });

    test('120 min am selben Ort -> zuLang, Vorschlag Start+90', () {
      const pauseStart = 840; // 14:00
      final r = pausePruefen(
        pauseStartMinuten: pauseStart,
        jetztMinuten: pauseStart + 120,
        distanzKm: 0.0,
      );
      expect(r.befund, PauseBefund.zuLang);
      expect(r.endeMinuten, pauseStart + 90);
    });

    test('Distanz unbekannt (null) und kurz -> unauffaellig', () {
      final r = pausePruefen(
        pauseStartMinuten: 840,
        jetztMinuten: 860, // 20 min
        distanzKm: null,
      );
      expect(r.befund, PauseBefund.unauffaellig);
      expect(r.endeMinuten, isNull);
    });

    test('Distanz knapp unter der Schwelle -> unauffaellig', () {
      final r = pausePruefen(
        pauseStartMinuten: 840,
        jetztMinuten: 870, // 30 min, unterhalb maxPauseMinuten
        distanzKm: 0.4,
      );
      expect(r.befund, PauseBefund.unauffaellig);
      expect(r.endeMinuten, isNull);
    });

    test('sehr grosse Distanz: Ende darf nicht vor den Start rutschen', () {
      const pauseStart = 840; // 14:00
      const jetzt = 850; // 14:10, nur 10 min seit Pausenbeginn
      final r = pausePruefen(
        pauseStartMinuten: pauseStart,
        jetztMinuten: jetzt,
        distanzKm: 300.0, // geschaetzte Fahrzeit weit ueber 10 min
      );
      expect(r.befund, PauseBefund.bewegt);
      expect(r.endeMinuten, pauseStart);
    });

    test('Ende rutscht auch nie nach jetzt', () {
      const pauseStart = 840;
      const jetzt = 845; // nur 5 min seit Pausenbeginn
      final r = pausePruefen(
        pauseStartMinuten: pauseStart,
        jetztMinuten: jetzt,
        distanzKm:
            1.0, // ueber der Schwelle, aber Fahrzeit >= 3 min (min in heuristikMinuten)
      );
      expect(r.befund, PauseBefund.bewegt);
      expect(r.endeMinuten, lessThanOrEqualTo(jetzt));
      expect(r.endeMinuten, greaterThanOrEqualTo(pauseStart));
    });

    test('individuelles maxPauseMinuten wird respektiert', () {
      const pauseStart = 600; // 10:00
      final r = pausePruefen(
        pauseStartMinuten: pauseStart,
        jetztMinuten: pauseStart + 45,
        distanzKm: 0.0,
        maxPauseMinuten: 30,
      );
      expect(r.befund, PauseBefund.zuLang);
      expect(r.endeMinuten, pauseStart + 30);
    });
  });
}
