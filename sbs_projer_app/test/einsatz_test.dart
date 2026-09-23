import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';

BetriebLocal betrieb() => BetriebLocal()
  ..serverId = 'b1'
  ..name = 'Calanda'
  ..ort = 'Chur'
  ..regionId = 'r1'
  ..betriebNr = '4711';

void main() {
  group('einsatzAusReinigung', () {
    test('uebernimmt Betrieb, Datum, Bruttopreis und leitet den Status ab', () {
      final r = ReinigungLocal()
        ..serverId = 'r1'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 15)
        ..preisBrutto = 177.30
        ..status = 'abgeschlossen'
        ..istAbgerechnet = false;

      final e = einsatzAusReinigung(r, betrieb: betrieb(), hatBuchung: true);

      expect(e.typ, EinsatzTyp.reinigung);
      expect(e.typLabel, 'Reinigung');
      expect(e.betriebName, 'Calanda');
      expect(e.betriebOrt, 'Chur');
      expect(e.betriebNr, '4711');
      expect(e.regionId, 'r1');
      expect(e.datum, DateTime(2026, 9, 15));
      expect(e.betragCHF, 177.30);
      expect(e.status, EinsatzStatus.verrechnet);
      expect(e.detailRoute, '/reinigungen/${r.routeId}');
      expect(e.geplantAm, isNull);
    });

    test('ohne Betrieb bleibt der Name ein Platzhalter statt zu werfen', () {
      final r = ReinigungLocal()
        ..serverId = 'r1'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'fehlt'
        ..datum = DateTime(2026, 9, 15)
        ..status = 'abgeschlossen';
      final e = einsatzAusReinigung(r, betrieb: null, hatBuchung: false);
      expect(e.betriebName, 'Unbekannter Betrieb');
    });
  });

  group('einsatzAusReinigung Kulanz', () {
    test('Kulanz zeigt keinen Betrag und heisst so', () {
      final r = ReinigungLocal()
        ..serverId = 'r9'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 7, 31)
        ..preisBrutto = 94.05
        ..istKulanz = true
        ..status = 'abgeschlossen';
      final e = einsatzAusReinigung(r, betrieb: betrieb(), hatBuchung: false);
      expect(e.betragCHF, isNull);
      expect(e.typLabel, 'Reinigung (Kulanz)');
      expect(e.status, EinsatzStatus.erledigt);
    });
  });

  group('einsatzAusStoerung', () {
    test(
      'nimmt problemBeschreibung, geplante Zeit und die Zusatzfilter-Felder mit',
      () {
        final s = StoerungLocal()
          ..serverId = 's1'
          ..userId = 'u'
          ..betriebId = 'b1'
          ..datum = DateTime(2026, 9, 17)
          ..geplantAm = DateTime(2026, 9, 17)
          ..geplantZeit = '14:00'
          ..status = 'offen'
          ..problemBeschreibung = 'Zapfhahn tropft'
          ..anlageTyp = 'heigenie'
          ..istKilometerabrechnung = false
          ..preisNetto = 94.05;

        final e = einsatzAusStoerung(s, betrieb: betrieb());

        expect(e.typ, EinsatzTyp.stoerung);
        expect(e.status, EinsatzStatus.geplant);
        expect(e.zeit, '14:00');
        expect(e.beschreibung, 'Zapfhahn tropft');
        expect(e.anlageTyp, 'heigenie');
        expect(e.betragCHF, isNull, reason: 'geplant zeigt keinen Betrag');
      },
    );

    test('erledigte Stoerung zeigt den Nettopreis', () {
      final s = StoerungLocal()
        ..serverId = 's2'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 15)
        ..status = 'behoben'
        ..problemBeschreibung = 'x'
        ..preisNetto = 94.05;
      expect(einsatzAusStoerung(s, betrieb: betrieb()).betragCHF, 94.05);
    });

    test(
      'geplantAm wird uebernommen, auch wenn die Stufe nicht geplant ist',
      () {
        final s = StoerungLocal()
          ..serverId = 's3'
          ..userId = 'u'
          ..betriebId = 'b1'
          ..datum = DateTime(2026, 9, 10)
          ..geplantAm = DateTime(2026, 9, 17)
          ..arbeitVon = '09:00'
          ..status = 'offen'
          ..problemBeschreibung = 'x';
        final e = einsatzAusStoerung(s, betrieb: betrieb());
        expect(e.status, EinsatzStatus.inArbeit);
        expect(e.geplantAm, DateTime(2026, 9, 17));
      },
    );
  });

  group('einsatzAusMontage', () {
    test('nimmt beschreibung und kostenArbeit', () {
      final m = MontageLocal()
        ..serverId = 'm1'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..montageTyp = 'neuanlage'
        ..beschreibung = 'neue Anlage'
        ..datum = DateTime(2026, 9, 10)
        ..status = 'abgeschlossen'
        ..kostenArbeit = 250;
      final e = einsatzAusMontage(m, betrieb: betrieb());
      expect(e.typ, EinsatzTyp.montage);
      expect(e.beschreibung, 'neue Anlage');
      expect(e.betragCHF, 250);
      expect(e.status, EinsatzStatus.erledigt);
    });

    test('nimmt geplantAm mit', () {
      final m = MontageLocal()
        ..serverId = 'm2'
        ..userId = 'u'
        ..betriebId = 'b1'
        ..montageTyp = 'neuanlage'
        ..beschreibung = 'x'
        ..datum = DateTime(2026, 9, 10)
        ..geplantAm = DateTime(2026, 9, 20)
        ..status = 'geplant';
      final e = einsatzAusMontage(m, betrieb: betrieb());
      expect(e.geplantAm, DateTime(2026, 9, 20));
    });
  });

  group('einsatzAusTermin', () {
    test('Termin oeffnet den Betrieb und hat keinen Betrag', () {
      final t = TerminDto(
        id: 't1',
        userId: 'u',
        betriebId: 'b1',
        datum: DateTime(2026, 9, 20),
        uhrzeitVon: '08:00',
        uhrzeitBis: null,
        typ: 'endreinigung',
        anlass: 'saisonende',
        titel: 'Endreinigung Piz Piz',
        notizen: null,
        status: 'geplant',
      );
      final e = einsatzAusTermin(t, betrieb: betrieb());
      expect(e.typ, EinsatzTyp.termin);
      expect(e.typLabel, 'Termin Endreinigung');
      expect(e.zeit, '08:00');
      expect(e.betragCHF, isNull);
      expect(e.status, EinsatzStatus.geplant);
      expect(e.detailRoute, '/betriebe/b1');
    });
  });

  group('filtereEinsaetze', () {
    final calanda = einsatzAusReinigung(
      ReinigungLocal()
        ..serverId = 'r1'
        ..userId = 'u'
        ..anlageId = 'a1'
        ..betriebId = 'b1'
        ..datum = DateTime(2026, 9, 15)
        ..status = 'abgeschlossen',
      betrieb: betrieb(),
      hatBuchung: true,
    );
    final stoerungDavos = einsatzAusStoerung(
      StoerungLocal()
        ..serverId = 's1'
        ..userId = 'u'
        ..betriebId = 'b2'
        ..datum = DateTime(2026, 8, 3)
        ..status = 'offen'
        ..problemBeschreibung = 'x'
        ..anlageTyp = 'david',
      betrieb: BetriebLocal()
        ..serverId = 'b2'
        ..name = 'Roessli'
        ..ort = 'Davos'
        ..regionId = 'r2',
    );
    final alle = [calanda, stoerungDavos];

    test('ohne Filter bleibt alles', () {
      expect(
        filtereEinsaetze(alle, const EinsatzFilter(jahr: 2026)),
        hasLength(2),
      );
    });

    test('Typ-Filter', () {
      final f = const EinsatzFilter(jahr: 2026, typen: {EinsatzTyp.stoerung});
      expect(filtereEinsaetze(alle, f).single.typ, EinsatzTyp.stoerung);
    });

    test('Status-Filter', () {
      final f = const EinsatzFilter(jahr: 2026, status: {EinsatzStatus.offen});
      expect(filtereEinsaetze(alle, f).single.betriebName, 'Roessli');
    });

    test('Monat', () {
      expect(
        filtereEinsaetze(
          alle,
          const EinsatzFilter(jahr: 2026, monat: 8),
        ).single.betriebName,
        'Roessli',
      );
    });

    test('Region', () {
      expect(
        filtereEinsaetze(
          alle,
          const EinsatzFilter(jahr: 2026, regionIds: {'r1'}),
        ).single.betriebName,
        'Calanda',
      );
    });

    test('Suche findet ueber den Ort — A9', () {
      expect(
        filtereEinsaetze(
          alle,
          const EinsatzFilter(jahr: 2026, suche: 'davos'),
        ).single.betriebName,
        'Roessli',
      );
    });

    test(
      'Stoerungs-Zusatzfilter greift nur, wenn genau Stoerung gewaehlt ist',
      () {
        final nurStoerung = const EinsatzFilter(
          jahr: 2026,
          typen: {EinsatzTyp.stoerung},
          anlageTyp: 'heigenie',
        );
        expect(
          filtereEinsaetze(alle, nurStoerung),
          isEmpty,
          reason: 'david != heigenie',
        );

        final beideTypen = const EinsatzFilter(
          jahr: 2026,
          typen: {EinsatzTyp.stoerung, EinsatzTyp.reinigung},
          anlageTyp: 'heigenie',
        );
        expect(
          filtereEinsaetze(alle, beideTypen),
          hasLength(2),
          reason: 'bei mehreren Typen wird der Zusatzfilter ignoriert',
        );
      },
    );

    test('Sortierung: neuestes Datum zuerst', () {
      expect(
        filtereEinsaetze(
          alle,
          const EinsatzFilter(jahr: 2026),
        ).first.betriebName,
        'Calanda',
      );
    });
  });

  group('einsatzAusPikett', () {
    test('zeigt die Kalenderwoche im Namen (Daniel 23.09.2026)', () {
      final p = PikettDienstLocal()
        ..userId = 'u'
        // Freitag 18.09.2026 bis Sonntag 20.09.2026 = KW 38
        ..datumStart = DateTime(2026, 9, 18)
        ..datumEnde = DateTime(2026, 9, 20);
      expect(einsatzAusPikett(p).betriebName, 'Pikettdienst KW 38');
    });

    test('KW am Jahreswechsel nach ISO (Fr 01.01.2027 = KW 53)', () {
      final p = PikettDienstLocal()
        ..userId = 'u'
        ..datumStart = DateTime(2027, 1, 1)
        ..datumEnde = DateTime(2027, 1, 3);
      expect(einsatzAusPikett(p).betriebName, 'Pikettdienst KW 53');
    });
  });
}
