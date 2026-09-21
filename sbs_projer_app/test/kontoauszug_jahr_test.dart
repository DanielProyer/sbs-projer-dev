import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
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
