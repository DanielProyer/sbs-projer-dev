import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';

Rechnung _rg(String id, String betriebId, double betrag) => Rechnung(
      id: id, userId: 'u', rechnungsnummer: id, rechnungstyp: 'kundenrechnung',
      betriebId: betriebId, rechnungsdatum: DateTime(2025, 1, 1),
      faelligkeitsdatum: DateTime(2025, 2, 1), betragNetto: betrag, mwstBetrag: 0,
      betragBrutto: betrag, zahlungsstatus: 'offen');

CamtTransaction _gut(double amt, String party, [String? info]) => CamtTransaction(
      amount: amt, currency: 'CHF', isCredit: true, bookingDate: DateTime(2026, 1, 5),
      partyName: party, additionalInfo: info, txKey: '$party-$amt');

Rechnung _rgMitRef(String id, String betriebId, double betrag, String ref) =>
    Rechnung(
      id: id, userId: 'u', rechnungsnummer: id, rechnungstyp: 'kundenrechnung',
      betriebId: betriebId, rechnungsdatum: DateTime(2025, 1, 1),
      faelligkeitsdatum: DateTime(2025, 2, 1), betragNetto: betrag, mwstBetrag: 0,
      betragBrutto: betrag, zahlungsstatus: 'offen', qrReferenz: ref);

CamtTransaction _gutMitRef(double amt, String party, String ref) =>
    CamtTransaction(
      amount: amt, currency: 'CHF', isCredit: true,
      bookingDate: DateTime(2026, 4, 1),
      partyName: party, strukturierteReferenz: ref, txKey: '$party-$amt');

void main() {
  final betriebe = [
    {'id': 'b1', 'name': 'Hotel Alpina'},
    {'id': 'b2', 'name': 'Gastro Latina GmbH'},
  ];

  test('eindeutige Einzelzahlung → auto', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.first.forderungen.single.id, 'r1');
    expect(r.auto.first.gutschrift.amount, 67.85);
    expect(r.manuell, isEmpty);
    expect(r.keineZahlung, isEmpty);
  });

  test('Sammelzahlung über zwei Forderungen → auto', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(135.70, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.first.forderungen.map((f) => f.id).toSet(), {'r1', 'r2'});
  });

  test('Zahlername aus AddtlNtryInf wird genutzt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(50.0, '', 'Gutschrift Gastro Latina GmbH')],
      offeneForderungen: [_rg('r3', 'b2', 50.0)],
      betriebe: betriebe,
    );
    expect(r.auto.single.forderungen.single.id, 'r3');
  });

  test('kein Betrieb-Match → Gutschrift ignoriert, Forderung bleibt offen', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(99.0, 'Unbekannt AG')],
      offeneForderungen: [_rg('r4', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.keineZahlung.single.id, 'r4');
  });

  test('Betrieb mit offener Forderung, Betrag passt nicht → manuell', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(40.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r5', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.manuell.single.betriebId, 'b1');
    expect(r.manuell.single.gutschriften.single.amount, 40.0);
    expect(r.manuell.single.forderungen.single.id, 'r5');
  });

  test('Gutschrift nur einmal verbraucht', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.manuell.single.forderungen.length, 2);
  });

  test('Gutschrift ohne offene Forderung wird verworfen', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: const [], // keine offene Forderung für b1 (oder irgendeinen Betrieb)
      betriebe: betriebe,
    );
    expect(r.auto, isEmpty);
    expect(r.manuell, isEmpty);
    expect(r.keineZahlung, isEmpty);
  });

  test('ein Treffer auto, übrige Gutschrift → manuell', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina'), _gut(99.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 40.0)],
      betriebe: betriebe,
    );
    // 67.85 matcht eindeutig r1 → auto; 99.0 matcht keine (Rest-)Forderung → manuell.
    expect(r.auto.length, 1);
    expect(r.auto.single.forderungen.map((f) => f.id).toSet(), {'r1'});
    expect(r.manuell.length, 1);
    expect(r.manuell.single.betriebId, 'b1');
    expect(r.manuell.single.gutschriften.map((g) => g.amount), contains(99.0));
    expect(r.manuell.single.forderungen.map((f) => f.id), contains('r2'));
    expect(r.keineZahlung, isEmpty);
  });

  test('alle Gutschriften verbraucht, Forderung bleibt → keineZahlung', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85), _rg('r2', 'b1', 40.0)],
      betriebe: betriebe,
    );
    expect(r.auto.length, 1);
    expect(r.auto.single.forderungen.map((f) => f.id).toSet(), {'r1'});
    expect(r.manuell, isEmpty);
    expect(r.keineZahlung.map((f) => f.id), contains('r2'));
  });

  test('benannte Gutschrift ohne Betrieb-Match → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(99.0, 'Unbekannt AG')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften.single.amount, 99.0);
    expect(r.auto, isEmpty);
    expect(r.keineZahlung.single.id, 'r1');
  });

  test('Betrieb ohne offene Forderung, Gutschrift vorhanden → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(50.0, 'Gastro Latina GmbH')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften.single.amount, 50.0);
  });

  test('Rest-Gutschrift nach Auto-Match (Forderungen leer) → unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina'), _gut(200.0, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.single.forderungen.single.id, 'r1');
    expect(r.unbekannteGutschriften.single.amount, 200.0);
  });

  test('namenlose Gutschrift (Saldovortrag) → NICHT unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(10.0, '', 'Saldovortrag')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.unbekannteGutschriften, isEmpty);
  });

  test('zugeordnete (auto) Gutschrift nicht doppelt in unbekannt', () {
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(67.85, 'Hotel Alpina')],
      offeneForderungen: [_rg('r1', 'b1', 67.85)],
      betriebe: betriebe,
    );
    expect(r.auto.single.gutschrift.amount, 67.85);
    expect(r.unbekannteGutschriften, isEmpty);
  });

  test('QR-Referenz-Treffer (Stufe 1) ordnet exakt zu, vor Betrieb-Logik', () {
    final betriebe = [
      {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': ''},
    ];
    // Zahlername passt NICHT auf den Betrieb — nur die Referenz verbindet.
    final gut = _gutMitRef(100.00, 'Wildfremd AG', 'RF18539007547034');
    final rg = _rgMitRef('r1', 'b1', 100.00, 'RF18539007547034');
    final erg = ForderungsAbgleichService.abgleich(
      gutschriften: [gut], offeneForderungen: [rg], betriebe: betriebe,
    );
    expect(erg.auto.length, 1);
    expect(erg.auto.first.forderungen.first.id, 'r1');
    expect(erg.auto.first.forderungen.length, 1);
  });

  test('Alias-Treffer ordnet Gutschrift dem Betrieb zu (Stufe 2 vor Unscharf)', () {
    final betriebeMitAlias = [
      {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': 'znueni beiz'},
    ];
    final r = ForderungsAbgleichService.abgleich(
      gutschriften: [_gut(100.00, 'Znueni Beiz')],
      offeneForderungen: [_rg('r1', 'b1', 100.00)],
      betriebe: betriebeMitAlias,
    );
    expect(r.auto.length, 1);
    expect(r.auto.first.forderungen.first.id, 'r1');
  });

  group('Sammelzahler-Routing (Regel Daniel 07.08.2026)', () {
    test('Goodfast ohne Vermerk-Hinweis → Nicht zugeordnet (kein Betrags-/Namens-Routing)',
        () {
      // Bewusst KEIN Routing über den Betrag: Das warf Zahlungen in fremde
      // Betriebe mit zufällig gleichem Betrag (Fall Waldhuus). Zuordnung
      // manuell — der Dialog hebt Betrags-Treffer hervor.
      final r = ForderungsAbgleichService.abgleich(
        gutschriften: [_gut(143.75, 'Goodfast Hotels AG')],
        offeneForderungen: [
          _rg('r1', 'b1', 143.75),
          _rg('r2', 'b2', 99.0),
        ],
        betriebe: betriebe,
      );
      expect(r.auto, isEmpty);
      expect(r.manuell, isEmpty);
      expect(r.unbekannteGutschriften.single.amount, 143.75);
    });

    test('Sammelzahler wird NICHT über Alias/Namen geroutet', () {
      // Weisse Arena hat einen gelernten Alias auf IKIGAI — ohne Vermerk darf
      // die Zahlung trotzdem nicht bei IKIGAI landen (sie kann jedem der
      // sechs Objekte gehören).
      final r = ForderungsAbgleichService.abgleich(
        gutschriften: [_gut(74.60, 'Weisse Arena Hospitality AG')],
        offeneForderungen: [_rg('r1', 'b1', 74.60)],
        betriebe: [
          {'id': 'b1', 'name': 'IKIGAI', 'aliase': 'weisse arena hospitality ag'},
        ],
      );
      expect(r.auto, isEmpty);
      expect(r.manuell, isEmpty);
      expect(r.unbekannteGutschriften.single.amount, 74.60);
    });

    test('Vermerk-Betriebsnummer routet den Sammelzahler', () {
      final betriebeMitNr = [
        {'id': 'b1', 'name': 'Grischa', 'heineken_nr': '0089'},
        {'id': 'b2', 'name': 'Golden Dragon', 'heineken_nr': '0090'},
      ];
      final g = CamtTransaction(
        amount: 100.0,
        currency: 'CHF',
        isCredit: true,
        bookingDate: DateTime(2026, 4, 22),
        partyName: 'Davos Klosters Bergbahnen AG',
        remittanceInfo: '04.04.2026 0090_2026_04_04',
        txKey: 'tx-dkb',
      );
      final r = ForderungsAbgleichService.abgleich(
        gutschriften: [g],
        // Betrag 100 passt exakt auf die b1-Forderung — die Nummer im Vermerk
        // sagt aber b2, und die gewinnt.
        offeneForderungen: [
          _rg('r1', 'b1', 100.0),
          _rg('r2', 'b2', 55.0),
        ],
        betriebe: betriebeMitNr,
      );
      expect(r.manuell.single.betriebId, 'b2');
    });

    test('Rechnungsnummer im Vermerk routet den Sammelzahler (DKB neuer Stil)',
        () {
      // Seit Mai schreiben DKB/Weisse Arena die Rechnungsnummer statt der
      // Betriebsnummer: «01.05.2026 2026-04-0505».
      final g = CamtTransaction(
        amount: 74.60,
        currency: 'CHF',
        isCredit: true,
        bookingDate: DateTime(2026, 5, 12),
        partyName: 'Davos Klosters Bergbahnen AG',
        remittanceInfo: '01.05.2026 2026-04-0505',
        txKey: 'tx-dkb-rn',
      );
      final rMitNr = Rechnung(
        id: 'r1',
        userId: 'u',
        rechnungsnummer: '2026-04-0505',
        rechnungstyp: 'kundenrechnung',
        betriebId: 'b1',
        rechnungsdatum: DateTime(2026, 4, 4),
        faelligkeitsdatum: DateTime(2026, 5, 4),
        betragNetto: 74.60,
        mwstBetrag: 0,
        betragBrutto: 74.60,
        zahlungsstatus: 'offen',
      );
      final r = ForderungsAbgleichService.abgleich(
        gutschriften: [g],
        offeneForderungen: [rMitNr, _rg('r2', 'b2', 55.0)],
        betriebe: betriebe,
      );
      expect(r.manuell.single.betriebId, 'b1');
      expect(r.manuell.single.gutschriften.single.txKey, 'tx-dkb-rn');
    });
  });

  group('Treffer-Grund (Anzeige zur Kontrolle)', () {
    test('QR-Referenz-Treffer trägt Grund "QR-Referenz"', () {
      final gut = _gutMitRef(100.00, 'Wildfremd AG', 'RF18539007547034');
      final rg = _rgMitRef('r1', 'b1', 100.00, 'RF18539007547034');
      final erg = ForderungsAbgleichService.abgleich(
        gutschriften: [gut],
        offeneForderungen: [rg],
        betriebe: [
          {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': ''},
        ],
      );
      expect(erg.auto.single.grund, 'QR-Referenz');
    });

    test('exakter Zahlername trägt Grund "Zahlername exakt · Betrag passt"', () {
      final r = ForderungsAbgleichService.abgleich(
        gutschriften: [_gut(67.85, 'Hotel Alpina')],
        offeneForderungen: [_rg('r1', 'b1', 67.85)],
        betriebe: betriebe,
      );
      expect(r.auto.single.grund, 'Zahlername exakt · Betrag passt');
    });

    test('Alias-Treffer trägt Grund "Zahler-Alias · Betrag passt"', () {
      final r = ForderungsAbgleichService.abgleich(
        gutschriften: [_gut(100.00, 'Znueni Beiz')],
        offeneForderungen: [_rg('r1', 'b1', 100.00)],
        betriebe: [
          {'id': 'b1', 'name': 'Hotel Alpina', 'aliase': 'znueni beiz'},
        ],
      );
      expect(r.auto.single.grund, 'Zahler-Alias · Betrag passt');
    });
  });
}
