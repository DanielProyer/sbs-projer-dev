import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/rechnung_status.dart';
import 'package:sbs_projer_app/core/util/zahlungsstatus.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/rechnungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/widgets/rechnung_status_farbe.dart';

/// Review 27.09.2026, K1: Anzeige und Filter der Rechnungslisten aus EINER
/// Ableitung ([anzeigeSchluessel]). Vorher färbten vier Screens je mit eigener
/// Tabelle nach dem rohen Status — «Gesendet» stand grau, und der Filter
/// «Mahnung 1» hiess anders als der Chip «1. Mahnung».
void main() {
  Rechnung rg({
    String status = 'offen',
    int stufe = 0,
    DateTime? versendet,
    DateTime? uebergeben,
  }) => Rechnung(
    id: 'r1',
    userId: 'u1',
    rechnungsnummer: 'R-1',
    rechnungstyp: 'kundenrechnung',
    rechnungsdatum: DateTime(2026, 9, 1),
    faelligkeitsdatum: DateTime(2026, 10, 1),
    betragBrutto: 100,
    zahlungsstatus: status,
    mahnungStufe: stufe,
    versendetAm: versendet,
    uebergebenAm: uebergeben,
  );

  group('rechnungStatusFarbe', () {
    test('gesendet und übergeben wie offen (unbezahlt, ungemahnt)', () {
      expect(rechnungStatusFarbe(Zahlungsstatus.offen), AppColors.warning);
      expect(rechnungStatusFarbe(Zahlungsstatus.gesendet), AppColors.warning);
      expect(rechnungStatusFarbe(kAnzeigeUebergeben), AppColors.warning);
    });

    test('freigegeben blau', () {
      expect(rechnungStatusFarbe(Zahlungsstatus.freigegeben), AppColors.info);
    });

    test('jeder Anzeige-Schlüssel hat eine eigene Farbe, nicht grau', () {
      for (final k in {...Zahlungsstatus.alle, kAnzeigeUebergeben}) {
        expect(
          rechnungStatusFarbe(k),
          isNot(AppColors.textSecondary),
          reason: k,
        );
      }
      // Unbekanntes bleibt sichtbar anders.
      expect(rechnungStatusFarbe('storniert'), AppColors.textSecondary);
    });

    test('Mahnstufe aus mahnung_stufe färbt wie der Text', () {
      final r = rg(status: 'gesendet', stufe: 2);
      expect(anzeigeStatus(r), '1. Mahnung');
      expect(
        rechnungStatusFarbe(anzeigeSchluessel(r)),
        rechnungStatusFarbe(Zahlungsstatus.mahnung1),
      );
    });
  });

  group('Filter der Rechnungsliste', () {
    test('Labels sind die Wörter der Anzeige', () {
      expect(anzeigeTextFuer(Zahlungsstatus.mahnung1), '1. Mahnung');
      expect(anzeigeTextFuer(Zahlungsstatus.mahnung2), 'Letzte Mahnung');
      expect(anzeigeTextFuer(Zahlungsstatus.gesendet), 'Gesendet');
      expect(anzeigeTextFuer(kAnzeigeUebergeben), 'Übergeben');
      // Dieselbe Übersetzung wie der Chip.
      final r = rg(status: 'mahnung_2', stufe: 3);
      expect(anzeigeStatus(r), anzeigeTextFuer(anzeigeSchluessel(r)));
    });

    test('jeder Filterwert ist per ?status= erlaubt', () {
      for (final k in kAnzeigeFilterSchluessel) {
        expect(rechnungStartStatus(k), k);
      }
      expect(rechnungStartStatus('gesendet'), 'gesendet');
      expect(rechnungStartStatus('uebergeben'), 'uebergeben');
    });

    test('jede Rechnung ausser freigegeben findet ihren Filter', () {
      final faelle = [
        rg(),
        rg(versendet: DateTime(2026, 9, 2)), // offen, aber zugestellt
        rg(status: 'gesendet'),
        rg(uebergeben: DateTime(2026, 9, 2)),
        rg(status: 'erinnert', stufe: 1),
        rg(status: 'gesendet', stufe: 2),
        rg(status: 'mahnung_2', stufe: 3),
        rg(status: 'bezahlt'),
        rg(status: 'abgeschrieben'),
      ];
      for (final r in faelle) {
        expect(
          kAnzeigeFilterSchluessel,
          contains(anzeigeSchluessel(r)),
          reason: '${r.zahlungsstatus}/${r.mahnungStufe}',
        );
      }
    });

    test('Wächter: Liste filtert und färbt über den Anzeige-Schlüssel', () {
      final code = File(
        'lib/presentation/screens/rechnungen/rechnungen_list_screen.dart',
      ).readAsStringSync().replaceAll(RegExp(r'//.*'), '');
      expect(code, contains('anzeigeSchluessel(r) != _statusFilter'));
      expect(code, isNot(contains('r.zahlungsstatus != _statusFilter')));
      expect(code, isNot(contains("'Mahnung 1'")));
      expect(code, isNot(contains('_statusColor(')));
      expect(code, isNot(contains('rechnungStatusFarbe(rechnung.zahlungsstatus)')));
      // Die Summenkarte «Offene Forderungen» zählt istOffen — ihr Filter
      // muss dieselbe Menge zeigen.
      expect(code, isNot(contains("_statusFilter = 'offen'")));
    });
  });
}
