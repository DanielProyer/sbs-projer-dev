import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RasterBetrieb {
  final String? weNummer;
  final String? agNummer;
  final String name;
  final bool rotpunkt;
  final String? strasse;
  final String? plz;
  final String? ort;
  final int hahnen;
  final String? telefon;
  final String bemerkungen;
  final String zahlung; // 'BZ', 'RG', 'HS'
  final String regionName;
  final String status; // aktiv, inaktiv, geschlossen
  final List<FerienPeriode> ferien;
  final bool keineBetriebsferien;
  final Map<int, List<RasterReinigung>> reinigungenProMonat;

  RasterBetrieb({
    this.weNummer,
    this.agNummer,
    required this.name,
    required this.rotpunkt,
    this.strasse,
    this.plz,
    this.ort,
    required this.hahnen,
    this.telefon,
    required this.bemerkungen,
    required this.zahlung,
    required this.regionName,
    required this.status,
    required this.ferien,
    required this.keineBetriebsferien,
    required this.reinigungenProMonat,
  });
}

class FerienPeriode {
  final DateTime start;
  final DateTime ende;
  FerienPeriode(this.start, this.ende);
}

class RasterReinigung {
  final int tag;
  final String? serviceArt;
  RasterReinigung({required this.tag, this.serviceArt});
}

class RasterPdfService {
  static const _grau = PdfColor.fromInt(0xFFD9D9D9);
  static const _gelb = PdfColor.fromInt(0xFFFFFF00);
  static const _weiss = PdfColor.fromInt(0xFFFFFFFF);
  static const _schwarz = PdfColor.fromInt(0xFF000000);

  static const _monate = [
    'JAN', 'FEB', 'MRZ', 'APR', 'MAI', 'JUN',
    'JUL', 'AUG', 'SEP', 'OKT', 'NOV', 'DEZ',
  ];

  static Future<Uint8List> generate({
    required int jahr,
    required Map<String, List<RasterBetrieb>> betriebeProRegion,
  }) async {
    final pdf = pw.Document();

    final headerStyle = pw.TextStyle(
      fontSize: 6,
      fontWeight: pw.FontWeight.bold,
    );
    final dataStyle = const pw.TextStyle(fontSize: 6);
    final dataStyleBold = pw.TextStyle(
      fontSize: 6,
      fontWeight: pw.FontWeight.bold,
    );
    final regionStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );
    final jahrStyle = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );

    // Spaltenbreiten
    const colWe = 36.0;
    const colAg = 36.0;
    const colKunde = 85.0;
    const colRot = 16.0;
    const colStrasse = 68.0;
    const colPlz = 26.0;
    const colOrt = 48.0;
    const colHahnen = 16.0;
    const colTel = 52.0;
    const colBem = 58.0;
    const colBz = 12.0;
    const colRg = 12.0;
    const colHs = 12.0;
    const colMonat = 22.0;

    final allWidths = [
      colWe, colAg, colKunde, colRot, colStrasse, colPlz, colOrt,
      colHahnen, colTel, colBem, colBz, colRg, colHs,
      ...List.filled(12, colMonat),
    ];

    pw.Widget cell(String text, {
      pw.TextStyle? style,
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? bg,
      double? height,
    }) {
      return pw.Container(
        height: height,
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
        color: bg,
        child: pw.Text(text, style: style ?? dataStyle, maxLines: 3),
      );
    }

    pw.Widget headerCell(String text, {
      pw.Alignment align = pw.Alignment.center,
      PdfColor? bg,
    }) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        color: bg ?? _grau,
        child: pw.Text(text, style: headerStyle, textAlign: pw.TextAlign.center),
      );
    }

    bool monatInFerien(int jahr, int monat, FerienPeriode f) {
      final monatsStart = DateTime(jahr, monat, 1);
      final monatsEnde = DateTime(jahr, monat + 1, 0);
      return f.start.isBefore(monatsEnde.add(const Duration(days: 1))) &&
             f.ende.isAfter(monatsStart.subtract(const Duration(days: 1)));
    }

    String monatWert(RasterBetrieb b, int monat) {
      if (b.status == 'inaktiv') return 'A';
      if (b.status == 'geschlossen') return 'G';

      if (!b.keineBetriebsferien) {
        for (final f in b.ferien) {
          if (monatInFerien(jahr, monat, f)) return 'F';
        }
      }

      final reinigungen = b.reinigungenProMonat[monat] ?? [];
      if (reinigungen.isEmpty) return '';

      return reinigungen.map((r) {
        final tag = r.tag.toString();
        if (r.serviceArt == 'eroeffnungsservice' || r.serviceArt == 'endreinigung') {
          return '$tag(E)';
        }
        return tag;
      }).join(', ');
    }

    final sortedRegions = betriebeProRegion.keys.toList()..sort();

    final pageFormat = PdfPageFormat.a4.landscape.copyWith(
      marginLeft: 14,
      marginRight: 14,
      marginTop: 14,
      marginBottom: 14,
    );

    final columnWidthMap = {
      for (int i = 0; i < allWidths.length; i++)
        i: pw.FixedColumnWidth(allWidths[i]),
    };

    // Jede Region auf eigener Seite
    for (final region in sortedRegions) {
      final betriebe = betriebeProRegion[region]!;
      final regionRows = <pw.TableRow>[];

      // Jahr-Header-Zeile
      regionRows.add(pw.TableRow(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(2),
            color: _grau,
            child: pw.Text('$jahr', style: jahrStyle),
          ),
          ...List.generate(3, (_) => pw.Container(color: _grau)),
          ...List.generate(9, (_) => pw.Container(color: _grau)),
          ...List.generate(12, (i) => headerCell(_monate[i])),
        ],
      ));

      // Spalten-Header-Zeile
      regionRows.add(pw.TableRow(
        children: [
          headerCell('WE'),
          headerCell('AG'),
          headerCell('Kunde', align: pw.Alignment.centerLeft),
          headerCell('RP'),
          headerCell('Strasse', align: pw.Alignment.centerLeft),
          headerCell('PLZ'),
          headerCell('Ort', align: pw.Alignment.centerLeft),
          headerCell('H'),
          headerCell('Telefon', align: pw.Alignment.centerLeft),
          headerCell('Bemerkungen', align: pw.Alignment.centerLeft),
          headerCell('BZ'),
          headerCell('RG'),
          headerCell('HS'),
          ...List.generate(12, (i) => headerCell(_monate[i])),
        ],
      ));

      // Region-Header-Zeile (gelb)
      regionRows.add(pw.TableRow(
        children: [
          ...List.generate(4, (_) => pw.Container(color: _gelb)),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            color: _gelb,
            child: pw.Text(region, style: regionStyle),
          ),
          ...List.generate(allWidths.length - 5, (_) => pw.Container(color: _gelb)),
        ],
      ));

      // Daten-Zeilen
      for (final b in betriebe) {
        final zahlBz = b.zahlung == 'BZ' ? 'X' : '';
        final zahlRg = b.zahlung == 'RG' ? 'X' : '';
        final zahlHs = b.zahlung == 'HS' ? 'X' : '';

        regionRows.add(pw.TableRow(
          children: [
            cell(b.weNummer ?? '', align: pw.Alignment.center),
            cell(b.agNummer ?? '', align: pw.Alignment.center),
            cell(b.name, style: dataStyleBold),
            cell(b.rotpunkt ? 'Ja' : '', align: pw.Alignment.center,
                bg: b.rotpunkt ? const PdfColor.fromInt(0xFFFFCCCC) : null),
            cell(b.strasse ?? ''),
            cell(b.plz ?? '', align: pw.Alignment.center),
            cell(b.ort ?? ''),
            cell(b.hahnen > 0 ? '${b.hahnen}' : '', align: pw.Alignment.center),
            cell(b.telefon ?? ''),
            cell(b.bemerkungen),
            cell(zahlBz, align: pw.Alignment.center),
            cell(zahlRg, align: pw.Alignment.center),
            cell(zahlHs, align: pw.Alignment.center),
            ...List.generate(12, (i) {
              final wert = monatWert(b, i + 1);
              return cell(wert, align: pw.Alignment.center);
            }),
          ],
        ));
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          build: (context) => [
            pw.Table(
              border: pw.TableBorder.all(color: _schwarz, width: 0.3),
              columnWidths: columnWidthMap,
              children: regionRows,
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }
}
