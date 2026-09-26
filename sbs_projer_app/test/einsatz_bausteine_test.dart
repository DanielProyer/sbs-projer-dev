import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeit_beenden_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/arbeitszeit_block.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/betrieb_feld.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz/material_slots.dart';

BetriebLocal _betrieb(
  String? id,
  String name, {
  String? ort,
  String? nr,
  bool berg = false,
}) {
  return BetriebLocal()
    ..serverId = id
    ..name = name
    ..ort = ort
    ..betriebNr = nr
    ..istBergkunde = berg;
}

Lager _lager(String id, String name, {String? dbo}) =>
    Lager(id: id, userId: 'u', name: name, dboNr: dbo);

Widget _huelle(Widget kind) => MaterialApp(
  home: Scaffold(
    body: Form(child: ListView(children: [kind])),
  ),
);

void main() {
  group('betriebVorschlaege', () {
    final betriebe = [
      _betrieb('1', 'Adler', ort: 'Chur', nr: '4711'),
      _betrieb(null, 'Ohne Server-ID', ort: 'Chur'),
      for (var i = 0; i < 30; i++) _betrieb('x$i', 'Betrieb $i'),
    ];

    test('blendet Betriebe ohne serverId aus', () {
      final namen = betriebVorschlaege(betriebe, 'chur').map((b) => b.name);
      expect(namen, ['Adler']);
    });

    test('sucht in Name, Ort und Betriebsnummer', () {
      expect(betriebVorschlaege(betriebe, 'adl').single.name, 'Adler');
      expect(betriebVorschlaege(betriebe, 'CHUR').single.name, 'Adler');
      expect(betriebVorschlaege(betriebe, '471').single.name, 'Adler');
    });

    test('leere Eingabe: erste 20 bzw. alle', () {
      expect(betriebVorschlaege(betriebe, '').length, 20);
      expect(betriebVorschlaege(betriebe, '', leerMax: null).length, 31);
    });
  });

  group('lagerVorschlaege', () {
    final lager = [
      for (var i = 0; i < 15; i++) _lager('l$i', 'Dichtung $i'),
      _lager('h', 'Hahn', dbo: 'DBO-99'),
    ];

    test('voll: leer → 10, sonst nur Name', () {
      expect(lagerVorschlaege(lager, '').length, 10);
      expect(lagerVorschlaege(lager, 'hahn').single.id, 'h');
      expect(lagerVorschlaege(lager, 'dbo-99'), isEmpty);
      expect(lagerVorschlaege(lager, 'dichtung').length, 15);
    });

    test('einfach: leer → nichts, Name oder DBO, höchstens 10', () {
      expect(lagerVorschlaege(lager, '', einfach: true), isEmpty);
      expect(lagerVorschlaege(lager, 'dbo-99', einfach: true).single.id, 'h');
      expect(lagerVorschlaege(lager, 'dichtung', einfach: true).length, 10);
    });
  });

  group('Arbeitszeit-Helfer', () {
    test('parsen und formatieren', () {
      expect(arbeitszeitParsen('07:05'), const TimeOfDay(hour: 7, minute: 5));
      expect(arbeitszeitParsen(' 7:5 '), const TimeOfDay(hour: 7, minute: 5));
      expect(arbeitszeitParsen('705'), isNull);
      expect(arbeitszeitParsen('a:b'), isNull);
      expect(arbeitszeitParsen('1:2:3'), isNull);
      expect(
        arbeitszeitFormatieren(const TimeOfDay(hour: 7, minute: 5)),
        '07:05',
      );
    });

    test('laufende Zeit: Minuten seit Beginn', () {
      final jetzt = DateTime(2026, 9, 26, 10, 45);
      expect(laufendeArbeitszeitText('09:30', '', jetzt), 'seit 09:30 · 75 min');
    });

    test('laufende Zeit: Beginn gestern (über Mitternacht)', () {
      final jetzt = DateTime(2026, 9, 26, 0, 30);
      expect(laufendeArbeitszeitText('23:30', '', jetzt), 'seit 23:30 · 60 min');
    });

    test('laufende Zeit: null mit Ende oder ohne Beginn', () {
      final jetzt = DateTime(2026, 9, 26, 10, 45);
      expect(laufendeArbeitszeitText('09:30', '10:00', jetzt), isNull);
      expect(laufendeArbeitszeitText('', '', jetzt), isNull);
    });
  });

  group('BetriebFeld', () {
    final betriebe = [
      _betrieb('1', 'Adler', ort: 'Chur', berg: true),
      _betrieb('2', 'Bären', ort: 'Davos'),
    ];

    testWidgets('zeigt den gewählten Betrieb (mit Ort) an', (tester) async {
      await tester.pumpWidget(
        _huelle(
          BetriebFeld(
            betriebe: betriebe,
            betriebId: '1',
            mitOrt: true,
            onGewaehlt: (_) {},
            onGeleert: () {},
          ),
        ),
      );
      expect(find.text('Adler, Chur'), findsOneWidget);
    });

    testWidgets('Auswahl ruft onGeaendert und onGewaehlt', (tester) async {
      BetriebLocal? gewaehlt;
      var geaendert = 0;
      await tester.pumpWidget(
        _huelle(
          BetriebFeld(
            betriebe: betriebe,
            betriebId: null,
            onGeaendert: () => geaendert++,
            onGewaehlt: (b) => gewaehlt = b,
            onGeleert: () {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'dav');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bären'));
      await tester.pumpAndSettle();
      expect(gewaehlt?.serverId, '2');
      expect(geaendert, 1);
    });

    testWidgets('Kreuz-Knopf leert', (tester) async {
      var geleert = false;
      await tester.pumpWidget(
        _huelle(
          BetriebFeld(
            betriebe: betriebe,
            betriebId: '1',
            onGewaehlt: (_) {},
            onGeleert: () => geleert = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.clear));
      expect(geleert, isTrue);
    });

    testWidgets('leer tippen leert (Variante tippen, kein Kreuz)', (
      tester,
    ) async {
      var geleert = false;
      await tester.pumpWidget(
        _huelle(
          BetriebFeld(
            betriebe: betriebe,
            betriebId: '1',
            leeren: BetriebLeeren.tippen,
            onGewaehlt: (_) {},
            onGeleert: () => geleert = true,
          ),
        ),
      );
      expect(find.byIcon(Icons.clear), findsNothing);
      await tester.enterText(find.byType(TextFormField), '');
      expect(geleert, isTrue);
    });

    testWidgets('Pflichtmeldung ohne Betrieb', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: BetriebFeld(
                betriebe: betriebe,
                betriebId: null,
                pflichtMeldung: 'Betrieb auswählen',
                onGewaehlt: (_) {},
                onGeleert: () {},
              ),
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Betrieb auswählen'), findsOneWidget);
    });
  });

  group('ArbeitszeitBlock', () {
    late TextEditingController von;
    late TextEditingController bis;

    setUp(() {
      von = TextEditingController();
      bis = TextEditingController();
    });
    tearDown(() {
      von.dispose();
      bis.dispose();
    });

    Widget block({
      required bool beginnMoeglich,
      VoidCallback? onBeginnen,
      VoidCallback? onBeenden,
    }) => _huelle(
      ArbeitszeitBlock(
        vonController: von,
        bisController: bis,
        beginnMoeglich: beginnMoeglich,
        laeuft: false,
        onBeginnen: onBeginnen ?? () {},
        onBeenden: onBeenden ?? () {},
        onGeaendert: () {},
        zwischen: const [Text('dazwischen')],
      ),
    );

    testWidgets('ohne Plan: nur Zeitfelder, kein Knopf', (tester) async {
      await tester.pumpWidget(block(beginnMoeglich: false));
      expect(find.text('Arbeit beginnen'), findsNothing);
      expect(find.text('Arbeit von'), findsOneWidget);
      expect(find.text('Arbeit bis'), findsOneWidget);
      expect(find.text('dazwischen'), findsOneWidget);
    });

    testWidgets('geplant: «Arbeit beginnen» ruft onBeginnen', (tester) async {
      var begonnen = false;
      await tester.pumpWidget(
        block(beginnMoeglich: true, onBeginnen: () => begonnen = true),
      );
      await tester.tap(find.text('Arbeit beginnen'));
      expect(begonnen, isTrue);
    });

    testWidgets('laufend: Band mit Beenden, Timer läuft und endet', (
      tester,
    ) async {
      von.text = '08:00';
      var beendet = false;
      await tester.pumpWidget(
        block(beginnMoeglich: true, onBeenden: () => beendet = true),
      );
      expect(find.textContaining('seit 08:00'), findsOneWidget);
      final state = tester.state(find.byType(ArbeitszeitBlock)) as dynamic;
      expect(state.timerAktiv, isTrue);

      await tester.tap(find.byType(ArbeitBeendenKnopf));
      expect(beendet, isTrue);

      bis.text = '09:00';
      await tester.pumpWidget(block(beginnMoeglich: true));
      expect(state.timerAktiv, isFalse);
      expect(find.text('Arbeit erfasst: 08:00 – 09:00'), findsOneWidget);
    });

    testWidgets('dispose beendet den Timer', (tester) async {
      von.text = '08:00';
      await tester.pumpWidget(block(beginnMoeglich: true));
      final state = tester.state(find.byType(ArbeitszeitBlock)) as dynamic;
      expect(state.timerAktiv, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(state.timerAktiv, isFalse);
    });
  });

  group('MaterialSlots', () {
    testWidgets('Auswahl setzt ID und Name, Leeren setzt zurück', (
      tester,
    ) async {
      final ids = List<String?>.filled(5, null);
      final namen = List.generate(5, (_) => TextEditingController());
      final mengenCtrl = List.generate(
        5,
        (_) => TextEditingController(text: '1'),
      );
      final mengen = List<double>.filled(5, 1);
      final feld = List<TextEditingController?>.filled(5, null);
      var geaendert = 0;
      await tester.pumpWidget(
        _huelle(
          MaterialSlots(
            lager: [_lager('h', 'Hahn')],
            ids: ids,
            namen: namen,
            mengenController: mengenCtrl,
            mengen: mengen,
            feldController: feld,
            onGeaendert: () => geaendert++,
          ),
        ),
      );
      expect(find.text('Material 5'), findsOneWidget);
      expect(feld.every((c) => c != null), isTrue);

      await tester.enterText(find.byType(TextFormField).first, 'ha');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hahn').last);
      await tester.pumpAndSettle();
      expect(ids[0], 'h');
      expect(namen[0].text, 'Hahn');
      expect(geaendert, 1);

      await tester.enterText(find.byType(TextFormField).at(1), '3');
      expect(mengen[0], 3);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(ids[0], isNull);
      expect(namen[0].text, '');
      expect(geaendert, 2);
    });

    testWidgets('einfach: 3 Slots ohne Leeren-Knopf, Auswahl nur ID', (
      tester,
    ) async {
      final ids = List<String?>.filled(3, null);
      final namen = List.generate(3, (_) => TextEditingController());
      final mengenCtrl = List.generate(
        3,
        (_) => TextEditingController(text: '1'),
      );
      await tester.pumpWidget(
        _huelle(
          MaterialSlots(
            lager: [_lager('h', 'Hahn', dbo: 'D1')],
            ids: ids,
            namen: namen,
            mengenController: mengenCtrl,
            feldController: namen,
            mengenBreite: 60,
            einfach: true,
            onGeaendert: () {},
          ),
        ),
      );
      expect(find.text('Material 3'), findsOneWidget);
      expect(find.text('Material 4'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'd1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hahn').last);
      await tester.pumpAndSettle();
      expect(ids[0], 'h');
      // Der Autocomplete-Controller steht jetzt in `namen` (bisheriges
      // Eigenauftrag-Verhalten) und trägt den Namen.
      expect(namen[0].text, 'Hahn');
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });
}
