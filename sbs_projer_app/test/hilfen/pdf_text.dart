import 'dart:convert';
import 'dart:io';

/// Text je Seite aus einem PDF des `pdf`-Pakets — für Tests.
///
/// WARUM selbst gebaut: Die App bettet Roboto ein (`pdfDokument()`); das
/// Paket schreibt Text dann als Glyph-Nummern (`[<0012003A>]TJ`) in
/// komprimierte Inhaltsströme. Ohne Auspacken und ToUnicode-Tabelle sieht
/// ein Test keinen einzigen Buchstaben. Deckt genau das ab, was das Paket
/// erzeugt (Type0-Schriften mit `bfchar`-Tabelle, Seiten über `/Kids`) —
/// kein allgemeiner PDF-Leser. Die Wörter einer Seite stehen mit einem
/// Leerzeichen getrennt in Zeichenreihenfolge.
List<String> pdfSeitenText(List<int> bytes) {
  final roh = latin1.decode(bytes);
  final objekte = <int, ({String dict, List<int>? strom})>{};
  final kopf = RegExp(r'(\d+)\s+0\s+obj');
  var pos = 0;
  while (true) {
    final m = kopf.allMatches(roh, pos).firstOrNull;
    if (m == null) break;
    final nr = int.parse(m.group(1)!);
    final ende = roh.indexOf('endobj', m.end);
    final s = roh.indexOf('stream', m.end);
    if (s < 0 || s > ende) {
      objekte[nr] = (dict: roh.substring(m.end, ende), strom: null);
      pos = ende + 6;
      continue;
    }
    // Strom: Länge aus dem Dictionary, nie nach «endobj» im Binärteil
    // suchen (die eingebettete Schrift kann jedes Bytemuster enthalten).
    final dict = roh.substring(m.end, s);
    var start = s + 'stream'.length;
    if (roh[start] == '\r') start++;
    if (roh[start] == '\n') start++;
    final laenge = int.parse(
      RegExp(r'/Length\s+(\d+)').firstMatch(dict)!.group(1)!,
    );
    var daten = bytes.sublist(start, start + laenge);
    if (dict.contains('/FlateDecode')) daten = zlib.decode(daten);
    objekte[nr] = (dict: dict, strom: daten);
    pos = roh.indexOf('endobj', start + laenge) + 6;
  }

  // Schrift-Objekt → Glyph-Index → Zeichen. Das Paket nennt jede Schrift
  // «/F<Objektnummer>».
  final tabellen = <int, Map<int, String>>{};
  Map<int, String> tabelle(int schrift) => tabellen.putIfAbsent(schrift, () {
    final ref = RegExp(
      r'/ToUnicode\s+(\d+)\s+0\s+R',
    ).firstMatch(objekte[schrift]?.dict ?? '');
    if (ref == null) return {};
    final cmap = latin1.decode(objekte[int.parse(ref.group(1)!)]!.strom!);
    return {
      for (final z in RegExp(
        r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]{4,8})>',
      ).allMatches(cmap))
        int.parse(z.group(1)!, radix: 16): String.fromCharCode(
          int.parse(z.group(2)!, radix: 16),
        ),
    };
  });

  final seitenbaum = objekte.values.firstWhere(
    (o) => RegExp(r'/Type\s*/Pages\b').hasMatch(o.dict),
  );
  final kids = RegExp(r'/Kids\s*\[([^\]]*)\]').firstMatch(seitenbaum.dict)!;
  final seiten = RegExp(
    r'(\d+)\s+0\s+R',
  ).allMatches(kids.group(1)!).map((m) => int.parse(m.group(1)!));

  String seitenText(int seite) {
    final dict = objekte[seite]!.dict;
    final contents = RegExp(
      r'/Contents\s*(\[[^\]]*\]|\d+\s+0\s+R)',
    ).firstMatch(dict)!.group(1)!;
    final woerter = <String>[];
    for (final c in RegExp(r'(\d+)\s+0\s+R').allMatches(contents)) {
      final text = latin1.decode(objekte[int.parse(c.group(1)!)]!.strom!);
      var schrift = 0;
      final befehle = RegExp(
        r'/F(\d+)\s+[\d.]+\s+Tf|\[<([0-9A-Fa-f]*)>\]\s*TJ',
      );
      for (final t in befehle.allMatches(text)) {
        if (t.group(1) != null) {
          schrift = int.parse(t.group(1)!);
          continue;
        }
        final hex = t.group(2)!;
        final zeichen = tabelle(schrift);
        final b = StringBuffer();
        for (var i = 0; i + 4 <= hex.length; i += 4) {
          b.write(zeichen[int.parse(hex.substring(i, i + 4), radix: 16)] ?? '?');
        }
        woerter.add(b.toString());
      }
    }
    return woerter.join(' ');
  }

  return [for (final s in seiten) seitenText(s)];
}
