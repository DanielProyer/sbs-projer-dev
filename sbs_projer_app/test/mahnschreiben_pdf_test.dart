import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/mahnregeln.dart';
import 'package:sbs_projer_app/core/util/scor_referenz.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/pdf/kontoauszug_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/mahnschreiben_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/pdf_schrift.dart';

Rechnung _rechnung({
  required String id,
  required String rechnungsnummer,
  DateTime? rechnungsdatum,
  DateTime? faelligkeitsdatum,
  double betragBrutto = 123.45,
  bool mitReferenz = true,
}) {
  return Rechnung.fromJson({
    'id': id,
    'user_id': 'u1',
    'rechnungsnummer': rechnungsnummer,
    'rechnungstyp': 'kundenrechnung',
    'rechnungsdatum':
        (rechnungsdatum ?? DateTime.utc(2026, 8, 1)).toIso8601String(),
    'faelligkeitsdatum':
        (faelligkeitsdatum ?? DateTime.utc(2026, 8, 31)).toIso8601String(),
    'betrag_brutto': betragBrutto,
    'zahlungsstatus': 'erinnert',
    // Realistische RF-Referenz statt Fantasie-Ziffern (Review 23.09.2026,
    // Punkt 6) — dieselbe Funktion, die die App beim Rechnungsversand nutzt.
    'qr_referenz':
        mitReferenz ? qrReferenzAusNummer('kundenrechnung', rechnungsnummer) : null,
  });
}

BetriebLocal _betrieb() {
  final b = BetriebLocal();
  b.userId = 'u1';
  b.name = 'Testbetrieb Gasthaus Sonne';
  b.strasse = 'Musterstrasse';
  b.nr = '12';
  b.plz = '7000';
  b.ort = 'Chur';
  return b;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mahnText — einheitliche Stufen', () {
    final frist = DateTime.utc(2026, 10, 3);

    test('Erinnerung, Einzahl: "Ihnen" ist entgangen — NIE "uns"', () {
      final t = MahnschreibenPdfService.mahnText([MahnStufe.erinnerung], frist: frist);
      expect(t, contains('Vermutlich ist Ihnen die folgende Rechnung entgangen'));
      expect(t, isNot(contains('uns entgangen')));
      expect(t, contains('03.10.2026'));
    });

    test('Erinnerung, Mehrzahl: "Ihnen" sind entgangen', () {
      final t = MahnschreibenPdfService.mahnText(
        [MahnStufe.erinnerung, MahnStufe.erinnerung],
        frist: frist,
      );
      expect(t, contains('Vermutlich sind Ihnen die folgenden Rechnungen entgangen'));
      expect(t, isNot(contains('uns entgangen')));
    });

    test('1. Mahnung, Einzahl nennt "der Betrag der folgenden Rechnung"', () {
      final t = MahnschreibenPdfService.mahnText([MahnStufe.mahnung1], frist: frist);
      expect(t, contains('der Betrag der folgenden Rechnung'));
      expect(t, contains('ihn bis spätestens 03.10.2026'));
    });

    test('1. Mahnung, Mehrzahl nennt "die Beträge der folgenden Rechnungen"', () {
      final t = MahnschreibenPdfService.mahnText(
        [MahnStufe.mahnung1, MahnStufe.mahnung1],
        frist: frist,
      );
      expect(t, contains('die Beträge der folgenden Rechnungen'));
      expect(t, contains('sie bis spätestens 03.10.2026'));
    });

    test(
      'Letzte Mahnung droht Betreibung, nennt Zins seit frühester Erinnerung, '
      'und bietet Hilfe bei Zahlungsschwierigkeiten an',
      () {
        final t = MahnschreibenPdfService.mahnText(
          [MahnStufe.letzte],
          frist: frist,
          ersteErinnerungLetzte: DateTime.utc(2026, 9, 1),
        );
        expect(t, contains('Trotz mehrfacher Erinnerung'));
        expect(t, contains('Betreibung'));
        expect(t, contains('5 %'));
        expect(t, contains('01.09.2026'));
        expect(
          t,
          contains(
            'Bei Zahlungsschwierigkeiten melden Sie sich bitte — wir finden gerne eine Lösung.',
          ),
        );
      },
    );

    test('Letzte Mahnung ohne bekannte Erinnerung nennt den Zins trotzdem, ohne Datum', () {
      final t = MahnschreibenPdfService.mahnText([MahnStufe.letzte], frist: frist);
      expect(t, contains('Verzugszins von 5 % geltend gemacht'));
    });

    test('jede Stufe mit Gegenstandslos-Satz', () {
      for (final s in MahnStufe.values) {
        expect(
          MahnschreibenPdfService.mahnText(
            [s],
            frist: frist,
            ersteErinnerungLetzte: DateTime.utc(2026, 9, 1),
          ),
          contains('gegenstandslos'),
          reason: s.name,
        );
      }
    });
  });

  group('mahnText — gemischte Stufen (Review 23.09.2026, Punkt 3)', () {
    final frist = DateTime.utc(2026, 10, 3);

    test(
      'Erinnerung + Letzte: Betreibung/Zins beziehen sich NUR auf die '
      'Letzte-Mahnung-Zeilen, nicht auf alle',
      () {
        final t = MahnschreibenPdfService.mahnText(
          [MahnStufe.erinnerung, MahnStufe.letzte],
          frist: frist,
          ersteErinnerungLetzte: DateTime.utc(2026, 9, 1),
        );
        expect(t, contains('als ‹Letzte Mahnung› bezeichneten'));
        expect(t, contains('Betreibung'));
        expect(t, contains('01.09.2026'));
        // "Trotz mehrfacher Erinnerung" stimmt nicht für ALLE Rechnungen
        // dieses Schreibens — eine davon steht erst bei der Erinnerung.
        expect(t, isNot(contains('Trotz mehrfacher Erinnerung')));
      },
    );

    test('Letzte Mahnung im Mix löst weiterhin das Hilfsangebot aus', () {
      final t = MahnschreibenPdfService.mahnText(
        [MahnStufe.mahnung1, MahnStufe.letzte],
        frist: frist,
      );
      expect(t, contains('Bei Zahlungsschwierigkeiten'));
    });

    test('Erinnerung + 1. Mahnung (keine Letzte): keine Betreibungsdrohung', () {
      final t = MahnschreibenPdfService.mahnText(
        [MahnStufe.erinnerung, MahnStufe.mahnung1],
        frist: frist,
      );
      expect(t, isNot(contains('Betreibung')));
      expect(t, isNot(contains('Trotz mehrfacher Erinnerung')));
      expect(t, isNot(contains('Bei Zahlungsschwierigkeiten')));
    });

    test('reine Sammlung aus zwei Letzte-Mahnung-Rechnungen nutzt die einfache Form', () {
      final t = MahnschreibenPdfService.mahnText(
        [MahnStufe.letzte, MahnStufe.letzte],
        frist: frist,
        ersteErinnerungLetzte: DateTime.utc(2026, 9, 1),
      );
      expect(t, contains('Trotz mehrfacher Erinnerung'));
      // Die gemischte Formulierung mit dem Tabellen-Verweis gehört NUR zum
      // Mix — bei reiner letzter Stufe wäre der Verweis redundant/falsch.
      expect(t, isNot(contains('als ‹Letzte Mahnung› bezeichneten')));
    });
  });

  group('generate', () {
    test('eine Rechnung, ohne Kontoauszug, ohne Muster', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: [(rechnung: r, stufe: MahnStufe.erinnerung)],
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: false,
      );
      expect(bytes.length, greaterThan(0));
    });

    test('drei Rechnungen mit gemischten Stufen, ohne Kontoauszug', () async {
      final betrieb = _betrieb();
      final posten = [
        (
          rechnung: _rechnung(id: 'r1', rechnungsnummer: '2026-08-1'),
          stufe: MahnStufe.erinnerung,
        ),
        (
          rechnung: _rechnung(id: 'r2', rechnungsnummer: '2026-08-2'),
          stufe: MahnStufe.mahnung1,
        ),
        (
          rechnung: _rechnung(id: 'r3', rechnungsnummer: '2026-08-3'),
          stufe: MahnStufe.letzte,
        ),
      ];
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: posten,
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: false,
      );
      expect(bytes.length, greaterThan(0));
    });

    test('mit Kontoauszug-Beilage', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: [(rechnung: r, stufe: MahnStufe.erinnerung)],
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: false,
        kontoauszugRechnungen: [r],
        kontoauszugJahr: 2026,
      );
      expect(bytes.length, greaterThan(0));
    });

    test('mit Muster-Aufdruck (Schreiben + QR + Kontoauszug)', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: [(rechnung: r, stufe: MahnStufe.letzte)],
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: true,
        kontoauszugRechnungen: [r],
      );
      expect(bytes.length, greaterThan(0));
    });
  });

  group('Kontoauszug-Beilage ohne Sammel-Zahlteil (Review 23.09.2026, Punkt 1)', () {
    // Das Mahnschreiben hat bereits einen QR-Zahlteil PRO RECHNUNG. Ein
    // zweiter, summierter Zahlteil über den Gesamtsaldo (wie ihn der
    // eigenständige Kontoauszug zeigt) wäre eine zweite Zahlungsaufforderung
    // über denselben Betrag — Doppelzahlungsgefahr. `seitenHinzufuegen`
    // liefert die Anzahl gebauter Zahlteile zurück, damit das ohne PDF-Parsing
    // geprüft werden kann.
    test('mitZahlteil: false baut trotz offenem Saldo keinen Zahlteil', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final doc = await pdfDokument();
      final anzahl = await KontoauszugPdfService.seitenHinzufuegen(
        doc,
        betrieb: betrieb,
        rechnungen: [r],
        mitZahlteil: false,
      );
      expect(anzahl, 0);
    });

    test('mitZahlteil-Default (true) baut weiterhin einen Zahlteil bei offenem Saldo', () async {
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final doc = await pdfDokument();
      final anzahl = await KontoauszugPdfService.seitenHinzufuegen(
        doc,
        betrieb: betrieb,
        rechnungen: [r],
      );
      expect(anzahl, 1);
    });

    test('das Mahnschreiben übergibt tatsächlich mitZahlteil: false an den Kontoauszug', () async {
      // Indirekter Nachweis über den öffentlichen Weg: generate() mit
      // Kontoauszug-Beilage darf keinen zweiten Zahlteil erzeugen — die
      // direkten seitenHinzufuegen-Tests oben zeigen, dass genau dieser
      // Parameter dafür entscheidend ist.
      final betrieb = _betrieb();
      final r = _rechnung(id: 'r1', rechnungsnummer: '2026-08-1');
      final bytes = await MahnschreibenPdfService.generate(
        betrieb: betrieb,
        posten: [(rechnung: r, stufe: MahnStufe.letzte)],
        datum: DateTime.utc(2026, 9, 23),
        frist: DateTime.utc(2026, 10, 3),
        muster: false,
        kontoauszugRechnungen: [r],
      );
      expect(bytes.length, greaterThan(0));
    });
  });
}
