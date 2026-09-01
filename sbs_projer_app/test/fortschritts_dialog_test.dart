import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/fortschritts_dialog.dart';

void main() {
  testWidgets('zeigt Titel, Spinner und den aktuellen Stand', (tester) async {
    final stand = ValueNotifier<int>(0);
    await tester.pumpWidget(MaterialApp(
      home: FortschrittsDialog(
        titel: 'Zahlungen verbuchen',
        stand: stand,
        total: 32,
      ),
    ));

    expect(find.text('Zahlungen verbuchen'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0 von 32 …'), findsOneWidget);

    stand.value = 12;
    await tester.pump();
    expect(find.text('12 von 32 …'), findsOneWidget);
  });

  testWidgets('ohne total zeigt er nur den Titel', (tester) async {
    final stand = ValueNotifier<int>(0);
    await tester.pumpWidget(MaterialApp(
      home: FortschrittsDialog(titel: 'Bitte warten', stand: stand),
    ));
    expect(find.text('Bitte warten'), findsOneWidget);
    expect(find.textContaining('von'), findsNothing);
  });
}
