/// Erlaubte Werte von `rechnungen.zahlungsstatus` — dieselbe Liste wie der
/// CHECK der letzten Migration, die ihn setzt (Wächter:
/// test/zahlungsstatus_waechter_test.dart). Früher benutzte Werte (entwurf,
/// versendet, gestellt, teilbezahlt, ueberfaellig, storniert) werfen seit den
/// Migrationen 081–083 eine PostgrestException.
abstract final class Zahlungsstatus {
  static const offen = 'offen';
  static const gesendet = 'gesendet';
  static const freigegeben = 'freigegeben';
  static const bezahlt = 'bezahlt';
  static const erinnert = 'erinnert';
  static const mahnung1 = 'mahnung_1';
  static const mahnung2 = 'mahnung_2';
  static const abgeschrieben = 'abgeschrieben';
  static const alle = {
    offen,
    gesendet,
    freigegeben,
    bezahlt,
    erinnert,
    mahnung1,
    mahnung2,
    abgeschrieben,
  };
  static const erledigt = {bezahlt, abgeschrieben};
  static const gemahnt = {erinnert, mahnung1, mahnung2};
  static const altwerte = {
    'entwurf',
    'versendet',
    'gestellt',
    'teilbezahlt',
    'ueberfaellig',
    'storniert',
  };
}
