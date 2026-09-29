import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/pdf/jahresrechnung_pdf_service.dart';

const konten = [
  KontoInfo(kontonummer: 1000, bezeichnung: 'Kasse', kategorie: 'Umlaufvermögen'),
  KontoInfo(kontonummer: 1020, bezeichnung: 'Bank', kategorie: 'Umlaufvermögen'),
  KontoInfo(kontonummer: 1100, bezeichnung: 'Debitoren', kategorie: 'Umlaufvermögen'),
  KontoInfo(kontonummer: 1109, bezeichnung: 'Delkredere', kategorie: 'Umlaufvermögen'),
  KontoInfo(
    kontonummer: 2208,
    bezeichnung: 'Steuerrückstellung',
    kategorie: 'Kurzfristiges Fremdkapital',
  ),
  KontoInfo(
    kontonummer: 2260,
    bezeichnung: 'Privatkonto',
    kategorie: 'Kurzfristiges Fremdkapital',
  ),
  KontoInfo(kontonummer: 2500, bezeichnung: 'Coronakredit', kategorie: 'Langfristiges Fremdkapital'),
  KontoInfo(kontonummer: 2800, bezeichnung: 'Stammkapital', kategorie: 'Eigenkapital'),
];

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  final k = JahresrechnungKennzahlen(
    jahr: 2025,
    gewinn: 20890.22,
    gewinnvortrag: 35060.71,
    stammkapital: 20000,
    debitoren: 112587.66,
    delkredere: 5629.38,
    rueckstellung: 4000,
    bank: 12202.73,
    kasse: 6670.24,
    aufrechnungenAuto: 120,
    aufrechnungenManuell: 200,
    abschreibungen: const ["Jahrgang 2019: 29 Rechnungen, 2'235.90"],
    // Typografische Zeichen: seit pdfDokument() kein Kästchen mehr.
    ereignisse: 'Keine – ausser der Abschreibung (Entscheid 29.09.2026) …',
  );

  final bilanz = BilanzService.gruppiere(
    {1000: 6670.24, 1020: 12202.73, 1100: 112587.66, 1109: -5629.38, 2208: -4000, 2260: -45880.32, 2800: -20000},
    konten,
    gewinnvortrag: 35060.71,
    jahresergebnis: 20890.22,
  );
  // Vorjahr mit einem Posten, den es im Jahr nicht mehr gibt (2500), und
  // ohne Delkredere — beides muss zusammengeführt werden.
  final bilanzVj = BilanzService.gruppiere(
    {1000: 1122.69, 1020: 11829.71, 1100: 85871.15, 2260: -38762.84, 2500: -5000, 2800: -20000},
    konten,
    gewinnvortrag: 6783.20,
    jahresergebnis: 28277.51,
  );
  const er = ErfolgsrechnungDaten(
    nettoerloes: 197566.76,
    materialaufwand: 649.97,
    personalaufwand: 102494.22,
    uebrigerAufwand: 58935.41,
    abschreibungen: 0,
    finanzerfolg: 0,
    nebenerfolg: -10388.94,
    steuern: 4208,
  );
  const kontenJahr = ErKontenAufstellung([
    ErKlasse(3, [ErKonto(3000, 197566.76, bezeichnung: 'Ertrag Reinigung')]),
    ErKlasse(6, [
      ErKonto(6280, 120, bezeichnung: 'Verkehrsbussen'),
      ErKonto(6500, 58815.41, bezeichnung: 'Verwaltung'),
    ]),
  ]);
  const kontenVj = ErKontenAufstellung([
    ErKlasse(3, [ErKonto(3000, 180000, bezeichnung: 'Ertrag Reinigung')]),
  ]);

  Future<List<int>> bauen({bool mitVorjahr = true}) =>
      JahresrechnungPdfService.generate(
        k: k,
        bilanz: bilanz,
        bilanzVorjahr: mitVorjahr ? bilanzVj : null,
        er: er,
        konten: kontenJahr,
        kontenVorjahr: mitVorjahr ? kontenVj : null,
        geschaeftsfuehrer: 'Daniel Projer',
        erstelltAm: DateTime(2026, 9, 29),
      );

  /// Seitenzahl aus dem Seitenbaum (`/Type /Pages … /Count n`) — die
  /// Dictionaries schreibt das pdf-Paket unkomprimiert.
  int seiten(List<int> bytes) {
    final text = latin1.decode(bytes);
    final m = RegExp(r'/Type\s*/Pages[^>]*?/Count\s+(\d+)').firstMatch(text) ??
        RegExp(r'/Count\s+(\d+)[^>]*?/Type\s*/Pages').firstMatch(text);
    expect(m, isNotNull, reason: 'Seitenbaum nicht gefunden');
    return int.parse(m!.group(1)!);
  }

  test('vier Seiten: Bilanz, Erfolgsrechnung, Anhang, Steuerbeilage', () async {
    final bytes = await bauen();
    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(seiten(bytes), 4);
    // Für eine Sichtprüfung von Hand: JAHRESRECHNUNG_PDF=pfad setzen.
    final ziel = Platform.environment['JAHRESRECHNUNG_PDF'];
    if (ziel != null) File(ziel).writeAsBytesSync(bytes);
  });

  test('ohne Vorjahr entsteht dieselbe Struktur', () async {
    final bytes = await bauen(mitVorjahr: false);
    expect(seiten(bytes), 4);
  });
}
