import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/abschluss_dialog_regel.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';

void main() {
  Set<AbschlussDialogGrund> g({
    required String gewaehlt,
    String? vorgabe = 'rechnung_mail',
    String? email = 'wirt@example.ch',
    String? hinweis,
    String? schalter,
  }) => abschlussDialogGruende(
    gewaehlt: gewaehlt,
    vorgabeBetrieb: vorgabe,
    kundenEmail: email,
    serviceHinweis: hinweis,
    schalterHinweis: schalter,
  );

  group('abschlussDialogGruende', () {
    test('Vorgabe übernommen, E-Mail da, kein Hinweis → direkt abschliessen',
        () {
      expect(g(gewaehlt: 'rechnung_mail'), isEmpty);
    });

    test('Tresen ohne E-Mail → leer (E-Mail nur für Mail nötig)', () {
      expect(
        g(gewaehlt: 'rechnung_tresen', vorgabe: 'rechnung_tresen', email: null),
        isEmpty,
      );
    });

    test('Mail ohne E-Mail (null oder leer) → mailOhneAdresse', () {
      expect(g(gewaehlt: 'rechnung_mail', email: null), {
        AbschlussDialogGrund.mailOhneAdresse,
      });
      expect(g(gewaehlt: 'rechnung_mail', email: '  '), {
        AbschlussDialogGrund.mailOhneAdresse,
      });
    });

    test('Service-Hinweis nur, wenn nicht leer', () {
      expect(g(gewaehlt: 'rechnung_mail', hinweis: '   '), isEmpty);
      expect(g(gewaehlt: 'rechnung_mail', hinweis: 'Nächste gratis'), {
        AbschlussDialogGrund.serviceHinweis,
      });
    });

    test('Schalter-Hinweis (Booster wieder an) → schalterHinweis', () {
      expect(g(gewaehlt: 'rechnung_mail', schalter: 'Booster wieder an'), {
        AbschlussDialogGrund.schalterHinweis,
      });
      expect(g(gewaehlt: 'rechnung_mail', schalter: ''), isEmpty);
    });

    test('Abweichung von der Betriebs-Vorgabe', () {
      expect(g(gewaehlt: 'barzahlung'), {AbschlussDialogGrund.abweichung});
    });

    test('Vorgabe fehlt → Rückfall wie resolveZahlungsart (Tresen)', () {
      expect(resolveZahlungsart(null, null), 'rechnung_tresen');
      expect(g(gewaehlt: 'rechnung_tresen', vorgabe: null), isEmpty);
      expect(g(gewaehlt: 'rechnung_tresen', vorgabe: ''), isEmpty);
      expect(g(gewaehlt: 'barzahlung', vorgabe: null), {
        AbschlussDialogGrund.abweichung,
      });
    });

    test('abweichend auf Mail ohne E-Mail + Hinweis → alle Gründe', () {
      expect(
        g(
          gewaehlt: 'rechnung_mail',
          vorgabe: 'rechnung_tresen',
          email: null,
          hinweis: 'Kulanz besprechen',
          schalter: 'Eissäule an',
        ),
        {
          AbschlussDialogGrund.mailOhneAdresse,
          AbschlussDialogGrund.serviceHinweis,
          AbschlussDialogGrund.abweichung,
          AbschlussDialogGrund.schalterHinweis,
        },
      );
    });

    test('alle Kombinationen: jeder Grund genau dann, wenn seine Bedingung gilt',
        () {
      for (final gewaehlt in zahlungsarten) {
        for (final vorgabe in [null, '', ...zahlungsarten]) {
          for (final email in [null, '', 'a@b.ch']) {
            for (final hinweis in [null, '', 'X']) {
              final r = g(
                gewaehlt: gewaehlt,
                vorgabe: vorgabe,
                email: email,
                hinweis: hinweis,
              );
              expect(
                r.contains(AbschlussDialogGrund.mailOhneAdresse),
                gewaehlt == 'rechnung_mail' && (email ?? '').isEmpty,
              );
              expect(
                r.contains(AbschlussDialogGrund.serviceHinweis),
                hinweis == 'X',
              );
              expect(
                r.contains(AbschlussDialogGrund.abweichung),
                gewaehlt != resolveZahlungsart(null, vorgabe),
              );
              expect(r.contains(AbschlussDialogGrund.schalterHinweis), isFalse);
            }
          }
        }
      }
    });
  });

  test('Label je Zahlungsart vorhanden, Reihenfolge wie das alte Dropdown', () {
    expect(zahlungsartAuswahl.map((e) => e.$1).toList(), [
      'rechnung_mail',
      'rechnung_post',
      'rechnung_tresen',
      'barzahlung',
      'jahresrechnung',
      'heineken',
    ]);
    expect(zahlungsartLabel('rechnung_mail'), 'Per E-Mail');
    expect(zahlungsartLabel('heineken'), 'Via Heineken (monatlich)');
    expect(zahlungsartLabel('unbekannt'), 'unbekannt');
  });
}
