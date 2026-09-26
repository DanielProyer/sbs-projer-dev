import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_akte.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';

BetriebLocal betrieb() => BetriebLocal()
  ..serverId = 'b1'
  ..name = 'Calanda'
  ..ort = 'Chur';

ReinigungLocal reinigung(
  String id,
  DateTime datum, {
  String anlage = 'a1',
  List<String> anlagen = const [],
}) => ReinigungLocal()
  ..serverId = id
  ..userId = 'u'
  ..anlageId = anlage
  ..anlageIds = anlagen
  ..betriebId = 'b1'
  ..datum = datum
  ..status = 'abgeschlossen';

StoerungLocal stoerung(String id, DateTime datum, {String? anlage}) =>
    StoerungLocal()
      ..serverId = id
      ..userId = 'u'
      ..betriebId = 'b1'
      ..anlageId = anlage
      ..datum = datum
      ..problemBeschreibung = 'Zapfhahn tropft'
      ..status = 'offen';

MontageLocal montage(String id, DateTime datum, {String? anlage}) =>
    MontageLocal()
      ..serverId = id
      ..userId = 'u'
      ..betriebId = 'b1'
      ..anlageId = anlage
      ..datum = datum
      ..montageTyp = 'neu'
      ..beschreibung = 'Neue Anlage'
      ..status = 'geplant';

EigenauftragLocal eigenauftrag(String id, DateTime datum, {String? anlage}) =>
    EigenauftragLocal()
      ..serverId = id
      ..userId = 'u'
      ..betriebId = 'b1'
      ..anlageId = anlage
      ..datum = datum
      ..status = 'behoben';

EroeffnungsreinigungLocal saison(String id, DateTime datum) =>
    EroeffnungsreinigungLocal()
      ..serverId = id
      ..userId = 'u'
      ..betriebId = 'b1'
      ..datum = datum;

void main() {
  test('führt alle Typen zusammen, neueste zuerst — Montagen inklusive', () {
    final liste = einsaetzeDerAkte(
      betrieb: betrieb(),
      reinigungen: [reinigung('r1', DateTime(2026, 5, 1))],
      stoerungen: [stoerung('s1', DateTime(2026, 7, 1))],
      montagen: [montage('m1', DateTime(2026, 9, 1))],
      eigenauftraege: [eigenauftrag('e1', DateTime(2026, 3, 1))],
      saisonreinigungen: [saison('o1', DateTime(2026, 4, 1))],
      belegIdsMitBuchung: const {},
    );
    expect(liste.map((e) => e.typ).toList(), [
      EinsatzTyp.montage,
      EinsatzTyp.stoerung,
      EinsatzTyp.reinigung,
      EinsatzTyp.saisonreinigung,
      EinsatzTyp.eigenauftrag,
    ]);
    expect(liste.first.betriebName, 'Calanda');
  });

  test('Reinigung mit Buchung gilt als verrechnet', () {
    final liste = einsaetzeDerAkte(
      betrieb: betrieb(),
      reinigungen: [
        reinigung('r1', DateTime(2026, 5, 1)),
        reinigung('r2', DateTime(2026, 6, 1)),
      ],
      belegIdsMitBuchung: const {'r1'},
    );
    final r1 = liste.firstWhere((e) => e.datum.month == 5);
    final r2 = liste.firstWhere((e) => e.datum.month == 6);
    expect(r1.status, EinsatzStatus.verrechnet);
    expect(r2.status, EinsatzStatus.erledigt);
  });

  test('mit anlageId nur die Einsätze dieser Anlage, ohne Saisonbelege', () {
    final liste = einsaetzeDerAkte(
      betrieb: betrieb(),
      anlageId: 'a2',
      reinigungen: [
        reinigung('r1', DateTime(2026, 5, 1)),
        // Sammelreinigung: a2 steht nur in anlageIds.
        reinigung('r2', DateTime(2026, 6, 1), anlagen: ['a1', 'a2']),
        reinigung('r3', DateTime(2026, 7, 1), anlage: 'a2'),
      ],
      stoerungen: [
        stoerung('s1', DateTime(2026, 7, 3), anlage: 'a2'),
        stoerung('s2', DateTime(2026, 7, 2)),
      ],
      montagen: [montage('m1', DateTime(2026, 9, 1), anlage: 'a1')],
      eigenauftraege: [eigenauftrag('e1', DateTime(2026, 3, 1), anlage: 'a2')],
      saisonreinigungen: [saison('o1', DateTime(2026, 4, 1))],
      belegIdsMitBuchung: const {},
    );
    expect(liste.map((e) => e.datum).toSet(), {
      DateTime(2026, 6, 1), // r2
      DateTime(2026, 7, 1), // r3
      DateTime(2026, 7, 3), // s1
      DateTime(2026, 3, 1), // e1
    });
    expect(liste.length, 4);
  });

  group('EinsatzFilter mit Betrieb', () {
    Einsatz e(String betriebId, DateTime datum) => Einsatz(
      typ: EinsatzTyp.reinigung,
      typLabel: 'Reinigung',
      routeId: '$betriebId-${datum.year}',
      betriebId: betriebId,
      betriebName: betriebId,
      betriebOrt: null,
      betriebNr: null,
      regionId: null,
      datum: datum,
      status: EinsatzStatus.erledigt,
      kennzeichen: EinsatzKennzeichen.keines,
    );
    final alle = [
      e('b1', DateTime(2024, 5, 1)),
      e('b1', DateTime(2026, 5, 1)),
      e('b2', DateTime(2026, 5, 1)),
    ];

    test('filtert auf den Betrieb', () {
      final f = filtereEinsaetze(
        alle,
        const EinsatzFilter(jahr: 2026, betriebId: 'b1'),
      );
      expect(f.map((x) => x.routeId), ['b1-2026']);
    });

    test('jahr 0 heisst alle Jahre', () {
      final f = filtereEinsaetze(
        alle,
        const EinsatzFilter(jahr: 0, betriebId: 'b1'),
      );
      expect(f.map((x) => x.routeId), ['b1-2026', 'b1-2024']);
    });

    test('copyWith kann den Betrieb wieder entfernen', () {
      const f = EinsatzFilter(jahr: 0, betriebId: 'b1');
      expect(f.copyWith(betriebId: null).betriebId, isNull);
      expect(f.copyWith(monat: 3).betriebId, 'b1');
    });
  });
}
