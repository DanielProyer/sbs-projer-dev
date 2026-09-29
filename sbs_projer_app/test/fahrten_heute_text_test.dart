import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeitstag_karte.dart';

/// Zeile «Fahrten heute» der Arbeitstag-Karte (Startseite, nach dem
/// Feierabend): Format und Route.

const _halt = Halt(
  typ: HaltTyp.betrieb,
  id: 'b',
  name: 'Betrieb',
  quelle: 'reinigung',
);

TagesFahrten _tag({
  int anzahl = 7,
  double km = 142.6,
  int? zaehler = 148,
  int ohneKm = 0,
}) => TagesFahrten(
  fahrten: [
    for (var i = 0; i < anzahl; i++) const Fahrt(von: _halt, nach: _halt),
  ],
  ohneZeit: const [],
  kmFahrten: km,
  fahrtenOhneKm: ohneKm,
  kmZaehler: zaehler,
  befunde: const [],
);

String _ganz(({String basis, String? delta}) t) =>
    t.delta == null ? t.basis : '${t.basis} ${t.delta}';

void main() {
  group('fahrtenHeuteText', () {
    test('mit Zählerstand: Anzahl, Fahrten-km, Zähler und Δ', () {
      final t = fahrtenHeuteText(_tag());
      expect(t.basis, 'Fahrten heute: 7 · 143 km · Zähler 148 km');
      expect(t.delta, '(+5)');
      expect(_ganz(t), 'Fahrten heute: 7 · 143 km · Zähler 148 km (+5)');
    });

    test('ohne Zählerstand: weder Zähler noch Δ', () {
      final t = fahrtenHeuteText(_tag(zaehler: null));
      expect(t.basis, 'Fahrten heute: 7 · 143 km');
      expect(t.delta, isNull);
    });

    test('weniger gezählt als erklärt → negatives Δ mit echtem Minus', () {
      final t = fahrtenHeuteText(_tag(km: 181.2, zaehler: 178));
      expect(t.delta, '(−3)');
    });

    test('kleine Differenz rundet auf «±0», nie «−0»', () {
      expect(fahrtenHeuteText(_tag(km: 148.4, zaehler: 148)).delta, '(±0)');
      expect(fahrtenHeuteText(_tag(km: 147.6, zaehler: 148)).delta, '(±0)');
    });

    test('Tag ohne Fahrten zeigt die Null ehrlich an', () {
      final t = fahrtenHeuteText(_tag(anzahl: 0, km: 0, zaehler: 12));
      expect(_ganz(t), 'Fahrten heute: 0 · 0 km · Zähler 12 km (+12)');
    });

    test('Rot-Regel kommt aus TagesFahrten (Toleranz 5 km bzw. 5 %)', () {
      expect(_tag(km: 142.6, zaehler: 148).differenzAuffaellig, isFalse);
      expect(_tag(km: 130, zaehler: 148).differenzAuffaellig, isTrue);
    });

    // Seit 29.09.2026 keine Luftlinien-km: Fehlt eine Strecke, wäre das Δ
    // eine falsche Aussage (die Lücke erschiene als «unerklärte» km).
    test('Strecken fehlen: Anzahl genannt, Zähler ja, Δ nein', () {
      final t = fahrtenHeuteText(
        _tag(anzahl: 3, km: 40, zaehler: 55, ohneKm: 1),
      );
      expect(
        t.basis,
        'Fahrten heute: 3 · 40 km (1 ohne Strecke) · Zähler 55 km',
      );
      expect(t.delta, isNull);
      expect(
        _tag(anzahl: 3, km: 40, zaehler: 55, ohneKm: 1).differenzAuffaellig,
        isFalse,
      );
    });

    test('Strecken fehlen, ohne Zählerstand', () {
      final t = fahrtenHeuteText(
        _tag(anzahl: 4, km: 22.4, zaehler: null, ohneKm: 2),
      );
      expect(t.basis, 'Fahrten heute: 4 · 22 km (2 ohne Strecke)');
      expect(t.delta, isNull);
    });
  });

  test('fahrtenPfad: Datum zweistellig, ohne Uhrzeit', () {
    expect(
      fahrtenPfad(DateTime(2026, 9, 7, 18, 30)),
      '/auswertungen/arbeitstage/2026-09-07/fahrten',
    );
  });
}
