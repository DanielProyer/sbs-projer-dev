import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';

final heute = DateTime(2026, 9, 15, 10, 30);
final heuteTag = DateTime(2026, 9, 15);

Einsatz einsatz({
  EinsatzTyp typ = EinsatzTyp.stoerung,
  String name = 'Calanda',
  EinsatzStatus status = EinsatzStatus.offen,
  DateTime? datum,
  DateTime? geplantAm,
  String? zeit,
  String? beschreibung = 'Zapfhahn tropft',
}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: 'x1',
  betriebId: 'b1',
  betriebName: name,
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: datum ?? DateTime(2026, 9, 10),
  geplantAm: geplantAm,
  zeit: zeit,
  beschreibung: beschreibung,
  status: status,
  kennzeichen: EinsatzKennzeichen.keines,
);

AufgabenEintrag eintrag(
  AufgabenQuelle q, {
  DateTime? faellig,
  bool dringend = false,
}) => AufgabenEintrag(
  quelle: q,
  key: 'k',
  titel: 't',
  faellig: faellig,
  dringend: dringend,
);

void main() {
  group('einsatzFaelligkeit', () {
    test('geplanter Tag vor Meldedatum', () {
      expect(
        einsatzFaelligkeit(
          einsatz(
            datum: DateTime(2026, 9, 10),
            geplantAm: DateTime(2026, 9, 17),
          ),
        ),
        DateTime(2026, 9, 17),
      );
    });
    test('ohne Plan das Meldedatum', () {
      expect(
        einsatzFaelligkeit(einsatz(datum: DateTime(2026, 9, 10))),
        DateTime(2026, 9, 10),
      );
    });
  });

  group('jetztFaellig', () {
    test('Detektor und Aenderungsvorschlag immer', () {
      expect(jetztFaellig(eintrag(AufgabenQuelle.detektor), heute), isTrue);
      expect(
        jetztFaellig(eintrag(AufgabenQuelle.aenderungsVorschlag), heute),
        isTrue,
      );
    });
    test('eigene: 7 Tage voraus sichtbar, 8 nicht, ohne Datum immer', () {
      expect(
        jetztFaellig(
          eintrag(AufgabenQuelle.eigene, faellig: DateTime(2026, 9, 22)),
          heute,
        ),
        isTrue,
      );
      expect(
        jetztFaellig(
          eintrag(AufgabenQuelle.eigene, faellig: DateTime(2026, 9, 23)),
          heute,
        ),
        isFalse,
      );
      expect(jetztFaellig(eintrag(AufgabenQuelle.eigene), heute), isTrue);
    });
    test('Einsatz, Saison-Vorschlag, Termin: erst heute oder ueberfaellig', () {
      for (final q in [
        AufgabenQuelle.einsatz,
        AufgabenQuelle.saisonVorschlag,
        AufgabenQuelle.termin,
      ]) {
        expect(
          jetztFaellig(eintrag(q, faellig: DateTime(2026, 9, 14)), heute),
          isTrue,
          reason: '$q gestern',
        );
        expect(
          jetztFaellig(eintrag(q, faellig: DateTime(2026, 9, 15, 23)), heute),
          isTrue,
          reason: '$q heute',
        );
        expect(
          jetztFaellig(eintrag(q, faellig: DateTime(2026, 9, 16)), heute),
          isFalse,
          reason: '$q morgen',
        );
        expect(
          jetztFaellig(eintrag(q), heute),
          isFalse,
          reason: '$q ohne Datum',
        );
      }
    });
  });

  group('faelligText', () {
    test('ueberfaellig, heute, morgen, Datum, ohne', () {
      expect(
        faelligText(DateTime(2026, 9, 12), heute),
        'überfällig seit 3 Tagen',
      );
      expect(
        faelligText(DateTime(2026, 9, 14), heute),
        'überfällig seit 1 Tag',
      );
      expect(faelligText(DateTime(2026, 9, 15), heute), 'heute');
      expect(faelligText(DateTime(2026, 9, 16), heute), 'morgen');
      expect(faelligText(DateTime(2026, 9, 17), heute), 'Do 17.09.');
      expect(faelligText(null, heute), '');
    });
  });

  group('baueAufgabenListe', () {
    List<AufgabenEintrag> baue({
      List<Aufgabe> detektoren = const [],
      List<Map<String, dynamic>> zeilen = const [],
      List<Einsatz> anstehend = const [],
      List<SaisonVorschlag> vorschlaege = const [],
      List<SaisonTerminEintrag> termine = const [],
      int aenderungsVorschlaege = 0,
    }) => baueAufgabenListe(
      detektoren: detektoren,
      aufgabenZeilen: zeilen,
      anstehend: anstehend,
      saisonVorschlaege: vorschlaege,
      saisonTermine: termine,
      aenderungsVorschlaege: aenderungsVorschlaege,
      heute: heute,
    );

    test('Detektor wird zum Eintrag mit Faelligkeit heute und Route', () {
      final l = baue(
        detektoren: [
          const Aufgabe(
            key: 'heineken:2026-08',
            titel: 'Heineken August',
            dringend: true,
            route: '/heineken',
          ),
        ],
      );
      expect(l.single.quelle, AufgabenQuelle.detektor);
      expect(l.single.faellig, heuteTag);
      expect(l.single.route, '/heineken');
      expect(l.single.dringend, isTrue);
      expect(l.single.snoozebar, isTrue);
      expect(
        l.single.erledigbar,
        isFalse,
        reason: 'nur MWST ist manuell erledigbar',
      );
    });

    test('gesnoozter Detektor fehlt, abgelaufener Snooze nicht', () {
      final det = [const Aufgabe(key: 'mahnlauf', titel: 'Mahnlauf')];
      expect(
        baue(
          detektoren: det,
          zeilen: [
            {'typ': 'snooze', 'key': 'mahnlauf', 'snooze_bis': '2026-09-16'},
          ],
        ),
        isEmpty,
      );
      expect(
        baue(
          detektoren: det,
          zeilen: [
            {'typ': 'snooze', 'key': 'mahnlauf', 'snooze_bis': '2026-09-14'},
          ],
        ),
        hasLength(1),
      );
    });

    test(
      'eigene Aufgaben: alle offenen, auch kuenftige; erledigte nicht; dringend ab heute',
      () {
        final l = baue(
          zeilen: [
            {
              'typ': 'eigene',
              'id': 'a1',
              'titel': 'Filter bestellen',
              'faellig_am': '2026-10-01',
              'erledigt_am': null,
            },
            {
              'typ': 'eigene',
              'id': 'a2',
              'titel': 'Anrufen',
              'faellig_am': '2026-09-15',
              'erledigt_am': null,
            },
            {
              'typ': 'eigene',
              'id': 'a3',
              'titel': 'Alt',
              'faellig_am': '2026-09-01',
              'erledigt_am': '2026-09-02',
            },
          ],
        );
        expect(l.map((e) => e.titel), ['Anrufen', 'Filter bestellen']);
        expect(l[0].dringend, isTrue);
        expect(l[0].eigeneId, 'a2');
        expect(l[0].key, 'eigene:a2');
        expect(l[0].erledigbar, isTrue);
        expect(l[1].dringend, isFalse);
      },
    );

    test('gesnoozte eigene Aufgabe fehlt', () {
      expect(
        baue(
          zeilen: [
            {
              'typ': 'eigene',
              'id': 'a1',
              'titel': 'x',
              'faellig_am': null,
              'erledigt_am': null,
            },
            {'typ': 'snooze', 'key': 'eigene:a1', 'snooze_bis': '2026-09-20'},
          ],
        ),
        isEmpty,
      );
    });

    test(
      'Einsatz: Titel, Untertitel mit Planungstext, Faelligkeit aus geplantAm, einplanbar',
      () {
        final l = baue(
          anstehend: [
            einsatz(
              status: EinsatzStatus.geplant,
              geplantAm: DateTime(2026, 9, 17),
              zeit: '14:00',
            ),
          ],
        );
        final e = l.single;
        expect(e.quelle, AufgabenQuelle.einsatz);
        expect(e.titel, 'Störung Calanda');
        expect(e.untertitel, 'Zapfhahn tropft · 17.09. 14:00');
        expect(e.faellig, DateTime(2026, 9, 17));
        expect(e.route, '/stoerungen/x1');
        expect(e.key, 'einsatz:stoerung:x1');
        expect(e.einplanbar, isTrue);
        expect(e.snoozebar, isFalse);
        expect(e.dringend, isFalse);
      },
    );

    test(
      'Stoerung ohne Termin ist dringend; Eigenauftrag nicht einplanbar',
      () {
        final l = baue(
          anstehend: [
            einsatz(status: EinsatzStatus.offen),
            einsatz(
              typ: EinsatzTyp.eigenauftrag,
              status: EinsatzStatus.inArbeit,
              beschreibung: null,
            ),
          ],
        );
        expect(
          l.firstWhere((e) => e.einsatz!.typ == EinsatzTyp.stoerung).dringend,
          isTrue,
        );
        final ea = l.firstWhere(
          (e) => e.einsatz!.typ == EinsatzTyp.eigenauftrag,
        );
        expect(ea.einplanbar, isFalse);
        expect(ea.untertitel, 'nicht geplant');
      },
    );

    test(
      'Saison-Vorschlag wird von einem bestaetigten Termin (±7 Tage) verdeckt',
      () {
        final SaisonVorschlag vorschlag = (
          betriebId: 'b9',
          betriebName: 'Piz Piz',
          betriebOrt: 'Lenzerheide',
          typ: 'endreinigung',
          zielDatum: DateTime(2026, 10, 20),
          beschreibung: 'Endreinigung',
        );
        final ohne = baue(vorschlaege: [vorschlag]);
        expect(ohne.single.quelle, AufgabenQuelle.saisonVorschlag);
        expect(ohne.single.titel, 'Endreinigung Piz Piz');
        expect(ohne.single.bestaetigbar, isTrue);
        expect(ohne.single.saison!.anlass, 'saisonende');
        expect(ohne.single.route, '/betriebe/b9');

        final mit = baue(
          vorschlaege: [vorschlag],
          termine: [
            (
              id: 't1',
              betriebId: 'b9',
              betriebName: 'Piz Piz',
              betriebOrt: 'Lenzerheide',
              typ: 'endreinigung',
              datum: DateTime(2026, 10, 22),
              titel: 'Endreinigung Piz Piz',
            ),
          ],
        );
        expect(mit.map((e) => e.quelle), [AufgabenQuelle.termin]);
        expect(mit.single.terminId, 't1');
        expect(mit.single.erledigbar, isTrue);
      },
    );

    test(
      'Aenderungsvorschlaege: ein Eintrag, snoozebar, Route zur Pruefliste',
      () {
        final l = baue(aenderungsVorschlaege: 4);
        expect(l.single.titel, '4 Änderungsvorschläge prüfen');
        expect(l.single.key, 'vorschlaege');
        expect(l.single.route, '/betriebe/vorschlaege');
        expect(l.single.snoozebar, isTrue);
        expect(baue(aenderungsVorschlaege: 0), isEmpty);
      },
    );

    test(
      'Sortierung: Faelligkeit aufsteigend, ohne Datum zuletzt, am selben Tag dringend und Quelle',
      () {
        final l = baue(
          detektoren: [const Aufgabe(key: 'mahnlauf', titel: 'Mahnlauf')],
          zeilen: [
            {
              'typ': 'eigene',
              'id': 'a1',
              'titel': 'Ohne Datum',
              'faellig_am': null,
              'erledigt_am': null,
            },
            {
              'typ': 'eigene',
              'id': 'a2',
              'titel': 'Heute eigene',
              'faellig_am': '2026-09-15',
              'erledigt_am': null,
            },
          ],
          anstehend: [
            einsatz(
              name: 'Gestern',
              datum: DateTime(2026, 9, 14),
              status: EinsatzStatus.offen,
            ),
            einsatz(
              name: 'Morgen',
              geplantAm: DateTime(2026, 9, 16),
              status: EinsatzStatus.geplant,
            ),
          ],
        );
        expect(l.map((e) => e.titel), [
          'Störung Gestern', // 14.09.
          'Heute eigene', // 15.09., dringend (faellig heute)
          'Mahnlauf', // 15.09., nicht dringend
          'Störung Morgen', // 16.09.
          'Ohne Datum',
        ]);
      },
    );
  });
}
