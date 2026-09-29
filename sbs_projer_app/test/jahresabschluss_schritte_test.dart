import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/jahresabschluss_schritte.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_regeln.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

Pruefbefund befund(
  String id,
  PruefStatus s, {
  String ist = '',
  String soll = '',
  String hinweis = '',
}) => Pruefbefund(
  regelId: id,
  gruppe: 'G',
  status: s,
  titel: id,
  ist: ist,
  soll: soll,
  hinweis: hinweis,
);

AbschreibungLauf lauf(List<int> jahrgaenge, int anzahl, double brutto) =>
    AbschreibungLauf(
      id: 'l$jahrgaenge',
      geschaeftsjahr: 2025,
      jahrgaenge: jahrgaenge,
      buchungsdatum: DateTime(2025, 12, 31),
      mwstJahr: 2025,
      mwstQuartal: 4,
      anzahl: anzahl,
      netto: brutto,
      mwst: 0,
      brutto: brutto,
      status: 'gebucht',
      ruecknahmeMoeglich: true,
    );

Dokument dok(
  String typ, {
  int jahr = 2025,
  DateTime? erstellt,
  String titel = 'JR',
  double? betrag,
}) => Dokument(
  id: '$typ$erstellt$titel',
  userId: 'u',
  bereich: 'steuern',
  typ: typ,
  jahr: jahr,
  dokumentDatum: DateTime(jahr, 12, 31),
  betrag: betrag,
  titel: titel,
  dateiname: 'x.pdf',
  dateityp: 'application/pdf',
  storagePfad: 'p',
  createdAt: erstellt,
);

/// Die Fassung 1 aus dem Beilage-Skript, wie sie seit 08.09.2026 im Dossier
/// liegt (ASCII-Bindestrich, Betrag ohne Apostroph, `betrag` leer).
Dokument skriptFassung() => dok(
  'jahresrechnung',
  erstellt: DateTime(2026, 9, 8),
  titel:
      'Jahresrechnung 2025 - Bilanz und Erfolgsrechnung mit Vorjahr, Anhang '
      'OR 959c, Beilage zur Steuererklaerung (Gewinn 20890.22, EK 75950.93)',
);

/// Die eingereichten Unterlagen 2019–2024: Bilanz und ER getrennt, Typ
/// `jahresrechnung`, aber keine Fassung der App.
Dokument fremd(int jahr, String titel) =>
    dok('jahresrechnung', jahr: jahr, erstellt: DateTime(2026, 9, 2), titel: titel);

void main() {
  final heute = DateTime(2026, 9, 29);

  List<JahresabschlussSchritt> schritte({
    List<Pruefbefund>? befunde,
    List<AbschreibungLauf> laeufe = const [],
    List<Dokument> dokumente = const [],
    Steuerjahr? steuerjahr,
    Dossier? dossier,
    int jahr = 2025,
    double? gewinn,
  }) => jahresabschlussSchritte(
    jahr: jahr,
    heute: heute,
    gewinnAktuell: gewinn,
    befunde: befunde ??
        [
          befund(kRegelVerjaehrt, PruefStatus.rot, ist: "76 Rechnungen · 7'216.30"),
          befund(kRegelDelkredere, PruefStatus.gelb, ist: '5629.38', soll: '5267.60', hinweis: 'Auf 5 % nachführen.'),
          befund(kRegelRueckstellung, PruefStatus.gruen, ist: '4000.00'),
          befund('bank_camt', PruefStatus.gelb),
        ],
    laeufe: laeufe,
    dokumente: dokumente,
    steuerjahr: steuerjahr,
    dossier: dossier,
  );

  test('sechs Schritte in fester Reihenfolge', () {
    expect(schritte().map((s) => s.titel).toList(), [
      'Abschlussprüfung',
      'Verjährte Jahrgänge abschreiben',
      'Delkredere 5 %',
      'Steuerrückstellung',
      'Jahresrechnung',
      'Steuererklärung',
    ]);
    expect(schritte().map((s) => s.nr).toList(), [1, 2, 3, 4, 5, 6]);
  });

  test('Regel-Ids gibt es in abschluss_regeln wirklich', () {
    final ids = alleAbschlussRegeln().map((r) => r.id).toSet();
    expect(ids, containsAll([kRegelVerjaehrt, kRegelDelkredere, kRegelRueckstellung]));
  });

  test('Prüfung: rot zählt, grün erst ohne rote Befunde', () {
    final s = schritte();
    expect(s[0].status, PruefStatus.rot);
    expect(s[0].ist, '1 rot · 2 gelb');
    final ohneRot = schritte(befunde: [befund('x', PruefStatus.gelb)]);
    expect(ohneRot[0].status, PruefStatus.gruen);
  });

  test('Abschreibung: Status aus dem Befund, Ist aus den Läufen', () {
    final s = schritte(laeufe: [lauf([2019], 29, 2235.90)]);
    expect(s[1].status, PruefStatus.rot);
    expect(s[1].ist, "Jahrgang 2019 · 29 Rechnungen · 2'235.90");
    expect(s[1].hinweis, contains("76 Rechnungen · 7'216.30"));
    final zwei = schritte(laeufe: [lauf([2020], 76, 7216.30), lauf([2019], 29, 2235.90)]);
    expect(zwei[1].ist, "Jahrgänge 2019, 2020 · 105 Rechnungen · 9'452.20");
    expect(schritte()[1].ist, 'kein Lauf');
  });

  test('Delkredere und Rückstellung übernehmen Ist/Soll der Prüfung', () {
    final s = schritte();
    expect(s[2].status, PruefStatus.gelb);
    expect(s[2].ist, 'Ist 5629.38 · Soll 5267.60');
    expect(s[2].hinweis, 'Auf 5 % nachführen.');
    expect(s[3].status, PruefStatus.gruen);
    expect(s[3].ist, '4000.00');
  });

  test('fehlender Befund bleibt gelb, nie still grün', () {
    final s = schritte(befunde: const []);
    expect(s[1].status, PruefStatus.gelb);
    expect(s[2].status, PruefStatus.gelb);
    expect(s[3].status, PruefStatus.gelb);
  });

  group('Jahresrechnung (Schritt 5)', () {
    final gruen = [
      befund(kRegelVerjaehrt, PruefStatus.gruen),
      befund(kRegelDelkredere, PruefStatus.gruen),
      befund(kRegelRueckstellung, PruefStatus.gruen),
    ];
    final fassung2 = dok(
      'jahresrechnung',
      erstellt: DateTime(2026, 10, 1),
      titel: "Jahresrechnung 2025 — Bilanz, Erfolgsrechnung, Anhang, "
          "Steuerbeilage (Gewinn 15'235.70, EK 70'296.41) — Fassung 2",
      betrag: 15235.70,
    );

    test('gelb ohne Dokument', () {
      expect(schritte()[4].status, PruefStatus.gelb);
      expect(schritte()[4].ist, 'noch nicht erzeugt');
    });

    test('grün mit der neuesten Fassung, wenn Zahlen und Vorschritte stimmen', () {
      final s = schritte(
        befunde: gruen,
        gewinn: 15235.70,
        dokumente: [
          skriptFassung(),
          fassung2,
          dok('jahresrechnung', jahr: 2024, erstellt: DateTime(2025, 11, 10)),
          dok('lohnausweis', erstellt: DateTime(2026, 9, 3)),
        ],
      );
      expect(s[4].status, PruefStatus.gruen);
      expect(s[4].ist, startsWith('2 Fassungen, neueste: Jahresrechnung 2025 —'));
      expect(s[4].ist, endsWith(' · 01.10.2026'));
      expect(
        s[4].knoepfe.map((k) => k.aktion),
        [SchrittAktion.vorschau, SchrittAktion.erzeugen],
      );
    });

    test('W1: ein roter Schritt 1–4 hält Schritt 5 auf gelb', () {
      // Standard-Befunde: Jahrgang verjährt ist rot.
      final s = schritte(gewinn: 15235.70, dokumente: [fassung2]);
      expect(s[4].status, PruefStatus.gelb);
      expect(s[4].hinweis, contains('Erst Schritte 1–4 bereinigen'));
    });

    test('W1: Gewinn seit der Fassung geändert → gelb mit beiden Zahlen', () {
      final s = schritte(befunde: gruen, gewinn: 15235.70, dokumente: [skriptFassung()]);
      expect(s[4].status, PruefStatus.gelb);
      expect(
        s[4].hinweis,
        contains("Zahlen seit dieser Fassung geändert (Fassung: 20'890.22, jetzt: 15'235.70)"),
      );
      // Innerhalb von 5 Rappen: keine Änderung.
      final gleich = schritte(befunde: gruen, gewinn: 20890.25, dokumente: [skriptFassung()]);
      expect(gleich[4].status, PruefStatus.gruen);
    });

    test('Betrag der Fassung hat Vorrang vor dem Titel', () {
      final d = dok(
        'jahresrechnung',
        erstellt: DateTime(2026, 10, 1),
        titel: 'Jahresrechnung 2025 (Gewinn 1.00)',
        betrag: 15235.70,
      );
      final s = schritte(befunde: gruen, gewinn: 15235.70, dokumente: [d]);
      expect(s[4].status, PruefStatus.gruen);
    });

    test('W2: im laufenden Jahr ist Erzeugen gesperrt, Vorschau nicht', () {
      final s = schritte(jahr: 2026, befunde: gruen);
      final knoepfe = {for (final k in s[4].knoepfe) k.aktion: k.aktiv};
      expect(knoepfe[SchrittAktion.vorschau], isTrue);
      expect(knoepfe[SchrittAktion.erzeugen], isFalse);
      expect(s[4].hinweis, contains('Jahr läuft noch'));
      final vorjahr = schritte(befunde: gruen);
      expect(vorjahr[4].knoepfe.every((k) => k.aktiv), isTrue);
    });

    test('Fremdunterlagen (Bilanz/ER getrennt) sind keine Fassung', () {
      final dokumente = [
        fremd(2024, 'Bilanz 31.12.2024 (eingereicht 10.11.2025)'),
        fremd(2024, 'Erfolgsrechnung 2024 (eingereicht 10.11.2025)'),
      ];
      expect(fassungenVon(2024, dokumente), isEmpty);
      expect(naechsteFassung(2024, dokumente), 1);
      // Eingereicht: die alte Ablage genügt, Schritt 5 ist erledigt.
      final s = jahresabschlussSchritte(
        jahr: 2024,
        heute: heute,
        befunde: gruen,
        laeufe: const [],
        dokumente: dokumente,
        steuerjahr: const Steuerjahr(jahr: 2024, status: 'veranlagt'),
      );
      expect(s[4].status, PruefStatus.gruen);
      expect(s[4].ist, contains('2 ältere Unterlagen'));
    });
  });

  group('K6: Fassungsnummer', () {
    test('Skript-Fassung ohne Zusatz zählt als 1, danach 2', () {
      expect(naechsteFassung(2025, [skriptFassung()]), 2);
      expect(fassungenVon(2025, [skriptFassung()]).single.nr, 1);
      expect(fassungenVon(2025, [skriptFassung()]).single.gewinn, 20890.22);
    });

    test('höchste «Fassung n» + 1, nicht die Anzahl', () {
      final d = [
        skriptFassung(),
        dok('jahresrechnung', erstellt: DateTime(2026, 10, 2), titel: 'Jahresrechnung 2025 — … — Fassung 3'),
        fremd(2025, 'Bilanz 31.12.2025 (Entwurf)'),
      ];
      expect(naechsteFassung(2025, d), 4);
      expect(fassungenVon(2025, d).first.nr, 3);
    });

    test('ohne Dossier: Fassung 1', () {
      expect(naechsteFassung(2025, const []), 1);
    });
  });

  test('offeneVorschritte nennt die roten Schritte 1–4', () {
    expect(offeneVorschritte(schritte()), [
      'Abschlussprüfung',
      'Verjährte Jahrgänge abschreiben',
    ]);
  });

  test('Steuererklärung: offen gelb mit Dossier und Frist, eingereicht grün', () {
    final offen = schritte(
      steuerjahr: const Steuerjahr(jahr: 2025),
      dossier: const Dossier(
        total: 6,
        vorhanden: 1,
        fehlend: ['lohnausweis', 'zinsausweis', 'steuererklaerung', 'veranlagung:bund', 'veranlagung:kanton'],
      ),
    )[5];
    expect(offen.status, PruefStatus.gelb);
    expect(offen.ist, 'Offen · Dossier 1/6');
    expect(offen.hinweis, contains('Fehlt: Lohnausweis, Zins-/Kapitalausweis.'));
    expect(offen.hinweis, contains('30.09.2026'));
    // Veranlagungen kommen erst nach der Einreichung — nicht als «fehlt».
    expect(offen.hinweis, isNot(contains('Veranlagung')));

    final ein = schritte(
      steuerjahr: Steuerjahr(jahr: 2025, status: 'eingereicht', eingereichtAm: DateTime(2026, 9, 30)),
    )[5];
    expect(ein.status, PruefStatus.gruen);
    expect(ein.ist, 'Eingereicht am 30.09.2026');
  });

  test('laufendes Jahr: Steuererklärung sagt «Jahr läuft noch»', () {
    final s = schritte(jahr: 2026)[5];
    expect(s.hinweis, contains('Jahr läuft noch'));
  });

  group('Ablage', () {
    const k = JahresrechnungKennzahlen(
      jahr: 2025,
      gewinn: 15235.70,
      gewinnvortrag: 35060.71,
      stammkapital: 20000,
      debitoren: 0,
      delkredere: 0,
      rueckstellung: 0,
      bank: 0,
      kasse: 0,
      aufrechnungenAuto: 120,
      aufrechnungenManuell: 200,
    );

    test('Titel und Dateiname, ab Fassung 2 nummeriert', () {
      expect(
        jahresrechnungTitel(k),
        "Jahresrechnung 2025 — Bilanz, Erfolgsrechnung, Anhang, Steuerbeilage "
        "(Gewinn 15'235.70, EK 70'296.41)",
      );
      expect(jahresrechnungTitel(k, fassung: 2), endsWith(' — Fassung 2'));
      expect(jahresrechnungDateiname(2025), 'Jahresrechnung_2025.pdf');
      expect(
        jahresrechnungDateiname(2025, fassung: 3),
        'Jahresrechnung_2025_Fassung3.pdf',
      );
    });

    test('Steuerjahr: leere Felder füllen, gesetzte nie überschreiben', () {
      final neu = steuerjahrAbgleich(null, k);
      expect(neu.neu!.jahr, 2025);
      expect(neu.neu!.status, 'offen');
      expect(neu.neu!.steuerbarerGewinn, 15555.70);
      expect(neu.neu!.steuerbaresKapital, 70296.41);
      expect(neu.abweichungen, isEmpty);

      final halb = steuerjahrAbgleich(
        const Steuerjahr(jahr: 2025, status: 'eingereicht', steuerbarerGewinn: 15000),
        k,
      );
      expect(halb.neu!.steuerbarerGewinn, 15000);
      expect(halb.neu!.steuerbaresKapital, 70296.41);
      expect(halb.neu!.status, 'eingereicht');
      expect(halb.abweichungen, ["Gewinn 15'000.00 (neu 15'555.70)"]);

      final voll = steuerjahrAbgleich(
        const Steuerjahr(jahr: 2025, steuerbarerGewinn: 15555.70, steuerbaresKapital: 2),
        k,
      );
      expect(voll.neu, isNull);
      expect(voll.abweichungen, ["Kapital 2.00 (neu 70'296.41)"]);
    });

    test('W2: Meldung, wenn das Steuerjahr andere Werte behält', () {
      expect(steuerjahrHinweis(const []), isNull);
      expect(
        steuerjahrHinweis(["Gewinn 15'000.00 (neu 15'555.70)", 'Kapital 2.00 (neu 3.00)']),
        "Steuerjahr behält Gewinn 15'000.00 (neu 15'555.70), Kapital 2.00 "
        '(neu 3.00) — im Steuerjahr anpassen',
      );
    });
  });
}
