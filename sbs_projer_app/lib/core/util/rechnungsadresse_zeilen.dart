import 'package:sbs_projer_app/data/models/betrieb_rechnungsadresse.dart';

/// Empfängeradresse für Rechnung, Mahnung und Kontoauszug — eine Wahrheit für
/// alle PDF-Services. Reine Funktionen, ohne IO.
///
/// Der Briefkopf darf beliebig viele Zeilen tragen (Objekt, Kostenstelle,
/// Zusatz, Postfach); der QR-Zahlteil nicht: die Swiss-QR-Bill-Norm kennt für
/// «Zahlbar durch» nur Name, eine Adresszeile und PLZ/Ort. Darum die zwei
/// getrennten Funktionen [adressZeilen] und [qrEmpfaenger].

/// Zeilen des Adressblocks im Brief, von oben nach unten.
/// Leere Felder erzeugen keine Leerzeilen.
List<String> adressZeilen({
  required String betriebName,
  String? betriebStrasse,
  String? betriebNr,
  String? betriebPlz,
  String? betriebOrt,
  required BetriebRechnungsadresse? ra,
}) {
  final zeilen = <String>[];

  if (ra == null) {
    _add(zeilen, betriebName);
    _add(zeilen, _join([betriebStrasse, betriebNr]));
    _add(zeilen, _join([betriebPlz, betriebOrt]));
    return zeilen;
  }

  _add(zeilen, ra.firma);
  _add(zeilen, ra.objekt);
  _add(zeilen, ra.kostenstelle);
  _add(zeilen, ra.zusatz);
  // Postfach ersetzt die Strasse — nie beides.
  final postfach = ra.postfach?.trim() ?? '';
  _add(zeilen, postfach.isNotEmpty ? postfach : _join([ra.strasse, ra.nr]));
  _add(zeilen, _join([ra.plz, ra.ort]));
  return zeilen;
}

/// Empfängerdaten für den QR-Zahlteil («Zahlbar durch»).
QrEmpfaenger qrEmpfaenger({
  required String betriebName,
  String? betriebStrasse,
  String? betriebNr,
  String? betriebPlz,
  String? betriebOrt,
  required BetriebRechnungsadresse? ra,
}) {
  if (ra == null) {
    return QrEmpfaenger(
      name: _kuerze(betriebName),
      strasse: betriebStrasse ?? '',
      nr: betriebNr ?? '',
      plz: betriebPlz ?? '',
      ort: betriebOrt ?? '',
    );
  }

  // Kostenstelle und Zusatz gehören NICHT in den QR-Namen: sie sind
  // Zustellhinweise des Empfängers, keine Angaben zum Zahlungspflichtigen.
  final name = _join([ra.firma, ra.objekt]);
  final postfach = ra.postfach?.trim() ?? '';
  return QrEmpfaenger(
    name: _kuerze(name.isNotEmpty ? name : ra.objekt),
    strasse: postfach.isNotEmpty ? postfach : ra.strasse,
    nr: postfach.isNotEmpty ? '' : (ra.nr ?? ''),
    plz: ra.plz,
    ort: ra.ort,
  );
}

class QrEmpfaenger {
  final String name;
  final String strasse;
  final String nr;
  final String plz;
  final String ort;

  const QrEmpfaenger({
    required this.name,
    required this.strasse,
    required this.nr,
    required this.plz,
    required this.ort,
  });

  /// Strassenzeile inkl. Hausnummer für die Anzeige im Zahlteil.
  String get strasseZeile => _join([strasse, nr]);

  /// «PLZ Ort» für die Anzeige im Zahlteil.
  String get plzOrt => _join([plz, ort]);
}

/// QR-Bill: Name des Zahlungspflichtigen max. 70 Zeichen.
String _kuerze(String s) => s.length <= 70 ? s : s.substring(0, 70);

String _join(List<String?> teile) =>
    teile.map((t) => t?.trim() ?? '').where((t) => t.isNotEmpty).join(' ');

void _add(List<String> zeilen, String? wert) {
  final t = wert?.trim() ?? '';
  if (t.isNotEmpty) zeilen.add(t);
}
