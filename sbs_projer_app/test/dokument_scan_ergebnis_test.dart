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
  });

  group('dokumentDateiname', () {
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
