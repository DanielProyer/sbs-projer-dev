import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/betrieb_geld.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

Rechnung rechnung({
  String typ = 'kundenrechnung',
  String status = 'offen',
  double brutto = 100,
  double guthaben = 0,
  int mahnstufe = 0,
  DateTime? faellig,
}) => Rechnung(
  id: 'x',
  userId: 'u',
  rechnungstyp: typ,
  rechnungsdatum: DateTime(2026, 8, 1),
  faelligkeitsdatum: faellig ?? DateTime(2026, 10, 30),
  betragBrutto: brutto,
  zahlungsstatus: status,
  mahnungStufe: mahnstufe,
  guthabenVerrechnet: guthaben,
);

void main() {
  final heute = DateTime(2026, 9, 26, 15, 30);

  test('ohne Rechnungen ist alles null', () {
    final g = betriebGeldStand(const [], 0, heute: heute);
    expect(g.offenCHF, 0);
    expect(g.anzahlOffen, 0);
    expect(g.anzahlUeberfaellig, 0);
    expect(g.hoechsteMahnstufe, 0);
    expect(g.guthabenCHF, 0);
  });

  test('summiert zuZahlen der zahlbaren Kunden- und Jahresrechnungen', () {
    final g = betriebGeldStand([
      rechnung(brutto: 177.30),
      rechnung(typ: 'jahresrechnung', status: 'gesendet', brutto: 500),
      // Guthaben verrechnet: nur der Rest zählt.
      rechnung(brutto: 100, guthaben: 40),
    ], 0, heute: heute);
    expect(g.offenCHF, closeTo(737.30, 0.001));
    expect(g.anzahlOffen, 3);
  });

  test('Bezahltes, Abgeschriebenes und Heineken-Monatsrechnungen zählen nicht',
      () {
    final g = betriebGeldStand([
      rechnung(status: 'bezahlt'),
      rechnung(status: 'abgeschrieben'),
      rechnung(typ: 'heineken_monatsrechnung', status: 'freigegeben'),
      rechnung(typ: 'heineken_monatsrechnung', status: 'offen'),
    ], 0, heute: heute);
    expect(g.offenCHF, 0);
    expect(g.anzahlOffen, 0);
  });

  test('gemahnte Rechnungen sind offen, höchste Mahnstufe gewinnt', () {
    final g = betriebGeldStand([
      rechnung(status: 'erinnert'),
      rechnung(status: 'mahnung_2', mahnstufe: 2),
      // Bezahlte mit alter Mahnstufe zählt nicht mehr.
      rechnung(status: 'bezahlt', mahnstufe: 2),
    ], 0, heute: heute);
    expect(g.anzahlOffen, 2);
    expect(g.hoechsteMahnstufe, 3);
    expect(mahnstufeLabel(g.hoechsteMahnstufe), '2. Mahnung');
  });

  test('Mahnstufe kommt aus dem Status, nicht aus mahnung_stufe', () {
    // Bewusst zwei unabhängige Quellen: Selbst wenn mahnung_stufe (hier 0)
    // vom Status abweicht, zählt für die Anzeige nur zahlungsstatus.
    final g = betriebGeldStand([
      rechnung(status: 'erinnert', mahnstufe: 0),
    ], 0, heute: heute);
    expect(g.hoechsteMahnstufe, 1);
    expect(mahnstufeLabel(1), 'Erinnerung');
    expect(mahnstufeLabel(2), '1. Mahnung');
    expect(
      betriebGeldStand([rechnung(status: 'gesendet')], 0, heute: heute)
          .hoechsteMahnstufe,
      0,
    );
  });

  test('überfällig heisst: Fälligkeit vor heute (Tag, nicht Uhrzeit)', () {
    final g = betriebGeldStand([
      rechnung(faellig: DateTime(2026, 9, 25)),
      rechnung(faellig: DateTime(2026, 9, 26)),
      rechnung(faellig: DateTime(2026, 9, 27)),
      rechnung(status: 'bezahlt', faellig: DateTime(2026, 1, 1)),
    ], 0, heute: heute);
    expect(g.anzahlUeberfaellig, 1);
  });

  test('Guthaben wird durchgereicht, negatives als 0', () {
    expect(betriebGeldStand(const [], 55.5, heute: heute).guthabenCHF, 55.5);
    expect(betriebGeldStand(const [], -3, heute: heute).guthabenCHF, 0);
  });

  test('Geld-Block öffnet die offenen Rechnungen des Betriebs', () {
    expect(
      betriebOffeneRechnungenRoute('Pub & Bar'),
      '/rechnungen?suche=Pub+%26+Bar&status=unbezahlt',
    );
    final uri = Uri.parse(betriebOffeneRechnungenRoute('Pub & Bar'));
    expect(uri.queryParameters['suche'], 'Pub & Bar');
    expect(uri.queryParameters['status'], 'unbezahlt');
  });
}
