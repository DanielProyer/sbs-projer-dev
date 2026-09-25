import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_regeln.dart';

Einsatz einsatz({
  EinsatzTyp typ = EinsatzTyp.reinigung,
  EinsatzStatus status = EinsatzStatus.verrechnet,
  double? betrag = 94.05,
  int tag = 12,
  String name = 'Calanda',
}) => Einsatz(
  typ: typ,
  typLabel: einsatzTypLabel(typ),
  routeId: '$name-$tag',
  betriebId: 'b1',
  betriebName: name,
  betriebOrt: 'Chur',
  betriebNr: null,
  regionId: null,
  datum: DateTime(2026, 8, tag),
  status: status,
  kennzeichen: EinsatzKennzeichen.keines,
  betragCHF: betrag,
);

MonatsKontext kontext({
  List<Einsatz> einsaetze = const [],
  int mailRechnungenOffen = 0,
  String? heinekenStatus = 'freigegeben',
  bool heinekenErtragGebucht = true,
  String? heinekenRechnungId = 'h1',
  String? heinekenRechnungsnummer = 'RE-2026-0815',
  Set<String> bergTage = const {},
  Set<String> pauschalenTage = const {},
  List<({DateTime von, DateTime bis})>? camtDeckung,
  int offenePrueflisteImMonat = 0,
  Set<int> lohnMonate = const {8},
  int monat = 8,
  DateTime? heute,
}) => MonatsKontext(
  jahr: 2026,
  monat: monat,
  heute: heute ?? DateTime(2026, 9, 16),
  einsaetze: einsaetze,
  mailRechnungenOffen: mailRechnungenOffen,
  heinekenStatus: heinekenStatus,
  heinekenErtragGebucht: heinekenErtragGebucht,
  heinekenRechnungId: heinekenRechnungId,
  heinekenRechnungsnummer: heinekenRechnungsnummer,
  bergTage: bergTage,
  pauschalenTage: pauschalenTage,
  camtDeckung:
      camtDeckung ?? [(von: DateTime(2026, 8, 1), bis: DateTime(2026, 8, 31))],
  offenePrueflisteImMonat: offenePrueflisteImMonat,
  lohnMonate: lohnMonate,
);

Pruefbefund lauf(String regelId, MonatsKontext k) =>
    alleMonatsRegeln().firstWhere((r) => r.id == regelId).pruefe(k);

void main() {
  group('reinigungen_offen', () {
    test('alles abgeschlossen ist gruen', () {
      final b = lauf('reinigungen_offen', kontext(einsaetze: [einsatz()]));
      expect(b.status, PruefStatus.gruen);
    });
    test('eine offene Reinigung ist rot und nennt die Zahl', () {
      final b = lauf(
        'reinigungen_offen',
        kontext(
          einsaetze: [
            einsatz(),
            einsatz(status: EinsatzStatus.inArbeit, tag: 14, name: 'Roessli'),
          ],
        ),
      );
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('1'));
      expect(b.aktionRoute, '/einsaetze?typ=reinigung');
    });
    test('Stoerungen zaehlen hier nicht mit', () {
      final b = lauf(
        'reinigungen_offen',
        kontext(
          einsaetze: [
            einsatz(typ: EinsatzTyp.stoerung, status: EinsatzStatus.offen),
          ],
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });
  });

  group('einsaetze_offen', () {
    test('erledigte Stoerungen und Montagen sind gruen', () {
      final b = lauf(
        'einsaetze_offen',
        kontext(
          einsaetze: [
            einsatz(typ: EinsatzTyp.stoerung, status: EinsatzStatus.erledigt),
            einsatz(typ: EinsatzTyp.montage, status: EinsatzStatus.verrechnet),
          ],
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });
    test('offene oder geplante sind rot', () {
      for (final s in [
        EinsatzStatus.offen,
        EinsatzStatus.geplant,
        EinsatzStatus.inArbeit,
      ]) {
        final b = lauf(
          'einsaetze_offen',
          kontext(
            einsaetze: [einsatz(typ: EinsatzTyp.stoerung, status: s)],
          ),
        );
        expect(b.status, PruefStatus.rot, reason: '$s');
      }
    });
  });

  group('ertragsbuchungen', () {
    test('verrechnete Reinigungen sind gruen', () {
      final b = lauf('ertragsbuchungen', kontext(einsaetze: [einsatz()]));
      expect(b.status, PruefStatus.gruen);
    });
    test('abgeschlossen ohne Buchung ist rot', () {
      final b = lauf(
        'ertragsbuchungen',
        kontext(einsaetze: [einsatz(status: EinsatzStatus.erledigt)]),
      );
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('1'));
      expect(b.aktionRoute, '/rechnungen');
    });
    test('Kulanz zaehlt nicht — sie traegt keinen Betrag', () {
      final b = lauf(
        'ertragsbuchungen',
        kontext(
          einsaetze: [einsatz(status: EinsatzStatus.erledigt, betrag: null)],
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });
    test('Stoerungen zaehlen hier nicht', () {
      final b = lauf(
        'ertragsbuchungen',
        kontext(
          einsaetze: [
            einsatz(typ: EinsatzTyp.stoerung, status: EinsatzStatus.erledigt),
          ],
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });
  });

  group('versandvermerk', () {
    test('keine offene Mail-Rechnung ist gruen', () {
      expect(lauf('versandvermerk', kontext()).status, PruefStatus.gruen);
    });
    test('offene Mail-Rechnungen sind rot', () {
      final b = lauf('versandvermerk', kontext(mailRechnungenOffen: 2));
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('2'));
      expect(b.aktionRoute, '/rechnungen');
    });
  });

  group('heineken_rechnung', () {
    test('Rechnung vorhanden ist gruen', () {
      expect(
        lauf('heineken_rechnung', kontext(heinekenStatus: 'offen')).status,
        PruefStatus.gruen,
      );
    });
    test('keine Rechnung ist rot', () {
      final b = lauf('heineken_rechnung', kontext(heinekenStatus: null));
      expect(b.status, PruefStatus.rot);
      expect(b.aktionRoute, '/heineken');
    });
    test('im laufenden Monat nur gelb', () {
      final b = lauf(
        'heineken_rechnung',
        kontext(monat: 9, heinekenStatus: null, heute: DateTime(2026, 9, 16)),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('läuft noch'));
    });
  });

  group('heineken_gesendet', () {
    test('gesendet und spaeter sind gruen', () {
      for (final s in ['gesendet', 'freigegeben', 'bezahlt']) {
        expect(
          lauf('heineken_gesendet', kontext(heinekenStatus: s)).status,
          PruefStatus.gruen,
          reason: s,
        );
      }
    });
    test('offen ist gelb', () {
      expect(
        lauf('heineken_gesendet', kontext(heinekenStatus: 'offen')).status,
        PruefStatus.gelb,
      );
    });
    test('ohne Rechnung gelb, ohne doppelten Alarm', () {
      final b = lauf('heineken_gesendet', kontext(heinekenStatus: null));
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('Rechnung'));
    });
  });

  group('heineken_freigegeben', () {
    test('freigegeben und bezahlt sind gruen', () {
      for (final s in ['freigegeben', 'bezahlt']) {
        expect(
          lauf('heineken_freigegeben', kontext(heinekenStatus: s)).status,
          PruefStatus.gruen,
          reason: s,
        );
      }
    });
    test('gesendet ist gelb — Ertrag noch nicht gebucht', () {
      final b = lauf(
        'heineken_freigegeben',
        kontext(heinekenStatus: 'gesendet'),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('Ertrag'));
    });
    test('freigegeben/bezahlt OHNE Ertragsbuchung ist rot (R3)', () {
      for (final s in ['freigegeben', 'bezahlt']) {
        final b = lauf(
          'heineken_freigegeben',
          kontext(heinekenStatus: s, heinekenErtragGebucht: false),
        );
        expect(b.status, PruefStatus.rot, reason: s);
        expect(b.ist, 'ohne Ertragsbuchung');
        expect(
          b.hinweis,
          contains('Heineken-Rechnung RE-2026-0815 ohne Ertragsbuchung'),
        );
        // Führt zum Nachhol-Knopf im Detail der Rechnung.
        expect(b.aktionRoute, '/heineken/h1');
      }
    });
    test('gesendet ohne Buchung bleibt gelb — dort ist keine faellig', () {
      final b = lauf(
        'heineken_freigegeben',
        kontext(heinekenStatus: 'gesendet', heinekenErtragGebucht: false),
      );
      expect(b.status, PruefStatus.gelb);
    });
  });

  group('bergkundenpauschalen', () {
    test('keine Bergkunden im Monat ist gruen', () {
      expect(lauf('bergkundenpauschalen', kontext()).status, PruefStatus.gruen);
    });
    test('jeder Berg-Tag hat seine Pauschale', () {
      final b = lauf(
        'bergkundenpauschalen',
        kontext(
          bergTage: const {'b9|2026-08-12', 'b9|2026-08-20'},
          pauschalenTage: const {'b9|2026-08-12', 'b9|2026-08-20'},
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });
    test('fehlende Pauschale ist gelb und nennt die Zahl', () {
      final b = lauf(
        'bergkundenpauschalen',
        kontext(
          bergTage: const {'b9|2026-08-12', 'b9|2026-08-20'},
          pauschalenTage: const {'b9|2026-08-12'},
        ),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.ist, contains('1'));
      expect(b.aktionRoute, '/bergkundenpauschalen');
    });
  });

  group('bank_abgedeckt', () {
    test('Datei deckt den Monat, Pruefliste leer — gruen', () {
      expect(lauf('bank_abgedeckt', kontext()).status, PruefStatus.gruen);
    });
    test('keine Datei ist gelb', () {
      final b = lauf('bank_abgedeckt', kontext(camtDeckung: const []));
      expect(b.status, PruefStatus.gelb);
      expect(b.aktionRoute, '/buchhaltung/camt-import');
    });
    test('Datei deckt nur einen Teil ist gelb', () {
      final b = lauf(
        'bank_abgedeckt',
        kontext(
          camtDeckung: [
            (von: DateTime(2026, 8, 1), bis: DateTime(2026, 8, 20)),
          ],
        ),
      );
      expect(b.status, PruefStatus.gelb);
    });
    test('mehrere Dateien duerfen den Monat gemeinsam decken', () {
      final b = lauf(
        'bank_abgedeckt',
        kontext(
          camtDeckung: [
            (von: DateTime(2026, 7, 25), bis: DateTime(2026, 8, 15)),
            (von: DateTime(2026, 8, 16), bis: DateTime(2026, 9, 5)),
          ],
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });
    test('offene Prueflisten-Eintraege sind gelb', () {
      final b = lauf('bank_abgedeckt', kontext(offenePrueflisteImMonat: 4));
      expect(b.status, PruefStatus.gelb);
      expect(b.ist, contains('4'));
      expect(b.aktionRoute, '/buchhaltung/camt-pruefliste');
    });
    test('im laufenden Monat nur gelb, ohne Vorwurf', () {
      final b = lauf(
        'bank_abgedeckt',
        kontext(monat: 9, camtDeckung: const [], heute: DateTime(2026, 9, 16)),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('läuft noch'));
    });
  });

  group('lohnlauf', () {
    test('Abrechnung vorhanden ist gruen', () {
      expect(
        lauf('lohnlauf', kontext(lohnMonate: const {8})).status,
        PruefStatus.gruen,
      );
    });
    test('fehlende Abrechnung ist gelb', () {
      final b = lauf('lohnlauf', kontext(lohnMonate: const {7}));
      expect(b.status, PruefStatus.gelb);
      expect(b.aktionRoute, '/buchhaltung/lohn');
    });
    test('im laufenden Monat nur gelb mit Hinweis', () {
      final b = lauf(
        'lohnlauf',
        kontext(monat: 9, lohnMonate: const {}, heute: DateTime(2026, 9, 16)),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('läuft noch'));
    });
  });
}
