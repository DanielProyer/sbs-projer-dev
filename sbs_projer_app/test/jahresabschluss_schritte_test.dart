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

Dokument dok(String typ, {int jahr = 2025, DateTime? erstellt, String titel = 'JR'}) =>
    Dokument(
      id: '$typ$erstellt',
      userId: 'u',
      bereich: 'steuern',
      typ: typ,
      jahr: jahr,
      dokumentDatum: DateTime(jahr, 12, 31),
      titel: titel,
      dateiname: 'x.pdf',
      dateityp: 'application/pdf',
      storagePfad: 'p',
      createdAt: erstellt,
    );

void main() {
  final heute = DateTime(2026, 9, 29);

  List<JahresabschlussSchritt> schritte({
    List<Pruefbefund>? befunde,
    List<AbschreibungLauf> laeufe = const [],
    List<Dokument> dokumente = const [],
    Steuerjahr? steuerjahr,
    Dossier? dossier,
    int jahr = 2025,
  }) => jahresabschlussSchritte(
    jahr: jahr,
    heute: heute,
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

  test('Jahresrechnung: gelb ohne Dokument, grün mit der neuesten Fassung', () {
    expect(schritte()[4].status, PruefStatus.gelb);
    expect(schritte()[4].ist, 'noch nicht erzeugt');
    final s = schritte(dokumente: [
      dok('jahresrechnung', erstellt: DateTime(2026, 9, 2), titel: 'Fassung 1'),
      dok('jahresrechnung', erstellt: DateTime(2026, 10, 1), titel: 'Fassung 2'),
      dok('jahresrechnung', jahr: 2024, erstellt: DateTime(2025, 11, 10)),
      dok('lohnausweis', erstellt: DateTime(2026, 9, 3)),
    ]);
    expect(s[4].status, PruefStatus.gruen);
    expect(s[4].ist, '2 Fassungen, neueste: Fassung 2 · 01.10.2026');
    expect(
      s[4].knoepfe.map((k) => k.aktion),
      [SchrittAktion.vorschau, SchrittAktion.erzeugen],
    );
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
      final neu = steuerjahrVorbefuellt(null, k)!;
      expect(neu.jahr, 2025);
      expect(neu.status, 'offen');
      expect(neu.steuerbarerGewinn, 15555.70);
      expect(neu.steuerbaresKapital, 70296.41);

      final halb = steuerjahrVorbefuellt(
        const Steuerjahr(jahr: 2025, status: 'eingereicht', steuerbarerGewinn: 15000),
        k,
      )!;
      expect(halb.steuerbarerGewinn, 15000);
      expect(halb.steuerbaresKapital, 70296.41);
      expect(halb.status, 'eingereicht');

      expect(
        steuerjahrVorbefuellt(
          const Steuerjahr(jahr: 2025, steuerbarerGewinn: 1, steuerbaresKapital: 2),
          k,
        ),
        isNull,
      );
    });
  });
}
