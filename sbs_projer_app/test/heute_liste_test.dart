import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/heute_liste.dart';

TourEintrag stopp(String name, {String? ort, List<String> anlagen = const ['a1']}) =>
    TourEintrag(
      typ: TourEintragTyp.reinigung,
      id: 'r_$name',
      betriebId: 'b_$name',
      anlageId: anlagen.first,
      anlageIds: anlagen,
      betriebName: name,
      betriebOrt: ort,
      beschreibung: '',
    );

Widget rahmen(Widget kind) => MaterialApp(home: Scaffold(body: kind));

void main() {
  testWidgets('zeigt Betrieb und Ort je Stopp', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda', ort: 'Chur')],
      erledigt: 0,
      gesamt: 1,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Calanda'), findsOneWidget);
    expect(find.textContaining('Chur'), findsOneWidget);
  });

  testWidgets('zeigt alle 13 Stopps — keine Kuerzung', (tester) async {
    final viele = [for (var i = 1; i <= 13; i++) stopp('Betrieb $i')];

    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: viele,
      erledigt: 0,
      gesamt: 13,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Betrieb 1'), findsOneWidget);
    expect(find.text('Betrieb 13'), findsOneWidget);
  });

  testWidgets('Kopfzeile zeigt den Fortschritt', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 3,
      gesamt: 4,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.textContaining('3 von 4'), findsOneWidget);
  });

  testWidgets('ohne Plan erscheint der Leerzustand', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: const [],
      erledigt: 0,
      gesamt: 0,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Kein Tagesplan für heute'), findsOneWidget);
    expect(find.text('Plan erstellen'), findsOneWidget);
  });

  testWidgets('alles erledigt ist nicht derselbe Zustand wie kein Plan', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: const [],
      erledigt: 9,
      gesamt: 9,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.text('Kein Tagesplan für heute'), findsNothing);
    expect(find.textContaining('Alles erledigt'), findsOneWidget);
  });

  testWidgets('Start-Pfeil meldet den Stopp', (tester) async {
    TourEintrag? gestartet;

    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      onStart: (e) => gestartet = e,
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    await tester.tap(find.byKey(const Key('heute_start_r_Calanda')));
    await tester.pump();

    expect(gestartet?.betriebName, 'Calanda');
  });

  testWidgets('kein ListTile und kein FilledButton', (tester) async {
    await tester.pumpWidget(rahmen(HeuteListeInhalt(
      stopps: [stopp('Calanda')],
      erledigt: 0,
      gesamt: 1,
      onStart: (_) {},
      onOeffnen: (_) {},
      onTourenplan: () {},
    )));

    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
