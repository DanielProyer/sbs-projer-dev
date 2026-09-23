import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/telefon.dart';

/// Tippt [zeichen] an der Cursorposition von [alt] ein, wie die Tastatur es
/// tut, und lässt den Formatierer darüberlaufen.
TextEditingValue _tippe(TextEditingValue alt, String zeichen) {
  final pos = alt.selection.baseOffset;
  final text = alt.text.substring(0, pos) + zeichen + alt.text.substring(pos);
  return TelefonEingabeFormatter().formatEditUpdate(
    alt,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: pos + zeichen.length),
    ),
  );
}

TextEditingValue _loesche(TextEditingValue alt) {
  final pos = alt.selection.baseOffset;
  final text = alt.text.substring(0, pos - 1) + alt.text.substring(pos);
  return TelefonEingabeFormatter().formatEditUpdate(
    alt,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: pos - 1),
    ),
  );
}

TextEditingValue _bei(String text, int cursor) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor));

void main() {
  group('formatiereTelefon (Regel Daniel 22.07.2026: +41 79 123 45 67)', () {
    test('Schweizer Nummern in jeder Schreibweise', () {
      expect(formatiereTelefon('079 123 45 67'), '+41 79 123 45 67');
      expect(formatiereTelefon('0791234567'), '+41 79 123 45 67');
      expect(formatiereTelefon('0041 79 123 45 67'), '+41 79 123 45 67');
      expect(formatiereTelefon('+41791234567'), '+41 79 123 45 67');
      expect(formatiereTelefon('081 378 40 20'), '+41 81 378 40 20');
    });

    test('leer bleibt null, Unbekanntes wird nicht verschlimmbessert', () {
      expect(formatiereTelefon(''), isNull);
      expect(formatiereTelefon('   '), isNull);
      expect(formatiereTelefon('1234'), '1234');
    });
  });

  group('TelefonEingabeFormatter', () {
    test('tippen: Schweizer Raster schon waehrend der Eingabe', () {
      var v = _bei("", 0);
      for (final z in '0791234567'.split('')) {
        v = _tippe(v, z);
      }
      expect(v.text, '079 123 45 67');
      expect(v.selection.baseOffset, v.text.length);

      v = _bei("", 0);
      for (final z in '+41791234567'.split('')) {
        v = _tippe(v, z);
      }
      expect(v.text, '+41 79 123 45 67');
    });

    test('Cursor bleibt beim Korrigieren in der Mitte stehen (Befund 23.09.)', () {
      // «+41 79 123 45 67», Cursor hinter «123» → eine 9 einfügen
      final v = _tippe(_bei('+41 79 123 45 67', 10), '9');
      expect(v.text, '+41 79 123 94 56 7');
      // Der Cursor steht direkt hinter der eingefügten 9, nicht am Ende.
      expect(v.text.substring(0, v.selection.baseOffset), '+41 79 123 9');
    });

    test('Loeschen in der Mitte: Cursor bleibt an der Stelle', () {
      // Cursor hinter «+41 79 1», Rückschritt löscht die 1
      final v = _loesche(_bei('+41 79 123 45 67', 8));
      expect(v.text, '+41 79 234 56 7');
      expect(v.text.substring(0, v.selection.baseOffset), '+41 79 ');
    });

    test('ganze Nummer eingefuegt: gleich im richtigen Format', () {
      final v = TelefonEingabeFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '079 123 45 67',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );
      expect(v.text, '+41 79 123 45 67');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('alles geloescht: leer', () {
      final v = _loesche(_bei('0', 1));
      expect(v.text, '');
    });
  });
}
