import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_regeln.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

/// Q5 (App-Analyse 25.09.2026): «Debitoren stimmen» und «2030 stimmt».
/// Am 25.09. stand 1100 bei 117'416.58, die offenen Rechnungen bei
/// 131'193.44 — und keine Regel meldete die −13'776.86.

BuchungSaldo bs(int soll, int haben, double betrag, {DateTime? datum}) =>
    BuchungSaldo(
      sollKonto: soll,
      habenKonto: haben,
      betrag: betrag,
      datum: datum ?? DateTime(2026, 3, 1),
      storniert: false,
    );

Rechnung rg(
  String id,
  double brutto, {
  String status = 'offen',
  String typ = 'kundenrechnung',
  double guthaben = 0,
  String? betrieb,
}) => Rechnung(
  id: id,
  userId: 'u',
  rechnungstyp: typ,
  betriebId: betrieb,
  rechnungsdatum: DateTime(2026, 3, 1),
  faelligkeitsdatum: DateTime(2026, 3, 31),
  betragBrutto: brutto,
  zahlungsstatus: status,
  guthabenVerrechnet: guthaben,
);

Buchung bu(
  int soll,
  int haben,
  double brutto, {
  String? beleg,
  bool storniert = false,
}) => Buchung(
  id: 'b$soll-$haben-$brutto-$beleg',
  userId: 'u',
  datum: DateTime(2026, 3, 5),
  sollKonto: soll,
  habenKonto: haben,
  betragNetto: brutto,
  betragBrutto: brutto,
  beschreibung: 'x',
  belegId: beleg,
  geschaeftsjahr: 2026,
  istStorniert: storniert,
);

AbschlussKontext kx({
  List<BuchungSaldo> buchungen = const [],
  double? offeneForderungen,
  int offeneForderungenAnzahl = 0,
  Map<String, double>? kundenguthaben,
  int jahr = 2026,
}) => AbschlussKontext(
  jahr: jahr,
  heute: DateTime(2026, 9, 25),
  buchungen: buchungen,
  konten: const [],
  camtDateien: const [],
  offeneRechnungen: const [],
  steuerbuchungenOhneJahr: 0,
  dokumentTypen: const {},
  offeneRechnungenMitZahlung: const {},
  offeneForderungen: offeneForderungen,
  offeneForderungenAnzahl: offeneForderungenAnzahl,
  kundenguthabenJeBetrieb: kundenguthaben,
);

Pruefbefund lauf(String id, AbschlussKontext k) =>
    alleAbschlussRegeln().firstWhere((r) => r.id == id).pruefe(k);

void main() {
  group('zaehltAlsForderung', () {
    test('Kunden- und Jahresrechnungen zählen, solange nicht erledigt', () {
      for (final s in ['offen', 'gesendet', 'erinnert', 'mahnung_1',
          'mahnung_2']) {
        expect(zaehltAlsForderung(rg('a', 10, status: s)), isTrue, reason: s);
      }
      expect(
        zaehltAlsForderung(rg('a', 10, typ: 'jahresrechnung')),
        isTrue,
      );
      expect(zaehltAlsForderung(rg('a', 10, status: 'bezahlt')), isFalse);
      expect(
        zaehltAlsForderung(rg('a', 10, status: 'abgeschrieben')),
        isFalse,
      );
    });

    test('Heineken erst ab freigegeben (vorher kein Debitor gebucht)', () {
      for (final s in ['offen', 'gesendet', 'bezahlt']) {
        expect(
          zaehltAlsForderung(rg('h', 10, typ: 'heineken_monat', status: s)),
          isFalse,
          reason: s,
        );
      }
      expect(
        zaehltAlsForderung(
          rg('h', 10, typ: 'heineken_monat', status: 'freigegeben'),
        ),
        isTrue,
      );
    });
  });

  group('offeneForderungenSumme', () {
    test('Brutto der offenen Rechnungen, erledigte und Heineken-gesendet '
        'nicht', () {
      final s = offeneForderungenSumme([
        rg('a', 100),
        rg('b', 50, typ: 'jahresrechnung', status: 'mahnung_1'),
        rg('c', 70, status: 'bezahlt'),
        rg('h1', 1000, typ: 'heineken_monat', status: 'gesendet'),
        rg('h2', 2000, typ: 'heineken_monat', status: 'freigegeben'),
      ], const []);
      expect(s, closeTo(2150, 0.001));
    });

    test('schon gebuchte Eingänge (Haben 1100) mindern den offenen Rest', () {
      // Teilzahlung 40 und Guthaben-Verrechnung 2030/1100 über 10.
      final s = offeneForderungenSumme(
        [rg('a', 100, guthaben: 10)],
        [
          bu(1020, 1100, 40, beleg: 'a'),
          bu(2030, 1100, 10, beleg: 'a'),
          bu(1020, 1100, 99, beleg: 'a', storniert: true),
          bu(1020, 1100, 5, beleg: 'fremd'),
        ],
      );
      expect(s, closeTo(50, 0.001));
    });

    test('reserviertes, noch nicht verrechnetes Guthaben mindert NICHT — '
        '1100 trägt bis zur Verrechnungsbuchung das volle Brutto', () {
      final s = offeneForderungenSumme([rg('a', 100, guthaben: 30)], const []);
      expect(s, closeTo(100, 0.001));
    });
  });

  group('debitoren_offene_rechnungen', () {
    test('1100 = offene Rechnungen → grün', () {
      final b = lauf(
        'debitoren_offene_rechnungen',
        kx(
          buchungen: [bs(1100, 3400, 150)],
          offeneForderungen: 150.03,
          offeneForderungenAnzahl: 2,
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });

    test('Abweichung → rot mit beiden Beträgen, Differenz und Hinweis', () {
      final b = lauf(
        'debitoren_offene_rechnungen',
        kx(
          buchungen: [bs(1100, 3400, 117416.58)],
          offeneForderungen: 131193.44,
          offeneForderungenAnzahl: 1128,
        ),
      );
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('117'));
      expect(b.soll, contains('131'));
      expect(b.hinweis, contains('-13'));
      expect(b.hinweis, contains('776.86'));
      expect(
        b.hinweis,
        contains(
          'Differenz klären: Rechnungen ohne Buchung / Buchungen ohne Rechnung',
        ),
      );
    });

    test('Saldo per heute, auch im abgeschlossenen Jahr — die offenen '
        'Rechnungen sind ein heutiger Stand', () {
      final b = lauf(
        'debitoren_offene_rechnungen',
        kx(
          jahr: 2025,
          buchungen: [
            bs(1100, 3400, 100, datum: DateTime(2025, 12, 1)),
            bs(1020, 1100, 100, datum: DateTime(2026, 2, 1)),
          ],
          offeneForderungen: 0,
        ),
      );
      expect(b.status, PruefStatus.gruen);
    });

    test('Rechnungen nicht geladen → gelb statt Fehlalarm', () {
      final b = lauf('debitoren_offene_rechnungen', kx());
      expect(b.status, PruefStatus.gelb);
    });
  });

  group('kundenguthaben_2030', () {
    test('2030 = Summe Guthaben → grün', () {
      final b = lauf(
        'kundenguthaben_2030',
        kx(buchungen: [bs(1020, 2030, 30)], kundenguthaben: {'b1': 30}),
      );
      expect(b.status, PruefStatus.gruen);
    });

    test('Abweichung → rot mit beiden Beträgen und Differenz', () {
      final b = lauf(
        'kundenguthaben_2030',
        kx(
          buchungen: [bs(1020, 2030, 50)],
          kundenguthaben: {'b1': 30},
        ),
      );
      expect(b.status, PruefStatus.rot);
      expect(b.ist, contains('50.00'));
      expect(b.soll, contains('30.00'));
      expect(b.hinweis, contains('20.00'));
    });

    test('Guthaben ohne Betrieb (Schlüssel \'\') zählt mit, meldet aber gelb',
        () {
      final b = lauf(
        'kundenguthaben_2030',
        kx(
          buchungen: [bs(1020, 2030, 50)],
          kundenguthaben: {'b1': 30, '': 20},
        ),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('ohne Betrieb'));
    });

    test('negatives Guthaben eines Betriebs → gelb', () {
      final b = lauf(
        'kundenguthaben_2030',
        kx(
          buchungen: [bs(1020, 2030, 10)],
          kundenguthaben: {'b1': 30, 'b2': -20},
        ),
      );
      expect(b.status, PruefStatus.gelb);
      expect(b.hinweis, contains('negativ'));
    });

    test('Guthaben nicht geladen → gelb', () {
      expect(lauf('kundenguthaben_2030', kx()).status, PruefStatus.gelb);
    });
  });
}
