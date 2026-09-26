import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz_start.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

TourEintrag _e(
  TourEintragTyp typ, {
  String id = 'r_a1',
  String? betriebId = 'b1',
  String? anlageId,
  List<String> anlageIds = const [],
  FaelligkeitsStatus? faelligkeit,
}) => TourEintrag(
  typ: typ,
  id: id,
  betriebId: betriebId,
  anlageId: anlageId,
  anlageIds: anlageIds,
  betriebName: 'Test',
  beschreibung: '',
  faelligkeit: faelligkeit,
);

void main() {
  group('Reinigung', () {
    test('normal: Betrieb und gebündelte Anlagen, keine Service-Art', () {
      final r = startRoute(
        _e(
          TourEintragTyp.reinigung,
          anlageIds: ['a1', 'a2'],
          faelligkeit: FaelligkeitsStatus.faellig,
        ),
      );
      expect(r, '/reinigungen/neu?betriebId=b1&anlageIds=a1,a2');
    });

    test('Alt-Eintrag nur mit anlageId', () {
      expect(
        startRoute(_e(TourEintragTyp.reinigung, anlageId: 'a9')),
        '/reinigungen/neu?betriebId=b1&anlageIds=a9',
      );
    });

    test('ohne Anlagen: nur Betrieb', () {
      expect(
        startRoute(_e(TourEintragTyp.reinigung)),
        '/reinigungen/neu?betriebId=b1',
      );
    });

    test('Eröffnung → serviceArt=eroeffnungsservice', () {
      expect(
        startRoute(
          _e(
            TourEintragTyp.reinigung,
            anlageIds: ['a1'],
            faelligkeit: FaelligkeitsStatus.eroeffnungFaellig,
          ),
        ),
        '/reinigungen/neu?betriebId=b1&anlageIds=a1'
        '&serviceArt=eroeffnungsservice',
      );
    });

    test('Endreinigung → serviceArt=endreinigung', () {
      expect(
        startRoute(
          _e(
            TourEintragTyp.reinigung,
            anlageIds: ['a1'],
            faelligkeit: FaelligkeitsStatus.endreinigungFaellig,
          ),
        ),
        '/reinigungen/neu?betriebId=b1&anlageIds=a1&serviceArt=endreinigung',
      );
    });

    test('Notiz mit Umlauten, Leerzeichen und & wird kodiert', () {
      const notiz = 'Hahn 2 tropft & Kühler prüfen';
      final r = startRoute(
        _e(TourEintragTyp.reinigung, anlageIds: ['a1']),
        notiz: notiz,
      );
      expect(
        r,
        startsWith('/reinigungen/neu?betriebId=b1&anlageIds=a1&notiz='),
      );
      expect(r, isNot(contains(' ')));
      expect(r, isNot(contains('ü')));
      // Rundreise: der Router liest sie wieder im Klartext.
      final q = Uri.parse(r).queryParameters;
      expect(q['notiz'], notiz);
      expect(q['anlageIds'], 'a1');
    });

    test('Saison-Stopp mit Notiz: beides dabei', () {
      final q = Uri.parse(
        startRoute(
          _e(
            TourEintragTyp.reinigung,
            faelligkeit: FaelligkeitsStatus.endreinigungFaellig,
          ),
          notiz: 'Schlüssel beim Wirt',
        ),
      ).queryParameters;
      expect(q['serviceArt'], 'endreinigung');
      expect(q['notiz'], 'Schlüssel beim Wirt');
    });

    test('leere Notiz fällt weg', () {
      expect(
        startRoute(_e(TourEintragTyp.reinigung), notiz: '   '),
        '/reinigungen/neu?betriebId=b1',
      );
    });

    test('ohne Betrieb → Betriebsauswahl', () {
      expect(
        startRoute(_e(TourEintragTyp.reinigung, betriebId: null)),
        '/reinigungen/neu',
      );
    });
  });

  group('Störung', () {
    test('geplant (s_<id>) → bearbeiten statt neu', () {
      expect(
        startRoute(_e(TourEintragTyp.stoerung, id: 's_abc-123')),
        '/stoerungen/abc-123/bearbeiten',
      );
    });

    test('ohne Einsatz-Id → neues Formular mit Betrieb und Anlage', () {
      expect(
        startRoute(_e(TourEintragTyp.stoerung, id: 'u_x', anlageId: 'a1')),
        '/stoerungen/neu?betriebId=b1&anlageId=a1',
      );
      expect(
        startRoute(_e(TourEintragTyp.stoerung, id: '')),
        '/stoerungen/neu?betriebId=b1',
      );
    });

    test('falsches Präfix (m_ bei Störung) gilt nicht als geplant', () {
      expect(
        startRoute(_e(TourEintragTyp.stoerung, id: 'm_abc')),
        '/stoerungen/neu?betriebId=b1',
      );
    });
  });

  group('Montage und HeiGenie', () {
    test('Montage geplant → bearbeiten', () {
      expect(
        startRoute(_e(TourEintragTyp.montage, id: 'm_42')),
        '/montagen/42/bearbeiten',
      );
    });

    test('HeiGenie läuft über die Montage-Route', () {
      expect(
        startRoute(_e(TourEintragTyp.heigenie, id: 'm_77')),
        '/montagen/77/bearbeiten',
      );
    });

    test('ohne Einsatz → neu', () {
      expect(
        startRoute(_e(TourEintragTyp.montage, id: 'u_m_1_99')),
        '/montagen/neu?betriebId=b1',
      );
      expect(
        startRoute(_e(TourEintragTyp.heigenie, id: 's_1')),
        '/montagen/neu?betriebId=b1',
      );
    });
  });

  test('geplanteEinsatzId', () {
    expect(geplanteEinsatzId(_e(TourEintragTyp.stoerung, id: 's_')), isNull);
    expect(geplanteEinsatzId(_e(TourEintragTyp.reinigung, id: 's_1')), isNull);
    expect(geplanteEinsatzId(_e(TourEintragTyp.montage, id: 'm_1')), '1');
  });
}
