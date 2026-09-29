import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/audit_screen.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

/// Abschlussprüfung: Knöpfe der Abschlussschritte D (Rückstellung) und E
/// (Delkredere) — Entscheid Daniel 29.09.2026 «die Schritte in die App».
/// Abschlussjahr (Vorjahr): beide per 31.12.; laufendes Jahr: Delkredere wie
/// bisher heute, keine Rückstellung (der Gewinn steht noch nicht fest);
/// ältere, eingereichte Jahre: keine Knöpfe (Review W1).

Pruefbefund _befund(String id, PruefStatus s) => Pruefbefund(
  regelId: id,
  gruppe: id == 'delkredere' ? 'Debitoren' : 'Abschluss',
  status: s,
  titel: id,
  ist: '0.00',
  hinweis: 'Hinweis $id',
);

Future<void> _pumpe(
  WidgetTester tester, {
  required int jahr,
  required List<Pruefbefund> befunde,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        abschlussPruefungProvider.overrideWith((ref, j) async => befunde),
      ],
      child: MaterialApp(home: AuditScreen(jahr: jahr)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final daten = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(daten))).load();
  });

  final vorjahr = DateTime.now().year - 1;

  testWidgets(
    'W1: Abschlussjahr (Vorjahr) → Delkredere per 31.12. und Rückstellung '
    'buchen',
    (tester) async {
      await _pumpe(
        tester,
        jahr: vorjahr,
        befunde: [
          _befund('delkredere', PruefStatus.gelb),
          _befund('rueckstellung', PruefStatus.rot),
        ],
      );
      expect(find.text('Delkredere per 31.12.$vorjahr buchen'), findsOneWidget);
      expect(find.text('Rückstellung buchen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Rückstellung auch bei grüner Zeile (Nachführen), sobald '
      'grüne gezeigt werden', (tester) async {
    await _pumpe(
      tester,
      jahr: vorjahr,
      befunde: [_befund('rueckstellung', PruefStatus.gruen)],
    );
    expect(find.text('Rückstellung buchen'), findsNothing);
    await tester.tap(find.text('grüne zeigen'));
    await tester.pumpAndSettle();
    expect(find.text('Rückstellung buchen'), findsOneWidget);
    // Delkredere im Lot → kein Knopf.
    expect(find.textContaining('Delkredere'), findsNothing);
  });

  testWidgets('W1: eingereichtes Jahr 2023 → keine Knöpfe, auch bei roten '
      'Zeilen', (tester) async {
    // Nur das Abschlussjahr (Vorjahr) bekommt die Buchungsschritte — ein
    // Jahr, dessen Steuererklärung längst eingereicht ist, nicht.
    await _pumpe(
      tester,
      jahr: 2023,
      befunde: [
        _befund('delkredere', PruefStatus.rot),
        _befund('rueckstellung', PruefStatus.rot),
      ],
    );
    // Die Zeilen stehen da (rot) …
    expect(find.text('Hinweis delkredere'), findsOneWidget);
    expect(find.text('Hinweis rueckstellung'), findsOneWidget);
    // … aber ohne Buchungsknopf.
    expect(find.textContaining('buchen'), findsNothing);
  });

  testWidgets('laufendes Jahr: Delkredere wie bisher, keine Rückstellung', (
    tester,
  ) async {
    await _pumpe(
      tester,
      jahr: DateTime.now().year,
      befunde: [
        _befund('delkredere', PruefStatus.rot),
        _befund('rueckstellung', PruefStatus.gelb),
      ],
    );
    expect(find.text('Delkredere auf 5 % buchen'), findsOneWidget);
    expect(find.text('Rückstellung buchen'), findsNothing);
  });
}
