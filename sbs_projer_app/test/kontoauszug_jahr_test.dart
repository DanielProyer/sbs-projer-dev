import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/services/pdf/kontoauszug_pdf_service.dart';

/// Kontoauszug mit Jahres-Eingrenzung (Wunsch Daniel 21.09.2026).
///
/// WARUM getestet: Der Auszug geht an KUNDEN. Nennt er einen Saldo, der nur
/// ein Jahr umfasst, ohne das zu sagen, liest ihn der Kunde als seinen
/// gesamten Ausstand — und eine Zahlung nach diesem Betrag liesse ältere
/// Rechnungen stillschweigend liegen. Deshalb filtert der Service selbst und
/// schreibt den Vorbehalt ins Papier.
void main() {
  // Die Schrift kommt aus dem rootBundle (services/pdf/pdf_schrift.dart).
  TestWidgetsFlutterBinding.ensureInitialized();

  BetriebLocal betrieb() => BetriebLocal()
    ..serverId = 'b1'
    ..userId = 'u1'
    ..name = 'Testbetrieb'
    ..strasse = 'Hauptstrasse'
    ..nr = '1'
    ..plz = '7000'
    ..ort = 'Chur';

  Rechnung rg(
    String id,
    DateTime datum,
    double brutto, {
    String status = 'offen',
  }) => Rechnung(
    id: id,
    userId: 'u1',
    rechnungsnummer: id,
    rechnungstyp: 'kundenrechnung',
    betriebId: 'b1',
    rechnungsdatum: datum,
    faelligkeitsdatum: datum.add(const Duration(days: 30)),
    betragBrutto: brutto,
    zahlungsstatus: status,
  );

  final gemischt = [
    rg('2025-a', DateTime(2025, 5, 4), 200),
    rg('2026-a', DateTime(2026, 3, 1), 100),
    rg('2026-b', DateTime(2026, 9, 2), 150, status: 'bezahlt'),
  ];

  bool istPdf(List<int> b) =>
      b.length > 4 &&
      b[0] == 0x25 &&
      b[1] == 0x50 &&
      b[2] == 0x44 &&
      b[3] == 0x46;

  test('ohne Jahr entsteht wie bisher ein PDF über alles', () async {
    final bytes = await KontoauszugPdfService.generate(
      betrieb: betrieb(),
      rechnungen: gemischt,
    );
    expect(istPdf(bytes), isTrue, reason: 'muss mit %PDF beginnen');
    expect(bytes.length, greaterThan(1000));
  });

  group('Jahres-Auswahl', () {
    test('nimmt nur den gewählten Jahrgang', () {
      final r = KontoauszugPdfService.fuerJahr(gemischt, 2026);
      expect(r.map((e) => e.id).toList(), ['2026-a', '2026-b']);
    });

    test(
      'bezahlte Rechnungen bleiben drin — der Auszug zeigt beide Seiten',
      () {
        // Ein Kontoauszug ohne die Zahlungen wäre kein Auszug, sondern eine
        // Mahnliste. Die Zahlung bekommt im PDF eine eigene Haben-Zeile.
        final r = KontoauszugPdfService.fuerJahr(gemischt, 2026);
        expect(r.where((e) => e.zahlungsstatus == 'bezahlt'), hasLength(1));
      },
    );

    test('null nimmt alles', () {
      expect(KontoauszugPdfService.fuerJahr(gemischt, null), hasLength(3));
    });

    test('Jahr ohne Rechnungen ergibt eine leere Auswahl', () {
      expect(KontoauszugPdfService.fuerJahr(gemischt, 2019), isEmpty);
    });
  });

  group('Zustellweg in der Belegspalte', () {
    // WARUM (Wunsch Daniel 21.09.2026): «Am Tresen übergeben» und «per Mail
    // versendet» sind zwei verschiedene Gespräche mit dem Wirt. Stand das
    // nicht im PDF, musste man für jede Zeile zurück in die App.
    final df = DateFormat('dd.MM.yyyy');

    Rechnung mitWeg(String? art, {DateTime? uebergeben, DateTime? versendet}) =>
        Rechnung(
          id: 'x',
          userId: 'u1',
          rechnungstyp: 'kundenrechnung',
          rechnungsdatum: DateTime(2026, 9, 17),
          faelligkeitsdatum: DateTime(2026, 10, 17),
          versandart: art,
          uebergebenAm: uebergeben,
          versendetAm: versendet,
        );

    test('Tresen nennt den Einzahlungsschein und das Übergabedatum', () {
      expect(
        KontoauszugPdfService.zustellungKurz(
          mitWeg('rechnung_tresen', uebergeben: DateTime(2026, 9, 17)),
          df,
        ),
        'EZS am Tresen · 17.09.2026',
      );
    });

    test('Mail nennt das Versanddatum', () {
      expect(
        KontoauszugPdfService.zustellungKurz(
          mitWeg('rechnung_mail', versendet: DateTime(2026, 9, 14)),
          df,
        ),
        'Per E-Mail · 14.09.2026',
      );
    });

    test('Tresen nimmt das Übergabe-, nicht das Versanddatum', () {
      // Eine Tresen-Rechnung kann später zusätzlich gemailt worden sein.
      // Für den Weg «Tresen» zählt die Übergabe.
      expect(
        KontoauszugPdfService.zustellungKurz(
          mitWeg(
            'rechnung_tresen',
            uebergeben: DateTime(2026, 9, 17),
            versendet: DateTime(2026, 9, 20),
          ),
          df,
        ),
        'EZS am Tresen · 17.09.2026',
      );
    });

    test('ohne Datum steht nur der Weg, keine Behauptung über den Kunden', () {
      expect(
        KontoauszugPdfService.zustellungKurz(mitWeg('rechnung_tresen'), df),
        'EZS am Tresen',
      );
    });

    test('ohne Versandart bleibt die Zeile weg', () {
      expect(KontoauszugPdfService.zustellungKurz(mitWeg(null), df), isNull);
      expect(KontoauszugPdfService.zustellungKurz(mitWeg(''), df), isNull);
    });

    test('unbekannter Weg wird durchgereicht statt verschluckt', () {
      expect(
        KontoauszugPdfService.zustellungKurz(mitWeg('neuer_weg'), df),
        'neuer_weg',
      );
    });
  });

  group('Referenz auf dem Einzahlungsschein', () {
    // Entscheid Daniel 21.09.2026: Nur bei GENAU EINER offenen Rechnung trägt
    // der Schein deren Referenz. Bei mehreren würde die Zahlung sonst
    // vollständig auf eine davon gebucht, die übrigen blieben offen, und der
    // Fehler fiele erst bei der nächsten Mahnung auf.
    Rechnung mitRef(String id, String status, String? ref) => Rechnung(
      id: id,
      userId: 'u1',
      rechnungsnummer: id,
      rechnungstyp: 'kundenrechnung',
      rechnungsdatum: DateTime(2026, 5, 1),
      faelligkeitsdatum: DateTime(2026, 6, 1),
      betragBrutto: 100,
      zahlungsstatus: status,
      qrReferenz: ref,
    );

    test('genau eine offene Rechnung: deren Referenz', () {
      expect(
        KontoauszugPdfService.einzelReferenz([
          mitRef('a', 'bezahlt', 'RF11'),
          mitRef('b', 'offen', 'RF22'),
        ]),
        'RF22',
      );
    });

    test('mehrere offene: keine Referenz', () {
      expect(
        KontoauszugPdfService.einzelReferenz([
          mitRef('a', 'offen', 'RF11'),
          mitRef('b', 'mahnung_1', 'RF22'),
        ]),
        isNull,
      );
    });

    test('keine offene: keine Referenz', () {
      expect(
        KontoauszugPdfService.einzelReferenz([
          mitRef('a', 'bezahlt', 'RF11'),
          mitRef('b', 'abgeschrieben', 'RF22'),
        ]),
        isNull,
      );
    });

    test('einzige offene ohne hinterlegte Referenz: keine Referenz', () {
      expect(
        KontoauszugPdfService.einzelReferenz([mitRef('a', 'offen', null)]),
        isNull,
      );
      expect(
        KontoauszugPdfService.einzelReferenz([mitRef('a', 'offen', '')]),
        isNull,
      );
    });

    test('Zwischenstatus zählen als offen', () {
      expect(
        KontoauszugPdfService.einzelReferenz([
          mitRef('a', 'bezahlt', 'RF11'),
          mitRef('b', 'erinnert', 'RF22'),
        ]),
        'RF22',
      );
    });
  });
  test('mit Jahr entsteht ebenfalls ein gültiges PDF', () async {
    // Bewusst KEIN Grössenvergleich: Das Jahres-PDF ist grösser als das
    // vollständige, weil der Vorbehalt-Satz fett gesetzt ist und dafür ein
    // zusätzlicher Schriftschnitt eingebettet wird. Die Auswahl selbst prüft
    // die Gruppe oben.
    final bytes = await KontoauszugPdfService.generate(
      betrieb: betrieb(),
      rechnungen: gemischt,
      jahr: 2026,
    );
    expect(istPdf(bytes), isTrue);
  });

  test('ein Jahr ohne Bewegungen stürzt nicht ab', () async {
    // Der eigentliche Absturzkandidat: leere Bewegungsliste. `von` greift dann
    // auf die erste Bewegung zu, die es nicht gibt.
    final bytes = await KontoauszugPdfService.generate(
      betrieb: betrieb(),
      rechnungen: gemischt,
      jahr: 2019,
    );
    expect(istPdf(bytes), isTrue);
  });

  test('leere Rechnungsliste stürzt nicht ab', () async {
    final bytes = await KontoauszugPdfService.generate(
      betrieb: betrieb(),
      rechnungen: const [],
    );
    expect(istPdf(bytes), isTrue);
  });
}
