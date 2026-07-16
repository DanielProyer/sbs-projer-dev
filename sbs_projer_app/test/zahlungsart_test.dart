import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/zahlungsart.dart';

void main() {
  group('resolveZahlungsart', () {
    test('Reinigungs-Wert gewinnt immer', () {
      expect(
        resolveZahlungsart('rechnung_mail', 'rechnung_tresen'),
        'rechnung_mail',
      );
      expect(resolveZahlungsart('barzahlung', 'heineken'), 'barzahlung');
    });
    test('NULL/leer auf der Reinigung -> Betriebs-Default', () {
      expect(resolveZahlungsart(null, 'rechnung_tresen'), 'rechnung_tresen');
      expect(resolveZahlungsart('', 'barzahlung'), 'barzahlung');
    });
    test(
      'beides leer -> rechnung_tresen (sicherster Default: erzeugt Rechnung)',
      () {
        expect(resolveZahlungsart(null, null), 'rechnung_tresen');
        expect(resolveZahlungsart('', ''), 'rechnung_tresen');
      },
    );
  });

  group('istRechnungsart', () {
    test('tresen/mail/post -> true, Rest -> false', () {
      expect(istRechnungsart('rechnung_tresen'), isTrue);
      expect(istRechnungsart('rechnung_mail'), isTrue);
      expect(istRechnungsart('rechnung_post'), isTrue);
      expect(istRechnungsart('barzahlung'), isFalse);
      expect(istRechnungsart('heineken'), isFalse);
      expect(istRechnungsart('jahresrechnung'), isFalse);
      expect(istRechnungsart(null), isFalse);
    });
  });

  group('zahlungsartKlartext', () {
    test('jede Art hat einen erklaerenden Satz', () {
      expect(
        zahlungsartKlartext('rechnung_tresen', kundenEmail: null),
        'Rechnung + Einzahlungsschein, Übergabe vor Ort, kein Versand',
      );
      expect(
        zahlungsartKlartext('rechnung_mail', kundenEmail: 'a@b.ch'),
        'Rechnung per Mail an a@b.ch',
      );
      expect(
        zahlungsartKlartext('rechnung_mail', kundenEmail: null),
        '⚠ Keine Rechnungsadresse-E-Mail — Rechnung geht NICHT an den Kunden',
      );
      expect(
        zahlungsartKlartext('rechnung_post', kundenEmail: null),
        'Rechnung per Mail an dich (Ausdrucken + Post)',
      );
      expect(
        zahlungsartKlartext('barzahlung', kundenEmail: null),
        'Bar kassiert → Kasse, keine Rechnung',
      );
      expect(
        zahlungsartKlartext('heineken', kundenEmail: null),
        'Keine Einzelrechnung — läuft über die Heineken-Monatsabrechnung',
      );
      expect(
        zahlungsartKlartext('jahresrechnung', kundenEmail: null),
        'Keine Einzelrechnung — läuft über die Jahresrechnung',
      );
    });
  });

  group('qrReferenzFuerReinigung', () {
    test(
      'Rechnungsart -> deterministische SCOR-Referenz (Datum+BetriebNr)',
      () {
        final ref = qrReferenzFuerReinigung(
          zahlungsart: 'rechnung_tresen',
          datum: DateTime(2026, 6, 26),
          betriebNr: '0476',
        );
        expect(ref, isNotNull);
        expect(ref, startsWith('RF'));
        expect(ref, contains('202606260476'));
      },
    );
    test('barzahlung/heineken -> null (QR bleibt referenzlos)', () {
      expect(
        qrReferenzFuerReinigung(
          zahlungsart: 'barzahlung',
          datum: DateTime(2026, 6, 26),
          betriebNr: '0476',
        ),
        isNull,
      );
      expect(
        qrReferenzFuerReinigung(
          zahlungsart: 'heineken',
          datum: DateTime(2026, 6, 26),
          betriebNr: '0476',
        ),
        isNull,
      );
    });
    test('fehlende BetriebNr -> Ziffernfallback 0000 wie die Rechnung', () {
      final ref = qrReferenzFuerReinigung(
        zahlungsart: 'rechnung_mail',
        datum: DateTime(2026, 6, 26),
        betriebNr: null,
      );
      expect(ref, contains('202606260000'));
    });
  });

  group('warnungsGrund', () {
    test('Kasse gebucht -> nie flaggen (bar erledigt, egal welche Art)', () {
      expect(
        warnungsGrund(
          art: 'rechnung_tresen',
          hatRechnung: false,
          hatBuchung: true,
          kasseGebucht: true,
        ),
        isNull,
      );
    });
    test('heineken/jahresrechnung -> nie flaggen', () {
      expect(
        warnungsGrund(
          art: 'heineken',
          hatRechnung: false,
          hatBuchung: false,
          kasseGebucht: false,
        ),
        isNull,
      );
      expect(
        warnungsGrund(
          art: 'jahresrechnung',
          hatRechnung: false,
          hatBuchung: false,
          kasseGebucht: false,
        ),
        isNull,
      );
    });
    test('Rechnungsart ohne Rechnung -> ohneRechnung', () {
      expect(
        warnungsGrund(
          art: 'rechnung_tresen',
          hatRechnung: false,
          hatBuchung: true,
          kasseGebucht: false,
        ),
        WarnungsGrund.ohneRechnung,
      );
    });
    test('gar keine Buchung -> ohneBuchung (auch bei barzahlung)', () {
      expect(
        warnungsGrund(
          art: 'barzahlung',
          hatRechnung: false,
          hatBuchung: false,
          kasseGebucht: false,
        ),
        WarnungsGrund.ohneBuchung,
      );
    });
    test('alles da -> null', () {
      expect(
        warnungsGrund(
          art: 'rechnung_mail',
          hatRechnung: true,
          hatBuchung: true,
          kasseGebucht: false,
        ),
        isNull,
      );
    });
  });
}
