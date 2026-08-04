import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

// Fall Löwen Grossdietwil (04.08.2026): bestätigter Eröffnungs-Termin am
// letzten Ferientag muss im Tourenplan zur Auswahl stehen — auch wenn der
// Betrieb an dem Tag geschlossen ist. `saisonTermineFuerTag` baut die
// Sektion über der Fällig-Liste: bestätigte Termine des Tages + die
// Auto-Vorschläge, soweit kein Termin sie schon abdeckt (±7 Tage).

BetriebLocal _betrieb() => BetriebLocal()
  ..userId = 'test'
  ..name = 'Gasthof Löwen'
  ..ort = 'Grossdietwil'
  ..status = 'aktiv';

AnlageLocal _anlage(int id, {String status = 'aktiv'}) => AnlageLocal()
  ..id = id
  ..betriebId = 'srv-b1'
  ..status = status;

TerminDto _termin({
  String typ = 'eroeffnungsreinigung',
  DateTime? datum,
  String? uhrzeitVon,
}) => TerminDto(
  id: 'termin-1',
  userId: 'test',
  betriebId: 'srv-b1',
  datum: datum ?? DateTime(2026, 8, 6),
  uhrzeitVon: uhrzeitVon,
  typ: typ,
  titel: 'Eröffnungsreinigung Gasthof Löwen',
);

TourEintrag _autoVorschlag({
  String id = 'r_9',
  FaelligkeitsStatus faelligkeit = FaelligkeitsStatus.eroeffnungFaellig,
  DateTime? zielDatum,
}) => TourEintrag(
  typ: TourEintragTyp.reinigung,
  id: id,
  betriebId: 'srv-b1',
  betriebName: 'Gasthof Löwen',
  beschreibung: 'Eröffnungsservice · Bier',
  faelligkeit: faelligkeit,
  istAutoTermin: true,
  zielDatum: zielDatum ?? DateTime(2026, 8, 7),
);

void main() {
  final tag = DateTime(2026, 8, 6);
  final betriebMap = {'srv-b1': _betrieb()};

  group('saisonTermineFuerTag — bestätigte Termine', () {
    test('Eröffnungs-Termin am Tag wird zum Reinigungs-Eintrag', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: const [],
        offeneTermine: [_termin(uhrzeitVon: '08:30:00')],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      expect(result, hasLength(1));
      final e = result.single;
      expect(e.typ, TourEintragTyp.reinigung);
      expect(e.id, 'r_1');
      expect(e.betriebId, 'srv-b1');
      expect(e.anlageId, '1');
      expect(e.anlageIds, ['1']);
      expect(e.faelligkeit, FaelligkeitsStatus.eroeffnungFaellig);
      expect(e.betriebName, 'Gasthof Löwen');
      expect(e.beschreibung, contains('Eröffnungsreinigung'));
      expect(e.ankerZeit, '08:30');
      expect(e.istAutoTermin, isFalse);
      expect(e.zielDatum, DateTime(2026, 8, 6));
    });

    test('Endreinigungs-Termin bekommt endreinigungFaellig', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: const [],
        offeneTermine: [_termin(typ: 'endreinigung')],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      expect(result.single.faelligkeit, FaelligkeitsStatus.endreinigungFaellig);
      expect(result.single.beschreibung, contains('Endreinigung'));
    });

    test('Termin an anderem Tag → kein Eintrag', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: const [],
        offeneTermine: [_termin(datum: DateTime(2026, 8, 7))],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      expect(result, isEmpty);
    });

    test('Termin-Typ «sonstiges» wird ignoriert', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: const [],
        offeneTermine: [_termin(typ: 'sonstiges')],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      expect(result, isEmpty);
    });

    test('unbekannter Betrieb → Termin übersprungen', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: const [],
        offeneTermine: [_termin()],
        betriebMap: const {},
        anlagen: [_anlage(1)],
      );
      expect(result, isEmpty);
    });

    test('nur aktive Anlagen des Betriebs landen in anlageIds', () {
      final fremde = AnlageLocal()
        ..id = 3
        ..betriebId = 'srv-b2'
        ..status = 'aktiv';
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: const [],
        offeneTermine: [_termin()],
        betriebMap: betriebMap,
        anlagen: [_anlage(1), _anlage(2, status: 'demontiert'), fremde],
      );
      expect(result.single.anlageIds, ['1']);
    });

    test('Betrieb ohne aktive Anlage → Eintrag bleibt sichtbar (t_-Id)', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: const [],
        offeneTermine: [_termin()],
        betriebMap: betriebMap,
        anlagen: const [],
      );
      expect(result.single.id, 't_termin-1');
      expect(result.single.anlageId, isNull);
    });
  });

  group('saisonTermineFuerTag — Abgleich mit Auto-Vorschlägen', () {
    test('Auto-Vorschlag bleibt, wenn kein Termin ihn abdeckt', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: [_autoVorschlag()],
        offeneTermine: const [],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      expect(result.single.id, 'r_9');
      expect(result.single.istAutoTermin, isTrue);
    });

    test('bestätigter Termin (±7 Tage) verdrängt den Auto-Vorschlag', () {
      // Termin 06.08., Auto-Vorschlag zielt auf 07.08. → abgedeckt.
      final result = saisonTermineFuerTag(
        tag: tag,
        autoTermine: [_autoVorschlag(zielDatum: DateTime(2026, 8, 7))],
        offeneTermine: [_termin()],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      expect(result, hasLength(1));
      expect(result.single.istAutoTermin, isFalse);
    });

    test('Termin anderer Art verdrängt nicht', () {
      final result = saisonTermineFuerTag(
        tag: DateTime(2026, 10, 1),
        autoTermine: [
          _autoVorschlag(
            faelligkeit: FaelligkeitsStatus.endreinigungFaellig,
            zielDatum: DateTime(2026, 9, 30),
          ),
        ],
        offeneTermine: [_termin(datum: DateTime(2026, 10, 1))],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      // Eröffnungs-Termin (01.10.) + Endreinigungs-Vorschlag bleiben beide.
      expect(result, hasLength(2));
    });

    test('Id-Kollision: Termin-Eintrag gewinnt', () {
      final result = saisonTermineFuerTag(
        tag: tag,
        // Auto-Vorschlag weit weg vom Termin (>7 Tage), aber gleiche Anlage.
        autoTermine: [
          _autoVorschlag(id: 'r_1', zielDatum: DateTime(2026, 9, 1)),
        ],
        offeneTermine: [_termin()],
        betriebMap: betriebMap,
        anlagen: [_anlage(1)],
      );
      expect(result, hasLength(1));
      expect(result.single.istAutoTermin, isFalse);
    });
  });
}
