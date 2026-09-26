import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// T6: Der häufigste Pfad der App (Reinigung abschliessen, 111× in 17 Tagen)
/// darf nicht an der CanvasKit-Falle hängen — alle Aktionsknöpfe sind
/// TapKnopf. Ballast weg: «Wasser gewechselt» (0 von 405), «Ende» beim Start.
void main() {
  final s = File('lib/presentation/screens/reinigungen/reinigung_form_screen.dart')
      .readAsStringSync();
  test('keine Material-Buttons fuer Aktionen', () {
    expect(s.contains('FilledButton'), isFalse);
    expect(s.contains('OutlinedButton'), isFalse);
  });
  test('Wasser-Checkbox entfernt', () {
    expect(s.contains("'Wasser im Kühler gewechselt'"), isFalse);
  });
  test('Ende-Feld nur beim Bearbeiten', () {
    final i = s.indexOf("labelText: 'Ende'");
    expect(i, greaterThan(-1));
    expect(s.substring(i - 400, i).contains('if (_isEdit)'), isTrue);
  });
}
