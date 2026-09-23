/// Telefonnummern: eine Schreibweise für die ganze App (23.09.2026).
///
/// Regel Daniel 22.07.2026: Schweizer Nummern als «+41 79 123 45 67». Bis
/// 23.09.2026 gab es dafür eine Funktion für den Handy-Kontakt-Import und
/// drei Kopien eines Eingabe-Formatierers, der den Cursor bei jeder Taste ans
/// Ende setzte und «079 …» als «07 91 …» gruppierte.
library;

import 'package:flutter/services.dart';

/// Kanonische Form: Schweizer Nummern als «+41 79 123 45 67», gleich wie
/// eingegeben (079…, 0041…, +41…, 41…). Unbekannte Formate bleiben wie sie
/// sind — lieber unverändert als verschlimmbessert. Leer → `null`.
String? formatiereTelefon(String? roh) {
  final t = (roh ?? '').trim();
  if (t.isEmpty) return null;
  var nummer = t.replaceAll(RegExp(r'[^\d+]'), '');
  if (nummer.startsWith('00')) nummer = '+${nummer.substring(2)}';
  if (!nummer.startsWith('+')) {
    if (nummer.startsWith('0') && nummer.length > 1) {
      nummer = '+41${nummer.substring(1)}';
    } else if (nummer.startsWith('41') && nummer.length >= 11) {
      nummer = '+$nummer';
    } else {
      return t;
    }
  }
  final ziffern = nummer.substring(1).replaceAll('+', '');
  if (!ziffern.startsWith('41') || ziffern.length != 11) return '+$ziffern';
  return '+41 ${_gruppiere(ziffern.substring(2), const [2, 3, 2, 2])}';
}

/// Teilt [ziffern] in Gruppen der Längen [laengen]; was übrig bleibt, kommt
/// als letzte Gruppe dazu (eine zu lange Nummer bleibt sichtbar statt
/// abgeschnitten).
String _gruppiere(String ziffern, List<int> laengen) {
  final teile = <String>[];
  var i = 0;
  for (final l in laengen) {
    if (i >= ziffern.length) break;
    final ende = (i + l).clamp(0, ziffern.length);
    teile.add(ziffern.substring(i, ende));
    i = ende;
  }
  if (i < ziffern.length) teile.add(ziffern.substring(i));
  return teile.join(' ');
}

/// Anzeige während der Eingabe — nur Leerzeichen, keine Umwandlung.
String _rasterBeimTippen(String zeichen) {
  if (zeichen.startsWith('+41')) {
    final rest = zeichen.substring(3);
    return rest.isEmpty ? '+41' : '+41 ${_gruppiere(rest, const [2, 3, 2, 2])}';
  }
  if (zeichen.startsWith('0') && !zeichen.startsWith('00')) {
    return _gruppiere(zeichen, const [3, 3, 2, 2]);
  }
  return zeichen;
}

/// Ziffern und ein führendes «+» — das, was eine Nummer ausmacht.
String _bedeutsam(String text) {
  final b = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (RegExp(r'\d').hasMatch(c) || (c == '+' && b.isEmpty)) b.write(c);
  }
  return b.toString();
}

int _ziffernAnzahl(String text) => RegExp(r'\d').allMatches(text).length;

/// Eingabe-Formatierer für Telefonfelder.
///
/// WARUM so: Der frühere Formatierer setzte den Cursor nach jeder Taste ans
/// Ende — wer eine Ziffer in der Mitte korrigierte, schrieb danach am Ende
/// weiter (Befund Daniel 23.09.2026). Hier bleibt der Cursor hinter
/// derselben Anzahl Ziffern stehen, egal wie sich die Leerzeichen
/// verschieben. Kommt eine ganze Nummer auf einmal (Einfügen, Übernahme),
/// steht sie sofort in der kanonischen Form «+41 79 123 45 67».
class TelefonEingabeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final zeichen = _bedeutsam(newValue.text);
    if (zeichen.isEmpty) return TextEditingValue.empty;

    // Ganze Nummer auf einmal eingefügt → gleich kanonisch.
    if (_ziffernAnzahl(newValue.text) - _ziffernAnzahl(oldValue.text) >= 9) {
      final fertig = formatiereTelefon(newValue.text) ?? '';
      return TextEditingValue(
        text: fertig,
        selection: TextSelection.collapsed(offset: fertig.length),
      );
    }

    final text = _rasterBeimTippen(zeichen);
    // Wie viele bedeutsame Zeichen standen vor dem Cursor?
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final davor = _bedeutsam(newValue.text.substring(0, cursor)).length;
    var pos = 0;
    var gezaehlt = 0;
    while (pos < text.length && gezaehlt < davor) {
      if (text[pos] != ' ') gezaehlt++;
      pos++;
    }
    // Steht der Cursor vor einem Leerzeichen, springt er dahinter — dort
    // beginnt die nächste Gruppe.
    if (davor > 0 && pos < text.length && text[pos] == ' ') pos++;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}
