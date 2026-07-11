import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_active_filters.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('AppFilterBar rendert Dropdown + Toggle; Callbacks feuern', (t) async {
    String? gewaehlt = 'x';
    bool toggle = false;
    await t.pumpWidget(_wrap(StatefulBuilder(
      builder: (c, setState) => AppFilterBar(items: [
        AppFilterDropdown<String>(
          hint: 'Alle Status',
          value: null,
          options: const [('offen', 'Offen'), ('zu', 'Geschlossen')],
          onChanged: (v) => setState(() => gewaehlt = v),
        ),
        AppFilterToggle(
          label: 'Nur fällige',
          value: toggle,
          onChanged: (v) => setState(() => toggle = v),
        ),
      ]),
    )));
    expect(find.text('Alle Status'), findsWidgets);
    expect(find.text('Nur fällige'), findsOneWidget);
    // Toggle antippen
    await t.tap(find.text('Nur fällige'));
    await t.pumpAndSettle();
    expect(toggle, isTrue);
    // Dropdown öffnen + Option wählen
    await t.tap(find.text('Alle Status').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Geschlossen').last);
    await t.pumpAndSettle();
    expect(gewaehlt, 'zu');
  });

  testWidgets('AppMultiToggleChips: mehrere gleichzeitig wählbar', (t) async {
    Set<String> sel = {'a'};
    await t.pumpWidget(_wrap(StatefulBuilder(
      builder: (c, setState) => AppMultiToggleChips<String>(
        options: const [
          AppMultiOption('a', 'Alpha'),
          AppMultiOption('b', 'Beta'),
        ],
        selected: sel,
        onChanged: (s) => setState(() => sel = s),
      ),
    )));
    expect(find.text('Alpha'), findsOneWidget);
    await t.tap(find.text('Beta'));
    await t.pumpAndSettle();
    expect(sel, {'a', 'b'});
    await t.tap(find.text('Alpha'));
    await t.pumpAndSettle();
    expect(sel, {'b'});
  });

  testWidgets('AppActiveFilters: leer -> shrink, sonst löschbar', (t) async {
    await t.pumpWidget(_wrap(const AppActiveFilters(chips: [])));
    expect(find.byType(Chip), findsNothing);

    var entfernt = false;
    await t.pumpWidget(_wrap(AppActiveFilters(chips: [
      ('Region: Chur', () => entfernt = true),
    ])));
    expect(find.text('Region: Chur'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(entfernt, isTrue);
  });
}
