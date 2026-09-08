import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/servicezeit_vorschlag.dart';
import 'package:sbs_projer_app/data/repositories/servicezeit_durchsicht_repository.dart';

ServicezeitKandidat _k({
  ServicezeitVorschlag vorschlag = const ServicezeitVorschlag(),
  String? bisherMorgenAb,
  String? bisherMorgenBis,
}) => ServicezeitKandidat(
  betriebId: 'b1',
  name: 'Testbetrieb',
  ort: 'Chur',
  bisherMorgenAb: bisherMorgenAb,
  bisherMorgenBis: bisherMorgenBis,
  vorschlag: vorschlag,
);

/// Die Felder der Durchsicht starten mit dem Vorschlag — gibt es keinen,
/// mit den bereits hinterlegten Zeiten. Ohne diesen Rückfall würde ein Wisch
/// nach rechts bei einem Betrieb ohne Besuchshistorie seine bestehenden
/// Servicezeiten löschen.
void main() {
  test('mit Vorschlag: Vorschlag gewinnt', () {
    final v = _k(
      vorschlag: const ServicezeitVorschlag(
        morgenAb: '08:15',
        morgenBis: '11:45',
        morgenBesuche: 20,
      ),
      bisherMorgenAb: '09:00',
      bisherMorgenBis: '11:00',
    ).vorbelegung;
    expect(v.morgenAb, '08:15');
    expect(v.morgenBis, '11:45');
  });

  test('ohne Vorschlag: bestehende Zeiten bleiben stehen', () {
    final v = _k(bisherMorgenAb: '09:00', bisherMorgenBis: '11:00').vorbelegung;
    expect(v.morgenAb, '09:00');
    expect(v.morgenBis, '11:00');
  });

  test('ohne Vorschlag und ohne bisherige Zeiten: leer', () {
    final v = _k().vorbelegung;
    expect(v.morgenAb, isNull);
    expect(v.nachmittagBis, isNull);
  });

  test('label mit und ohne Ort', () {
    expect(_k().label, 'Testbetrieb, Chur');
    expect(
      const ServicezeitKandidat(
        betriebId: 'b2',
        name: 'Solo',
        vorschlag: ServicezeitVorschlag(),
      ).label,
      'Solo',
    );
  });
}
