import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Die Einsatzformulare nutzen die gemeinsamen Bausteine statt eigener
/// Kopien (Analyse 25.09.2026, §2.2 / §4 Nr. 6 und 8).
///
/// WARUM: Betriebfeld, Arbeitszeit-Block und Material-Slots standen je bis
/// zu fünfmal im Code und liefen still auseinander (andere Suchregel,
/// fehlender Validator, andere Feldbreite). Eine Korrektur traf dann nur
/// eine Kopie. Dieser Wächter verhindert, dass eine Kopie zurückkommt.
void main() {
  const pfad = 'lib/presentation/screens';
  const stoerung = '$pfad/stoerungen/stoerung_form_screen.dart';
  const montage = '$pfad/montagen/montage_form_screen.dart';
  const eigen = '$pfad/eigenauftraege/eigenauftrag_form_screen.dart';
  const eroeffnung =
      '$pfad/eroeffnungsreinigungen/eroeffnungsreinigung_form_screen.dart';
  const kontakt = '$pfad/kontakte/kontakt_form_screen.dart';

  String lies(String p) => File(p).readAsStringSync();

  test('fünf Formulare nutzen BetriebFeld', () {
    for (final p in [stoerung, montage, eigen, eroeffnung, kontakt]) {
      final text = lies(p);
      expect(text, contains('BetriebFeld('), reason: p);
      expect(text, isNot(contains('Autocomplete<BetriebLocal>')), reason: p);
    }
  });

  test('Störung und Montage nutzen ArbeitszeitBlock', () {
    for (final p in [stoerung, montage]) {
      final text = lies(p);
      expect(text, contains('ArbeitszeitBlock('), reason: p);
      expect(text, isNot(contains('_buildArbeitBeginnBlock')), reason: p);
      expect(text, isNot(contains('_buildArbeitZeitfelder')), reason: p);
      expect(text, isNot(contains('Timer.periodic')), reason: p);
    }
  });

  test('Störung, Montage und Eigenauftrag nutzen MaterialSlots', () {
    for (final p in [stoerung, montage, eigen]) {
      final text = lies(p);
      expect(text, contains('MaterialSlots('), reason: p);
      expect(text, isNot(contains('_buildMaterialSlots')), reason: p);
      expect(text, isNot(contains('Autocomplete<Lager>')), reason: p);
    }
  });
}
