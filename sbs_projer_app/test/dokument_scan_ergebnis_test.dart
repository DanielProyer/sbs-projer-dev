import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/dokument_scan_ergebnis.dart';
import 'package:sbs_projer_app/services/dokumente/dokument_scan_service.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

/// Dokument-Erkennung (Edge Function `parse-dokument`, 29.09.2026):
/// Antwort-Modell, Katalog für die Function, Dateiname beim Upload.
void main() {
  group('DokumentScanErgebnis.fromJson', () {
    test('vollständige Antwort (Zins- und Kapitalausweis)', () {
      final e = DokumentScanErgebnis.fromJson({
        'bereich': 'steuern',
        'typ': 'zinsausweis',
        'kategorie': null,
        'jahr': 2025,
        'dokument_datum': '2025-12-31',
        'betrag': null,
        'referenz': null,
        'titel': 'Zins- und Kapitalausweis GKB per 31.12.2025',
        'dateiname': '2025_GKB_Zins-Kapitalausweis.pdf',
        'zuversicht': 0.92,
        'felder': {
          'saldo_31_12': 10869.26,
          'zins_brutto': 0,
          'verrechnungssteuer': 0,
          'zins_netto': 0,
          'konto': '…0601',
        },
        'hinweis': null,
      });
      expect(e.bereich, 'steuern');
      expect(e.typ, 'zinsausweis');
      expect(e.kategorie, isNull);
      expect(e.jahr, 2025);
      expect(e.dokumentDatum, DateTime(2025, 12, 31));
      expect(e.betrag, isNull);
      expect(e.titel, 'Zins- und Kapitalausweis GKB per 31.12.2025');
      expect(e.dateiname, '2025_GKB_Zins-Kapitalausweis.pdf');
      expect(e.zuversicht, 0.92);
      expect(e.feldZahl('saldo_31_12'), 10869.26);
      expect(
        e.zinsausweisNotiz(),
        "Saldo 31.12.: 10'869.26 · Zins brutto 0.00 · VSt 0.00 · "
        'netto 0.00 · Konto …0601',
      );
    });

    test('leere Antwort → alles null, Zuversicht 0', () {
      final e = DokumentScanErgebnis.fromJson({});
      expect(e.bereich, isNull);
      expect(e.typ, isNull);
      expect(e.jahr, isNull);
      expect(e.dokumentDatum, isNull);
      expect(e.betrag, isNull);
      expect(e.titel, isNull);
      expect(e.dateiname, isNull);
      expect(e.zuversicht, 0);
      expect(e.felder, isEmpty);
      expect(e.zinsausweisNotiz(), isNull);
    });

    test('unbekannte JSON-Typen werden null statt einer Exception', () {
      final e = DokumentScanErgebnis.fromJson({
        'bereich': 42,
        'typ': ['brief'],
        'jahr': 'zwanzig',
        'dokument_datum': '2025-02-30', // rollte in Dart in den März
        'betrag': {'chf': 1},
        'titel': '   ',
        'zuversicht': 'hoch',
        'felder': [1, 2],
      });
      expect(e.bereich, isNull);
      expect(e.typ, isNull);
      expect(e.jahr, isNull);
      expect(e.dokumentDatum, isNull);
      expect(e.betrag, isNull);
      expect(e.titel, isNull);
      expect(e.zuversicht, 0);
      expect(e.felder, isEmpty);
    });

    test('Zahlen als Text, Jahr als Text, Zuversicht gedeckelt', () {
      final e = DokumentScanErgebnis.fromJson({
        'jahr': '2024',
        'betrag': "1'234.50",
        'zuversicht': 7,
      });
      expect(e.jahr, 2024);
      expect(e.betrag, 1234.5);
      expect(e.zuversicht, 1);
      expect(DokumentScanErgebnis.fromJson({'jahr': 1850}).jahr, isNull);
      expect(DokumentScanErgebnis.fromJson({'jahr': 2025.5}).jahr, isNull);
    });

    // K7: double.tryParse('NaN') ist NaN, jsonDecode('1e400') ist Infinity —
    // und Infinity.toInt() wirft. Nichts davon darf durchkommen.
    test('NaN, Infinity und 1e400 werden null statt einer Exception', () {
      final e = DokumentScanErgebnis.fromJson(
        jsonDecode('{"jahr": 1e400, "betrag": 1e400, "zuversicht": "NaN"}')
            as Map<String, dynamic>,
      );
      expect(e.jahr, isNull);
      expect(e.betrag, isNull);
      expect(e.zuversicht, 0);

      final s = DokumentScanErgebnis.fromJson({
        'typ': 'zinsausweis',
        'betrag': 'NaN',
        'jahr': 'Infinity',
        'felder': {'saldo_31_12': 'Infinity', 'zins_brutto': '-Infinity'},
      });
      expect(s.betrag, isNull);
      expect(s.jahr, isNull);
      expect(s.feldZahl('saldo_31_12'), isNull);
      expect(s.zinsausweisNotiz(), isNull);
      expect(DokumentScanErgebnis.fromJson({'jahr': double.nan}).jahr, isNull);
      expect(
        DokumentScanErgebnis.fromJson({'zuversicht': 'Infinity'}).zuversicht,
        0,
      );
    });

    test('unbekannter Dokumenttyp bleibt erhalten — der Dialog prüft', () {
      // Das Modell gibt weiter, was kam; ob der Typ in den Bereich passt,
      // entscheidet der Dialog anhand von dokumentTypen().
      final e = DokumentScanErgebnis.fromJson({
        'bereich': 'steuern',
        'typ': 'fantasie',
      });
      expect(e.typ, 'fantasie');
      expect(dokumentTypen('steuern').contains(e.typ), isFalse);
    });

    test('Zinsausweis-Notiz nur beim Typ zinsausweis und nur mit Zahlen', () {
      expect(
        const DokumentScanErgebnis(
          typ: 'kontoauszug',
          felder: {'saldo_31_12': 5},
        ).zinsausweisNotiz(),
        isNull,
      );
      expect(
        const DokumentScanErgebnis(
          typ: 'zinsausweis',
          felder: {'konto': '…0601'},
        ).zinsausweisNotiz(),
        isNull,
      );
      expect(
        const DokumentScanErgebnis(
          typ: 'zinsausweis',
          felder: {'saldo_31_12': "12'000.5", 'zins_brutto': 1.25},
        ).zinsausweisNotiz(),
        "Saldo 31.12.: 12'000.50 · Zins brutto 1.25",
      );
    });
  });

  group('DokumentScanService.katalog', () {
    test('schickt alle Bereiche mit ihren Typen und festen Kategorien', () {
      final k = DokumentScanService.katalog();
      expect(k['bereiche'], dokumentBereiche.keys.toList());
      final typen = k['typen'] as Map<String, List<String>>;
      for (final b in dokumentBereiche.keys) {
        expect(typen[b], dokumentTypen(b), reason: b);
      }
      final kategorien = k['kategorien'] as Map<String, List<String>>;
      expect(kategorien.keys.toSet(), {'steuern', 'vertraege'});
      expect(kategorien['steuern'], ['bund', 'kanton', 'mwst', 'busse']);
      final labels = k['labels'] as Map<String, String>;
      expect(labels['zinsausweis'], 'Zins-/Kapitalausweis');
      expect(labels['ahv'], 'AHV/SVA');
      expect(labels['kanton'], 'Kanton/Gemeinde');
    });

    test('Schlüssel passen zum Muster, das die Function verlangt', () {
      // parse-dokument/antwort.ts weist sonst den ganzen Katalog ab (400).
      final muster = RegExp(r'^[a-z0-9_]{1,40}$');
      final k = DokumentScanService.katalog();
      final alle = <String>[
        ...k['bereiche'] as List<String>,
        for (final l in (k['typen'] as Map<String, List<String>>).values) ...l,
        for (final l in (k['kategorien'] as Map<String, List<String>>).values)
          ...l,
      ];
      expect(alle.where((s) => !muster.hasMatch(s)), isEmpty);
    });

    test('erkennbar: nur PDF/JPG/PNG bis 15 MB', () {
      expect(DokumentScanService.erkennbar('application/pdf', 1000), isTrue);
      expect(DokumentScanService.erkennbar('image/png', 1000), isTrue);
      expect(DokumentScanService.erkennbar('image/heic', 1000), isFalse);
      expect(DokumentScanService.erkennbar('image/jpeg', 0), isFalse);
      expect(
        DokumentScanService.erkennbar(
          'application/pdf',
          DokumentScanService.maxBytes + 1,
        ),
        isFalse,
      );
    });

    // K2: Die Messages API nimmt ein Bild nur bis 5 MB base64 an — das sind
    // rund 3.7 MB Rohdaten. PDFs dürfen weiterhin bis 15 MB.
    test('Bilder nur bis ~3.7 MB, PDFs bis 15 MB', () {
      const bild = DokumentScanService.maxBildBytes;
      expect(DokumentScanService.erkennbar('image/jpeg', bild), isTrue);
      expect(DokumentScanService.erkennbar('image/jpeg', bild + 1), isFalse);
      expect(DokumentScanService.erkennbar('image/png', bild + 1), isFalse);
      expect(
        DokumentScanService.erkennbar('application/pdf', bild + 1),
        isTrue,
      );
      // base64 der grössten erlaubten Bilddatei bleibt unter 5 MB
      expect((bild + 2) ~/ 3 * 4, lessThanOrEqualTo(5 * 1024 * 1024));
    });

    test('hinderungsgrund nennt, warum nicht erkannt wird', () {
      expect(
        DokumentScanService.hinderungsgrund('application/pdf', 10),
        isNull,
      );
      expect(
        DokumentScanService.hinderungsgrund(
          'image/png',
          DokumentScanService.maxBildBytes + 1,
        ),
        'Bild zu gross für die Erkennung (max. 3.7 MB) — Felder von Hand',
      );
      expect(
        DokumentScanService.hinderungsgrund(
          'application/pdf',
          DokumentScanService.maxBytes + 1,
        ),
        'PDF zu gross für die Erkennung (max. 15 MB) — Felder von Hand',
      );
      expect(
        DokumentScanService.hinderungsgrund('image/heic', 10),
        'Keine Erkennung für diesen Dateityp — Felder von Hand',
      );
    });
  });

  group('dokumentDateiname', () {
    // K6: Der Name landet im Storage-Pfad und im Download — Pfadteile und
    // unter Windows verbotene Zeichen haben dort nichts zu suchen.
    test('Pfad- und Windows-Sonderzeichen werden ersetzt, «..» entfernt', () {
      expect(
        dokumentDateiname(
          '../../x',
          original: 'a.pdf',
          mime: 'application/pdf',
        ),
        '__x.pdf',
      );
      expect(
        dokumentDateiname(
          'Rechnung: 2025/Q1 "neu"?*<>|',
          original: 'a.pdf',
          mime: 'application/pdf',
        ),
        'Rechnung_ 2025_Q1 _neu______.pdf',
      );
      expect(
        dokumentDateiname(
          r'C:\temp\x.pdf',
          original: 'a.pdf',
          mime: 'application/pdf',
        ),
        'C__temp_x.pdf',
      );
      expect(
        dokumentDateiname(
          'a\u0000b\u001fc',
          original: 'a.pdf',
          mime: 'application/pdf',
        ),
        'a_b_c.pdf',
      );
      expect(
        dokumentDateiname('..\\..', original: 'a.pdf', mime: 'application/pdf'),
        '_.pdf',
      );
    });

    test('höchstens 150 Zeichen inklusive Endung', () {
      final lang = dokumentDateiname(
        'a' * 200,
        original: 'a.pdf',
        mime: 'application/pdf',
      );
      expect(lang.length, 150);
      expect(lang, endsWith('aaa.pdf'));
      final passend = dokumentDateiname(
        '${'b' * 200}.jpeg',
        original: 'b.jpg',
        mime: 'image/jpeg',
      );
      expect(passend.length, 150);
      expect(passend, endsWith('b.jpeg'));
    });

    test('passende Endung bleibt, fehlende wird ergänzt', () {
      expect(
        dokumentDateiname(
          '2025_GKB_Zins-Kapitalausweis.pdf',
          original: 'scan.pdf',
          mime: 'application/pdf',
        ),
        '2025_GKB_Zins-Kapitalausweis.pdf',
      );
      expect(
        dokumentDateiname(
          '2025_GKB_Zins-Kapitalausweis',
          original: 'scan.pdf',
          mime: 'application/pdf',
        ),
        '2025_GKB_Zins-Kapitalausweis.pdf',
      );
      expect(
        dokumentDateiname('Foto.JPEG', original: 'x.jpg', mime: 'image/jpeg'),
        'Foto.JPEG',
      );
    });

    test('falsche Endung wird ersetzt, leeres Feld nimmt das Original', () {
      expect(
        dokumentDateiname('Beleg.pdf', original: 'x.png', mime: 'image/png'),
        'Beleg.png',
      );
      expect(
        dokumentDateiname('  ', original: 'IMG_0042.jpg', mime: 'image/jpeg'),
        'IMG_0042.jpg',
      );
      expect(
        dokumentDateiname('.pdf', original: 'a.pdf', mime: 'application/pdf'),
        'dokument.pdf',
      );
      expect(
        dokumentDateiname('.png', original: 'a.pdf', mime: 'application/pdf'),
        'dokument.pdf',
      );
    });
  });
}
