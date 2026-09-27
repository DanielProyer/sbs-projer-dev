import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/planung_aufgeklappt.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerung_form_screen.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/arbeitszeit_block.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/planung_klappe.dart';

void main() {
  group('planungAufgeklappt', () {
    bool offen({
      bool erstGeplant = false,
      String? von,
      String? bis,
      bool manuell = false,
    }) => planungAufgeklappt(
      erstGeplant: erstGeplant,
      arbeitVon: von,
      arbeitBis: bis,
      manuellOffen: manuell,
    );

    test('sofort erledigt, keine Zeiten, nicht angetippt → zu', () {
      expect(offen(), isFalse);
      expect(offen(von: '', bis: '  '), isFalse); // Leerzeichen zählen nicht
    });

    test('«Erst geplant» an → offen', () {
      expect(offen(erstGeplant: true), isTrue);
    });

    test('eine erfasste Zeit genügt → offen', () {
      expect(offen(von: '08:00'), isTrue);
      expect(offen(bis: '09:30'), isTrue);
    });

    test('von Hand aufgeklappt → offen', () {
      expect(offen(manuell: true), isTrue);
    });
  });

  group('Störungsformular, 360 px breit', () {
    Future<void> pumpeFormular(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [betriebeProvider.overrideWithValue(const [])],
          child: const MaterialApp(home: StoerungFormScreen()),
        ),
      );
      // Lager/Preise laden ohne Supabase ins Leere (try/catch im Formular).
      await tester.pumpAndSettle();
    }

    testWidgets('neue Störung: Klappe zu, Datum und Eingang sichtbar', (
      tester,
    ) async {
      await pumpeFormular(tester);

      expect(find.text('Planung & Arbeitszeit'), findsOneWidget);
      expect(
        find.text('Sofort erledigt — zum Planen antippen'),
        findsOneWidget,
      );
      expect(find.text('Erst geplant'), findsNothing);
      expect(find.byType(ArbeitszeitBlock), findsNothing);
      expect(find.text('Arbeit von'), findsNothing);
      // Datum und Störungseingang gehören nicht in die Klappe.
      expect(find.text('Datum'), findsOneWidget);
      expect(find.text('Störungseingang (Uhrzeit)'), findsOneWidget);
      expect(tester.takeException(), isNull); // kein Overflow
    });

    testWidgets('antippen klappt auf und wieder zu', (tester) async {
      await pumpeFormular(tester);

      await tester.tap(find.byKey(const Key('planung_klappe_kopf')));
      await tester.pumpAndSettle();
      expect(find.text('Erst geplant'), findsOneWidget);
      expect(find.byType(ArbeitszeitBlock), findsOneWidget);
      expect(find.text('Arbeit von'), findsOneWidget);
      expect(find.text('Arbeit bis'), findsOneWidget);
      expect(find.text('Sofort erledigt — zum Planen antippen'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('planung_klappe_kopf')));
      await tester.pumpAndSettle();
      expect(find.text('Erst geplant'), findsNothing);
    });

    testWidgets('«Erst geplant» an → bleibt offen, Kopf nicht zuklappbar', (
      tester,
    ) async {
      await pumpeFormular(tester);

      await tester.tap(find.byKey(const Key('planung_klappe_kopf')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erst geplant'));
      await tester.pumpAndSettle();
      expect(
        find.text('Erscheint im Tourenplan; Rapport folgt beim Erledigen'),
        findsOneWidget,
      );

      // Zuklappen geht nicht, solange der Schalter an ist.
      await tester.tap(find.byKey(const Key('planung_klappe_kopf')));
      await tester.pumpAndSettle();
      expect(find.text('Erst geplant'), findsOneWidget);
      final klappe = tester.widget<PlanungKlappe>(find.byType(PlanungKlappe));
      expect(klappe.offen, isTrue);
      expect(klappe.zuklappbar, isFalse);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // Schalter wieder aus: Die Klappe bleibt offen (kein Zuklappen unter
      // dem Finger).
      await tester.tap(find.text('Erst geplant'));
      await tester.pumpAndSettle();
      expect(
        find.text('Erledigt — Rapport wird jetzt erfasst'),
        findsOneWidget,
      );
    });
  });
}
