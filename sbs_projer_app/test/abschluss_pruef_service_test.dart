import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

BuchungSaldo b(
  int soll,
  int haben,
  double betrag,
  DateTime datum, {
  int? mwstKonto,
  double mwst = 0,
}) => BuchungSaldo(
  sollKonto: soll,
  habenKonto: haben,
  betrag: betrag,
  datum: datum,
  storniert: false,
  mwstKonto: mwstKonto,
  betragNetto: betrag - mwst,
  mwstBetrag: mwst,
);

final d = DateTime(2025, 6, 30);

AbschlussKontext k({
  int jahr = 2025,
  List<BuchungSaldo> buchungen = const [],
  List<KontoInfo> konten = const [],
  List<CamtDateiInfo> camt = const [],
  List<OffeneRechnungInfo> rechnungen = const [],
  int steuerbuchungenOhneJahr = 0,
  Set<String> dokumentTypen = const {},
  String steuerjahrStatus = 'offen',
  Set<String> offeneRechnungenMitZahlung = const {},
}) => AbschlussKontext(
  jahr: jahr,
  heute: DateTime(2026, 9, 2),
  buchungen: buchungen,
  konten: konten,
  camtDateien: camt,
  offeneRechnungen: rechnungen,
  steuerbuchungenOhneJahr: steuerbuchungenOhneJahr,
  dokumentTypen: dokumentTypen,
  steuerjahrStatus: steuerjahrStatus,
  offeneRechnungenMitZahlung: offeneRechnungenMitZahlung,
);

Pruefbefund f(List<Pruefbefund> l, String id) =>
    l.firstWhere((x) => x.regelId == id);

void main() {
  test(
    'Bank = camt-Schlusssaldo → grün; Differenz → rot; ohne camt → gelb',
    () {
      final bu = [b(1020, 2800, 12202.73, d)];
      final camt = [
        CamtDateiInfo(
          von: DateTime(2025, 1, 1),
          bis: DateTime(2025, 12, 31),
          anfangssaldo: 0,
          schlusssaldo: 12202.73,
        ),
      ];
      expect(
        f(
          AbschlussPruefService.pruefe(k(buchungen: bu, camt: camt)),
          'bank_camt',
        ).status,
        PruefStatus.gruen,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(
            k(
              buchungen: bu,
              camt: [
                CamtDateiInfo(
                  von: DateTime(2025, 1, 1),
                  bis: DateTime(2025, 12, 31),
                  anfangssaldo: 0,
                  schlusssaldo: 12000,
                ),
              ],
            ),
          ),
          'bank_camt',
        ).status,
        PruefStatus.rot,
      );
      expect(
        f(AbschlussPruefService.pruefe(k(buchungen: bu)), 'bank_camt').status,
        PruefStatus.gelb,
      );
    },
  );
  test(
    'camt-Lückenkette: lückenlos grün, Tageslücke gelb, Saldosprung rot',
    () {
      final a = CamtDateiInfo(
        von: DateTime(2025, 1, 1),
        bis: DateTime(2025, 3, 31),
        anfangssaldo: 0,
        schlusssaldo: 100,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(
            k(
              camt: [
                a,
                CamtDateiInfo(
                  von: DateTime(2025, 4, 1),
                  bis: DateTime(2025, 6, 30),
                  anfangssaldo: 100,
                  schlusssaldo: 200,
                ),
              ],
            ),
          ),
          'camt_kette',
        ).status,
        PruefStatus.gruen,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(
            k(
              camt: [
                a,
                CamtDateiInfo(
                  von: DateTime(2025, 4, 3),
                  bis: DateTime(2025, 6, 30),
                  anfangssaldo: 100,
                  schlusssaldo: 200,
                ),
              ],
            ),
          ),
          'camt_kette',
        ).status,
        PruefStatus.gelb,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(
            k(
              camt: [
                a,
                CamtDateiInfo(
                  von: DateTime(2025, 4, 1),
                  bis: DateTime(2025, 6, 30),
                  anfangssaldo: 90,
                  schlusssaldo: 200,
                ),
              ],
            ),
          ),
          'camt_kette',
        ).status,
        PruefStatus.rot,
      );
    },
  );
  test('Kasse: negativ rot, > 10000 gelb, sonst grün', () {
    expect(
      f(
        AbschlussPruefService.pruefe(k(buchungen: [b(6200, 1000, 50, d)])),
        'kasse',
      ).status,
      PruefStatus.rot,
    );
    expect(
      f(
        AbschlussPruefService.pruefe(k(buchungen: [b(1000, 3400, 12000, d)])),
        'kasse',
      ).status,
      PruefStatus.gelb,
    );
    expect(
      f(
        AbschlussPruefService.pruefe(k(buchungen: [b(1000, 3400, 500, d)])),
        'kasse',
      ).status,
      PruefStatus.gruen,
    );
  });
  test('MWST-Konten nach Saldierung 0 → grün, Rest → rot', () {
    expect(
      f(
        AbschlussPruefService.pruefe(
          k(
            buchungen: [
              b(1100, 3400, 108.1, d, mwstKonto: 2200, mwst: 8.1),
              b(2200, 2202, 8.1, d),
            ],
          ),
        ),
        'mwst_saldiert',
      ).status,
      PruefStatus.gruen,
    );
    expect(
      f(
        AbschlussPruefService.pruefe(
          k(buchungen: [b(1100, 3400, 108.1, d, mwstKonto: 2200, mwst: 8.1)]),
        ),
        'mwst_saldiert',
      ).status,
      PruefStatus.rot,
    );
  });
  test('2202 im Soll → gelb, im Haben → grün', () {
    expect(
      f(
        AbschlussPruefService.pruefe(k(buchungen: [b(2202, 1020, 100, d)])),
        'mwst_2202',
      ).status,
      PruefStatus.gelb,
    );
    expect(
      f(
        AbschlussPruefService.pruefe(k(buchungen: [b(2200, 2202, 100, d)])),
        'mwst_2202',
      ).status,
      PruefStatus.gruen,
    );
  });
  test(
    'Offene Rechnungen älter als 5 Jahre → rot mit Anzahl/Summe, jüngere → grün',
    () {
      final r = f(
        AbschlussPruefService.pruefe(
          k(
            rechnungen: [
              OffeneRechnungInfo(
                id: 'r1',
                datum: DateTime(2020, 5, 1),
                brutto: 67.85,
              ),
            ],
          ),
        ),
        'debitoren_verjaehrt',
      );
      expect(r.status, PruefStatus.rot);
      expect(r.ist, contains('1'));
      expect(r.ist, contains('67.85'));
      expect(
        f(
          AbschlussPruefService.pruefe(
            k(
              rechnungen: [
                OffeneRechnungInfo(
                  id: 'r2',
                  datum: DateTime(2021, 5, 1),
                  brutto: 67.85,
                ),
              ],
            ),
          ),
          'debitoren_verjaehrt',
        ).status,
        PruefStatus.gruen,
      );
    },
  );
  test(
    'Delkredere 5 %: passt grün, fehlt rot, weicht ab gelb, keine Debitoren grün',
    () {
      final deb = b(1100, 3400, 10000, d);
      expect(
        f(
          AbschlussPruefService.pruefe(
            k(buchungen: [deb, b(3805, 1109, 500, d)]),
          ),
          'delkredere',
        ).status,
        PruefStatus.gruen,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(k(buchungen: [deb])),
          'delkredere',
        ).status,
        PruefStatus.rot,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(
            k(buchungen: [deb, b(3805, 1109, 300, d)]),
          ),
          'delkredere',
        ).status,
        PruefStatus.gelb,
      );
      expect(
        f(AbschlussPruefService.pruefe(k()), 'delkredere').status,
        PruefStatus.gruen,
      );
    },
  );
  test('Offene Rechnungen mit verknüpfter Zahlung → gelb', () {
    expect(
      f(
        AbschlussPruefService.pruefe(k(offeneRechnungenMitZahlung: {'r9'})),
        'debitoren_status',
      ).status,
      PruefStatus.gelb,
    );
    expect(
      f(AbschlussPruefService.pruefe(k()), 'debitoren_status').status,
      PruefStatus.gruen,
    );
  });
  test(
    'Steuerrückstellung: abgeschlossenes Jahr ohne 2208 → rot, laufendes → gelb, vorhanden → grün',
    () {
      expect(
        f(AbschlussPruefService.pruefe(k()), 'rueckstellung').status,
        PruefStatus.rot,
      );
      expect(
        f(AbschlussPruefService.pruefe(k(jahr: 2026)), 'rueckstellung').status,
        PruefStatus.gelb,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(k(buchungen: [b(8900, 2208, 4000, d)])),
          'rueckstellung',
        ).status,
        PruefStatus.gruen,
      );
    },
  );
  test(
    'Negative Salden: 1109 ausgenommen (grün), Aktiv < 0 rot, Passiv im Soll rot',
    () {
      expect(
        f(
          AbschlussPruefService.pruefe(k(buchungen: [b(3805, 1109, 5, d)])),
          'negative_salden',
        ).status,
        PruefStatus.gruen,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(k(buchungen: [b(6200, 1020, 5, d)])),
          'negative_salden',
        ).status,
        PruefStatus.rot,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(k(buchungen: [b(2000, 1020, 5, d)])),
          'negative_salden',
        ).status,
        PruefStatus.rot,
      );
    },
  );
  test('Lohnkonten im Soll → gelb', () {
    expect(
      f(
        AbschlussPruefService.pruefe(k(buchungen: [b(2271, 1020, 5, d)])),
        'lohnkonten',
      ).status,
      PruefStatus.gelb,
    );
    expect(
      f(
        AbschlussPruefService.pruefe(k(buchungen: [b(5000, 2271, 5, d)])),
        'lohnkonten',
      ).status,
      PruefStatus.gruen,
    );
  });
  test('FEHLER-Konto mit Saldo → rot', () {
    final konten = [
      const KontoInfo(
        kontonummer: 8090,
        bezeichnung: 'FEHLER alt',
        kategorie: 'x',
      ),
    ];
    expect(
      f(
        AbschlussPruefService.pruefe(
          k(buchungen: [b(8090, 1020, 5, d)], konten: konten),
        ),
        'fehler_konten',
      ).status,
      PruefStatus.rot,
    );
    expect(
      f(
        AbschlussPruefService.pruefe(k(konten: konten)),
        'fehler_konten',
      ).status,
      PruefStatus.gruen,
    );
  });
  test(
    'Steuerbuchungen ohne Jahr → gelb; Erklärung fehlt → gelb, vorhanden → grün, laufendes Jahr → grün',
    () {
      expect(
        f(
          AbschlussPruefService.pruefe(k(steuerbuchungenOhneJahr: 3)),
          'steuer_zuordnung',
        ).status,
        PruefStatus.gelb,
      );
      expect(
        f(AbschlussPruefService.pruefe(k()), 'steuererklaerung').status,
        PruefStatus.gelb,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(k(dokumentTypen: {'steuererklaerung'})),
          'steuererklaerung',
        ).status,
        PruefStatus.gruen,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(k(steuerjahrStatus: 'ermessen')),
          'steuererklaerung',
        ).status,
        PruefStatus.gruen,
      );
      expect(
        f(
          AbschlussPruefService.pruefe(k(jahr: 2026)),
          'steuererklaerung',
        ).status,
        PruefStatus.gruen,
      );
    },
  );
  test('Stichtag und Quartalsende', () {
    expect(k(jahr: 2025).stichtag, DateTime(2025, 12, 31));
    expect(k(jahr: 2026).stichtag, DateTime(2026, 9, 2));
    expect(k(jahr: 2025).letztesQuartalsende(), DateTime(2025, 12, 31));
    expect(k(jahr: 2026).letztesQuartalsende(), DateTime(2026, 6, 30));
  });
  test('Sortierung: rot vor gelb vor grün; 14 Regeln', () {
    final l = AbschlussPruefService.pruefe(k(buchungen: [b(6200, 1020, 5, d)]));
    expect(l.length, 14);
    expect(l.first.status, PruefStatus.rot);
    expect(l.last.status, PruefStatus.gruen);
  });
}
