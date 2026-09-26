import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';

void main() {
  _buchungsTests();
  _versandvermerkTests();
  _protokollFehltTests();
  _draussenTests();

  group('heinekenAufgabe', () {
    // heute 05.08.2026 -> Vormonat Juli 2026
    final heute = DateTime(2026, 8, 5);
    test('keine Rechnung -> Stufe erstellen', () {
      final a = heinekenAufgabe(
        heute: heute,
        rechnungExistiert: false,
        rechnungOffen: false,
      );
      expect(a, isNotNull);
      expect(a!.key, 'heineken:2026-07');
      expect(a.titel, contains('erstellen'));
      expect(a.titel, contains('Juli'));
    });
    test('Rechnung offen -> Stufe versenden', () {
      final a = heinekenAufgabe(
        heute: heute,
        rechnungExistiert: true,
        rechnungOffen: true,
      );
      expect(a!.titel, contains('versenden'));
    });
    test('Rechnung gesendet -> erledigt (null)', () {
      expect(
        heinekenAufgabe(
          heute: heute,
          rechnungExistiert: true,
          rechnungOffen: false,
        ),
        isNull,
      );
    });
    test('Färbung: bis 10. orange, danach rot', () {
      expect(
        heinekenAufgabe(
          heute: DateTime(2026, 8, 10),
          rechnungExistiert: false,
          rechnungOffen: false,
        )!.dringend,
        isFalse,
      );
      expect(
        heinekenAufgabe(
          heute: DateTime(2026, 8, 11),
          rechnungExistiert: false,
          rechnungOffen: false,
        )!.dringend,
        isTrue,
      );
    });
    test('Jahreswechsel: Januar erinnert an Dezember', () {
      final a = heinekenAufgabe(
        heute: DateTime(2027, 1, 2),
        rechnungExistiert: false,
        rechnungOffen: false,
      );
      expect(a!.key, 'heineken:2026-12');
      expect(a.titel, contains('Dezember'));
    });
  });

  group('mwstAufgaben', () {
    test('Q2 vorbei -> Aufgabe ab 01.07., Frist 31.08.', () {
      final a = mwstAufgaben(
        heute: DateTime(2026, 7, 22),
        markerKeys: const {},
      ).first;
      expect(a.key, 'mwst:2026-Q2');
      expect(a.titel, contains('Q2'));
      expect(a.dringend, isFalse); // 31.08. ist > 14 Tage entfernt
    });
    test('14 Tage vor Frist -> dringend', () {
      expect(
        mwstAufgaben(
          heute: DateTime(2026, 8, 18),
          markerKeys: const {},
        ).first.dringend,
        isTrue,
      );
    });
    test('nach Frist -> weiterhin sichtbar und dringend', () {
      expect(
        mwstAufgaben(
          heute: DateTime(2026, 9, 15),
          markerKeys: const {},
        ).first.dringend,
        isTrue,
      );
    });
    test('Marker unterdrückt einzelnes Quartal', () {
      final keys = mwstAufgaben(
        heute: DateTime(2026, 7, 22),
        markerKeys: const {'mwst:2026-Q2'},
      ).map((a) => a.key).toList();
      expect(keys, isNot(contains('mwst:2026-Q2')));
    });
    test('Q4: Frist 28.02. im Folgejahr, key mit altem Jahr', () {
      final a = mwstAufgaben(
        heute: DateTime(2027, 1, 10),
        markerKeys: const {},
      ).first;
      expect(a.key, 'mwst:2026-Q4');
    });
    test(
      'Liste: mehrere unmarkierte Quartale gehen nicht verloren (Beispiel)',
      () {
        final keys = mwstAufgaben(
          heute: DateTime(2026, 7, 22),
          markerKeys: const {},
        ).map((a) => a.key).toList();
        expect(keys, [
          'mwst:2026-Q2',
          'mwst:2026-Q1',
          'mwst:2025-Q4',
          'mwst:2025-Q3',
        ]);
      },
    );
    test('Liste: mit Marker für Q1 und ältere -> nur Q2', () {
      final keys = mwstAufgaben(
        heute: DateTime(2026, 7, 22),
        markerKeys: const {'mwst:2026-Q1', 'mwst:2025-Q4', 'mwst:2025-Q3'},
      ).map((a) => a.key).toList();
      expect(keys, ['mwst:2026-Q2']);
    });
    test('Ablösung: Q1 unmarkiert bleibt auch nach Q2-Ende in der Liste', () {
      final keys = mwstAufgaben(
        heute: DateTime(2026, 10, 5),
        markerKeys: const {},
      ).map((a) => a.key).toList();
      expect(keys, contains('mwst:2026-Q1'));
      expect(keys, contains('mwst:2026-Q3'));
    });
    test('alle markiert -> leere Liste', () {
      final aufgaben = mwstAufgaben(
        heute: DateTime(2026, 7, 22),
        markerKeys: const {
          'mwst:2026-Q2',
          'mwst:2026-Q1',
          'mwst:2025-Q4',
          'mwst:2025-Q3',
        },
      );
      expect(aufgaben, isEmpty);
    });
    test('April -> erstes Element ist Q1', () {
      final a = mwstAufgaben(
        heute: DateTime(2026, 4, 15),
        markerKeys: const {},
      ).first;
      expect(a.key, 'mwst:2026-Q1');
    });
    test('Oktober -> erstes Element ist Q3', () {
      final a = mwstAufgaben(
        heute: DateTime(2026, 10, 15),
        markerKeys: const {},
      ).first;
      expect(a.key, 'mwst:2026-Q3');
    });
    test('Schaltjahr Q4: heute 10.01.2028 -> Q4/2027, Frist 28.02.2028', () {
      final a = mwstAufgaben(
        heute: DateTime(2028, 1, 10),
        markerKeys: const {},
      ).first;
      expect(a.key, 'mwst:2027-Q4');
      expect(a.titel, contains('28.02.2028'));
    });
  });

  group('mahnlauf/saisondaten', () {
    test('Zähler > 0 -> Aufgabe mit Anzahl, = 0 -> null', () {
      expect(mahnlaufAufgabe(3)!.titel, contains('3'));
      expect(mahnlaufAufgabe(0), isNull);
      expect(saisondatenAufgabe(15)!.titel, contains('15'));
    });
    test('Mahnlauf zählt Betriebe, führt zur Mahnlauf-Seite, Bank-Sperre hat Vorrang', () {
      expect(mahnlaufAufgabe(3)!.titel, 'Mahnlauf: 3 Betriebe fällig');
      expect(mahnlaufAufgabe(1)!.titel, 'Mahnlauf: 1 Betrieb fällig');
      expect(mahnlaufAufgabe(3)!.route, '/rechnungen/mahnlauf');
      expect(
        mahnlaufAufgabe(2, bankGesperrt: true)!.titel,
        'Mahnlauf: zuerst Bankauszug einlesen',
      );
      expect(mahnlaufAufgabe(0, bankGesperrt: true), isNull);
      expect(saisondatenAufgabe(0), isNull);
    });
    test('Eskalation: eigene Aufgabe «Heineken einschalten»', () {
      expect(eskalationAufgabe(0), isNull);
      final a = eskalationAufgabe(2)!;
      expect(a.key, 'mahnlauf:eskalation');
      expect(a.titel, 'Mahnlauf: 2 Betriebe — Heineken einschalten');
      expect(a.route, '/rechnungen/mahnlauf');
      expect(eskalationAufgabe(1)!.titel, 'Mahnlauf: 1 Betrieb — Heineken einschalten');
    });
  });

  group('Snooze + eigene + Sortierung', () {
    final heute = DateTime(2026, 7, 22);
    test('snoozeAktiv: bis heute inkl., abgelaufen nicht', () {
      expect(snoozeAktiv(DateTime(2026, 7, 22), heute), isTrue);
      expect(snoozeAktiv(DateTime(2026, 7, 21), heute), isFalse);
      expect(snoozeAktiv(null, heute), isFalse);
    });
    test('eigeneSichtbar: ohne Datum sofort, mit Datum ab Fällig-7', () {
      expect(eigeneSichtbar(null, heute), isTrue);
      expect(
        eigeneSichtbar(DateTime(2026, 7, 29), heute),
        isTrue,
      ); // genau 7 Tage
      expect(eigeneSichtbar(DateTime(2026, 7, 30), heute), isFalse); // 8 Tage
    });
    test('eigeneSichtbar: Zeitanteil von faelligAm wird ignoriert', () {
      expect(
        eigeneSichtbar(DateTime(2026, 7, 29, 23, 30), DateTime(2026, 7, 22)),
        isTrue,
      );
    });
    test('sortiereAufgaben: dringend zuerst, dann Rest stabil', () {
      final l = [
        const Aufgabe(key: 'a', titel: 'A', dringend: false),
        const Aufgabe(key: 'b', titel: 'B', dringend: true),
        const Aufgabe(key: 'c', titel: 'C', dringend: false),
      ];
      final s = sortiereAufgaben(l);
      expect(s.map((a) => a.key).toList(), ['b', 'a', 'c']);
    });
  });

  group('bankPrueflisteAufgabe', () {
    test('leere Pruefliste ergibt nichts', () {
      expect(bankPrueflisteAufgabe(0), isNull);
    });
    test('Einzahl und Mehrzahl', () {
      expect(bankPrueflisteAufgabe(1)!.titel, '1 Bank-Buchung prüfen');
      expect(bankPrueflisteAufgabe(23)!.titel, '23 Bank-Buchungen prüfen');
    });
    test('ist ein Vorrat und zeigt auf die Pruefliste', () {
      final a = bankPrueflisteAufgabe(5)!;
      expect(a.istVorrat, isTrue);
      expect(a.route, '/buchhaltung/camt-pruefliste');
      expect(a.key, 'bank_pruefliste');
      expect(a.dringend, isFalse, reason: 'ein Stapel ist nicht dringend');
    });
  });

  group('eingangsrechnungenAufgabe', () {
    test('nichts offen ergibt nichts', () {
      expect(eingangsrechnungenAufgabe(0), isNull);
    });
    test('Einzahl und Mehrzahl', () {
      expect(eingangsrechnungenAufgabe(1)!.titel, '1 Eingangsrechnung offen');
      expect(eingangsrechnungenAufgabe(7)!.titel, '7 Eingangsrechnungen offen');
    });
    test('ist ein Vorrat und zeigt auf die Eingangsrechnungen', () {
      final a = eingangsrechnungenAufgabe(3)!;
      expect(a.istVorrat, isTrue);
      expect(a.route, '/buchhaltung/eingangsrechnungen');
      expect(a.key, 'eingangsrechnungen_offen');
    });
  });

  group('bestehende Stapel sind Vorraete (B3)', () {
    test('fehlende Buchungen und Versandvermerke', () {
      expect(fehlendeBuchungenAufgabe(2)!.istVorrat, isTrue);
      expect(versandvermerkAufgabe(2)!.istVorrat, isTrue);
      // dringend bleibt: im Buero und im Aufgaben-Screen weiterhin rot.
      expect(fehlendeBuchungenAufgabe(2)!.dringend, isTrue);
    });
    test('Fristen bleiben Fristen', () {
      expect(mahnlaufAufgabe(3)!.istVorrat, isFalse);
    });
    test('Saison-Zaehler sind seit V8 Vorraete (Band + Tourenplan bleiben)', () {
      expect(saisondatenAufgabe(3)!.istVorrat, isTrue);
      expect(saisonLueckeAufgabe(3)!.istVorrat, isTrue);
    });
  });

  group('monatsabschlussAufgabe', () {
    test('nichts offen ergibt nichts', () {
      expect(monatsabschlussAufgabe(0, 'August'), isNull);
    });
    test('Titel nennt Monat und Zahl', () {
      expect(monatsabschlussAufgabe(1, 'August')!.titel,
          'Monatsabschluss August: 1 Punkt offen');
      expect(monatsabschlussAufgabe(3, 'August')!.titel,
          'Monatsabschluss August: 3 Punkte offen');
    });
    test('ist ein Vorrat und zeigt auf den Screen', () {
      final a = monatsabschlussAufgabe(3, 'August')!;
      expect(a.istVorrat, isTrue);
      expect(a.route, '/buchhaltung/monatsabschluss');
      expect(a.key, 'monatsabschluss');
    });
  });
}

/// Versandvermerk-Wächter — nachgerüstet am 10.09.2026.
///
/// Am 07.09. ging die Rechnung an Signina per Mail raus, der Vermerk in der
/// App kam nicht mehr durch: Sie stand danach auf «offen», obwohl sie beim
/// Kunden lag. Aufgefallen ist das nur, weil Daniel den Postausgang mit der
/// App verglichen hat — und die Gefahr war, sie ein zweites Mal zu senden.
///
/// Die App kann nicht wissen, ob eine Mail rausging. Sie kann aber sagen:
/// Hier stimmt etwas nicht, sieh im Postausgang nach.
void _buchungsTests() {
  group('Waechter fuer fehlende Ertragsbuchungen', () {
    test('stumm, solange nichts fehlt', () {
      expect(fehlendeBuchungenAufgabe(0), isNull);
    });

    test('meldet Einzahl und Mehrzahl', () {
      expect(
        fehlendeBuchungenAufgabe(1)!.titel,
        '1 Reinigung ohne Ertragsbuchung',
      );
      expect(
        fehlendeBuchungenAufgabe(2)!.titel,
        '2 Reinigungen ohne Ertragsbuchung',
      );
    });

    test('dringend und mit Weg zu den Forderungen', () {
      // Ohne Ertragsbuchung fehlt der Umsatz in der Erfolgsrechnung — das
      // faellt sonst erst beim Abschluss auf.
      final a = fehlendeBuchungenAufgabe(2)!;
      expect(a.dringend, isTrue);
      expect(a.route, '/rechnungen');
      expect(a.key, 'fehlende_buchungen');
    });
  });
}

void _versandvermerkTests() {
  group('Versandvermerk-Wächter', () {
    test('ohne Verdachtsfälle stumm', () {
      expect(versandvermerkAufgabe(0), isNull);
    });

    test('meldet Einzahl und Mehrzahl richtig', () {
      expect(
        versandvermerkAufgabe(1)!.titel,
        '1 Mail-Rechnung ohne Versandvermerk — Postausgang prüfen',
      );
      expect(
        versandvermerkAufgabe(3)!.titel,
        '3 Mail-Rechnungen ohne Versandvermerk — Postausgang prüfen',
      );
    });

    test('führt zu den Forderungen und ist dringend', () {
      // Dringend, weil beide möglichen Ursachen Geld kosten: entweder ist die
      // Rechnung nie beim Kunden angekommen, oder sie geht doppelt raus.
      final a = versandvermerkAufgabe(2)!;
      expect(a.route, '/rechnungen');
      expect(a.dringend, isTrue);
      expect(a.key, 'versandvermerk');
    });
  });
}

/// T1/R8: Reinigungen ohne Protokollfoto (Stichtag 26.09.2026).
void _protokollFehltTests() {
  group('protokollFehltAufgabe', () {
    test('0 -> null', () => expect(protokollFehltAufgabe(0), isNull));
    test('1 -> Singular, Vorrat, nicht dringend', () {
      final a = protokollFehltAufgabe(1)!;
      expect(a.key, 'protokoll_fehlt');
      expect(a.titel, '1 Reinigung ohne Protokollfoto');
      expect(a.istVorrat, isTrue);
      expect(a.dringend, isFalse);
      expect(a.route, '/einsaetze?typ=reinigung'); // '/reinigungen' ist keine Route
    });
    test('3 -> Plural', () {
      expect(protokollFehltAufgabe(3)!.titel, '3 Reinigungen ohne Protokollfoto');
    });
  });
}

/// V8/V9 (Analyse-Runde 5): Was auf der Heute-Karte steht, ist «draussen».
void _draussenTests() {
  group('draussen-Kennzeichen', () {
    test('Vorgabe ist Buero', () {
      expect(const Aufgabe(key: 'x', titel: 'X').draussen, isFalse);
    });
    test('Buero-Fristen und Vorraete sind nicht draussen', () {
      final heute = DateTime(2026, 9, 26);
      expect(
        heinekenAufgabe(
          heute: heute,
          rechnungExistiert: false,
          rechnungOffen: false,
        )!.draussen,
        isFalse,
      );
      expect(
        mwstAufgaben(heute: heute, markerKeys: const {}).first.draussen,
        isFalse,
      );
      expect(mahnlaufAufgabe(2)!.draussen, isFalse);
      expect(eskalationAufgabe(2)!.draussen, isFalse);
      expect(saisondatenAufgabe(2)!.draussen, isFalse);
      expect(saisonLueckeAufgabe(2)!.draussen, isFalse);
      expect(versandvermerkAufgabe(2)!.draussen, isFalse);
      expect(fehlendeBuchungenAufgabe(2)!.draussen, isFalse);
    });
  });

  group('angefangeneReinigungAufgaben', () {
    test('je Entwurf eine dringende Aufgabe mit Name, Uhrzeit, Route', () {
      final l = angefangeneReinigungAufgaben(
        [(betriebId: 'b1', gespeichertAm: DateTime(2026, 9, 26, 9, 12))],
        {'b1': 'Hirschen'},
      );
      expect(l, hasLength(1));
      final a = l.single;
      expect(a.key, 'entwurf:b1');
      expect(a.titel, 'Reinigung Hirschen angefangen (09:12)');
      expect(a.route, '/reinigungen/neu?betriebId=b1');
      expect(a.dringend, isTrue);
      expect(a.draussen, isTrue);
      expect(a.istVorrat, isFalse);
    });
    test('unbekannter Betrieb bleibt sichtbar', () {
      final a = angefangeneReinigungAufgaben(
        [(betriebId: 'b9', gespeichertAm: DateTime(2026, 9, 26, 14, 5))],
        const {},
      ).single;
      expect(a.titel, 'Reinigung (unbekannter Betrieb) angefangen (14:05)');
    });
    test('keine Entwuerfe -> leer', () {
      expect(angefangeneReinigungAufgaben(const [], const {}), isEmpty);
    });
  });

  group('laufendeArbeitAufgaben', () {
    final heute = DateTime(2026, 9, 26, 8);
    test('Stoerung und Montage vom Vortag -> Aufgabe mit Bearbeiten-Route', () {
      final l = laufendeArbeitAufgaben([
        (typ: 'stoerung', id: 's1', betriebName: 'Calanda', datum: DateTime(2026, 9, 25)),
        (typ: 'montage', id: 'm1', betriebName: 'Post', datum: DateTime(2026, 9, 20)),
      ], heute);
      expect(l.map((a) => a.route), [
        '/stoerungen/s1/bearbeiten',
        '/montagen/m1/bearbeiten',
      ]);
      expect(l.first.key, 'arbeit_laeuft:stoerung:s1');
      expect(l.first.titel, 'Arbeit läuft seit gestern: Calanda');
      expect(l.every((a) => a.dringend && a.draussen), isTrue);
    });
    test('heute begonnene Arbeit ist kein Fall', () {
      expect(
        laufendeArbeitAufgaben([
          (typ: 'stoerung', id: 's1', betriebName: 'X', datum: DateTime(2026, 9, 26)),
        ], heute),
        isEmpty,
      );
    });
  });

  group('einsatzArbeitLaeuft', () {
    test('offene Status zaehlen', () {
      expect(einsatzArbeitLaeuft('stoerung', 'offen'), isTrue);
      expect(einsatzArbeitLaeuft('stoerung', 'in_bearbeitung'), isTrue);
      expect(einsatzArbeitLaeuft('montage', 'geplant'), isTrue);
      expect(einsatzArbeitLaeuft('montage', 'in_bearbeitung'), isTrue);
    });
    test('abgeschlossen ohne arbeit_bis ist keine laufende Arbeit', () {
      // Produktionsfall Montage 7ff997ec…: abgeschlossen, arbeit_bis NULL.
      expect(einsatzArbeitLaeuft('montage', 'abgeschlossen'), isFalse);
      expect(einsatzArbeitLaeuft('stoerung', 'abgeschlossen'), isFalse);
      expect(einsatzArbeitLaeuft('montage', null), isFalse);
    });
  });

  group('arbeitstagOffenAufgabe', () {
    final heute = DateTime(2026, 9, 26, 7);
    test('Beginn ohne Ende -> Aufgabe zum Tourenplan jenes Tages', () {
      final a = arbeitstagOffenAufgabe(
        [
          (datum: DateTime(2026, 9, 25), beginn: '06:39', ende: null, km: 86284),
        ],
        heute,
      )!;
      expect(a.key, 'arbeitstag_offen:2026-09-25');
      expect(a.titel, 'Arbeitstag 25.09. ohne Feierabend');
      expect(a.route, '/touren?datum=2026-09-25');
      expect(a.draussen, isTrue);
      expect(a.dringend, isTrue);
    });
    test('fehlender km-Stand allein reicht', () {
      final a = arbeitstagOffenAufgabe(
        [(datum: DateTime(2026, 9, 25), beginn: '06:39', ende: '17:00', km: null)],
        heute,
      )!;
      expect(a.titel, 'Arbeitstag 25.09. ohne km-Stand');
    });
    test('beides fehlt', () {
      final a = arbeitstagOffenAufgabe(
        [(datum: DateTime(2026, 9, 25), beginn: '06:39', ende: null, km: null)],
        heute,
      )!;
      expect(a.titel, 'Arbeitstag 25.09. ohne Feierabend und km-Stand');
    });
    test('vollstaendig, ohne Beginn oder heute -> nichts', () {
      expect(
        arbeitstagOffenAufgabe([
          (datum: DateTime(2026, 9, 25), beginn: '06:39', ende: '17:00', km: 1),
          (datum: DateTime(2026, 9, 24), beginn: null, ende: null, km: null),
          (datum: DateTime(2026, 9, 26), beginn: '06:00', ende: null, km: null),
        ], heute),
        isNull,
      );
    });
    test('mehrere offene Tage -> der juengste', () {
      final a = arbeitstagOffenAufgabe([
        (datum: DateTime(2026, 9, 22), beginn: '06:00', ende: null, km: null),
        (datum: DateTime(2026, 9, 24), beginn: '06:00', ende: null, km: null),
      ], heute)!;
      expect(a.key, 'arbeitstag_offen:2026-09-24');
    });
  });

  group('diktateWartenAufgabe', () {
    test('0 -> null, sonst Zahl und Diktat-Aktion', () {
      expect(diktateWartenAufgabe(0), isNull);
      expect(diktateWartenAufgabe(1)!.titel, '1 Diktat wartet auf Auswertung');
      final a = diktateWartenAufgabe(3)!;
      expect(a.titel, '3 Diktate warten auf Auswertung');
      expect(a.route, kDiktatAktion);
      expect(a.draussen, isTrue);
      expect(a.key, 'diktate');
    });
  });

  group('zaehleVersandvermerke (eine Abfrage statt N+1)', () {
    test('zaehlt Rechnungen mit Mail-Reinigung am created_at-Tag', () {
      final n = zaehleVersandvermerke(
        rechnungen: [
          {'betrieb_id': 'b1', 'created_at': '2026-09-20T15:02:11+00:00'},
          {'betrieb_id': 'b2', 'created_at': '2026-09-20T15:02:11+00:00'},
          {'betrieb_id': 'b1', 'created_at': '2026-09-21T08:00:00+00:00'},
          {'betrieb_id': null, 'created_at': '2026-09-20T15:02:11+00:00'},
        ],
        mailReinigungen: [
          {'betrieb_id': 'b1', 'datum': '2026-09-20'},
          {'betrieb_id': 'b2', 'datum': '2026-09-19'},
        ],
      );
      expect(n, 1);
    });
    test('zwei Rechnungen am selben Tag zaehlen beide', () {
      expect(
        zaehleVersandvermerke(
          rechnungen: [
            {'betrieb_id': 'b1', 'created_at': '2026-09-20T10:00:00'},
            {'betrieb_id': 'b1', 'created_at': '2026-09-20T11:00:00'},
          ],
          mailReinigungen: [
            {'betrieb_id': 'b1', 'datum': '2026-09-20'},
          ],
        ),
        2,
      );
    });
  });
}
