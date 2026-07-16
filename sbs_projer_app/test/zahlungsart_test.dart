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
}
