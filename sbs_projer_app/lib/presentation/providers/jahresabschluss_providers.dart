import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/jahresabschluss_schritte.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/presentation/providers/abschreibung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/konto_providers.dart';
import 'package:sbs_projer_app/presentation/providers/steuern_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

/// Alles, was der geführte Jahresabschluss eines Jahrs zeigt und für die
/// Jahresrechnung braucht.
class JahresabschlussLage {
  final int jahr;
  final List<Pruefbefund> befunde;
  final List<AbschreibungLauf> laeufe;

  /// Steuer-Dokumente des Jahrs (Bereich `steuern`).
  final List<Dokument> dokumente;
  final Steuerjahr? steuerjahr;
  final Dossier dossier;

  /// Kennzahlen ohne Dialog-Eingaben (keine manuellen Aufrechnungen).
  final JahresrechnungKennzahlen kennzahlen;
  final BilanzDaten bilanz, bilanzVorjahr;
  final ErfolgsrechnungDaten er, erVorjahr;
  final ErKontenAufstellung konten, kontenVorjahr;

  const JahresabschlussLage({
    required this.jahr,
    required this.befunde,
    required this.laeufe,
    required this.dokumente,
    required this.steuerjahr,
    required this.dossier,
    required this.kennzahlen,
    required this.bilanz,
    required this.bilanzVorjahr,
    required this.er,
    required this.erVorjahr,
    required this.konten,
    required this.kontenVorjahr,
  });

  List<Dokument> get jahresrechnungen => jahresrechnungenVon(jahr, dokumente);

  List<JahresabschlussSchritt> schritte(DateTime heute) =>
      jahresabschlussSchritte(
        jahr: jahr,
        heute: heute,
        befunde: befunde,
        laeufe: laeufe,
        dokumente: dokumente,
        steuerjahr: steuerjahr,
        dossier: dossier,
      );
}

/// Lage des Jahresabschlusses [jahr].
///
/// Bilanz, Erfolgsrechnung und Saldi entstehen aus dem laufenden
/// `buchungenStreamProvider` — wie `bilanzStichtagProvider` und
/// `erKontenAufstellungProvider`, aber mit EINEM Journal-Durchgang je
/// Stichtag und ohne deren je eigenen Konten-Download. Die Teilquellen sind
/// beobachtet: Bucht die Abschlussprüfung das Delkredere, legt der
/// Abschreibungsschritt einen Lauf an oder landet ein Dokument im Dossier,
/// rechnet die Liste neu, ohne dass jemand sie eigens anstossen muss.
///
/// `autoDispose`: Sonst rechnet jedes einmal gewählte Jahr bei jeder Buchung
/// mit (gleicher Grund wie bei `abschlussPruefungProvider`).
final jahresabschlussLageProvider = FutureProvider.autoDispose
    .family<JahresabschlussLage, int>((ref, jahr) async {
      // Alle Quellen vor dem ersten await beobachten — so hängt die Lage an
      // jeder, auch wenn eine davon später fertig wird.
      final buchungenF = ref.watch(buchungenStreamProvider.future);
      final kontenF = ref.watch(kontenStreamProvider.future);
      final befundeF = ref.watch(abschlussPruefungProvider(jahr).future);
      final laeufeF = ref.watch(abschreibungLaeufeProvider.future);
      final dokumenteF = ref.watch(steuerDokumenteProvider(jahr).future);
      final steuerjahreF = ref.watch(steuerjahreProvider.future);

      final (buchungen, konten, befunde, laeufe, dokumente, steuerjahre) =
          await (
            buchungenF,
            kontenF,
            befundeF,
            laeufeF,
            dokumenteF,
            steuerjahreF,
          ).wait;

      final saldoInput = toSaldoInput(buchungen);
      final infos = [
        for (final k in konten)
          KontoInfo(
            kontonummer: k.kontonummer,
            bezeichnung: k.bezeichnung,
            kategorie: k.kategorie ?? '—',
          ),
      ];
      final namen = {for (final k in konten) k.kontonummer: k.bezeichnung};
      final stichtag = DateTime(jahr, 12, 31);
      final stichtagVj = DateTime(jahr - 1, 12, 31);

      ErKontenAufstellung aufstellung(int j) {
        final roh = ErfolgsrechnungService.kontenAufstellung(
          saldoInput,
          von: DateTime(j, 1, 1),
          bis: DateTime(j, 12, 31),
        );
        return ErKontenAufstellung([
          for (final kl in roh.klassen)
            ErKlasse(kl.klasse, [
              for (final kt in kl.konten)
                kt.withBezeichnung(namen[kt.nr] ?? '—'),
            ]),
        ]);
      }

      ErfolgsrechnungDaten erfolg(int j) => ErfolgsrechnungService.berechne(
        saldoInput,
        von: DateTime(j, 1, 1),
        bis: DateTime(j, 12, 31),
      );

      Steuerjahr? steuerjahr;
      for (final s in steuerjahre) {
        if (s.jahr == jahr) steuerjahr = s;
      }

      return JahresabschlussLage(
        jahr: jahr,
        befunde: befunde,
        laeufe: laeufe,
        dokumente: dokumente,
        steuerjahr: steuerjahr,
        dossier: SteuerjahrRechner.dossier(
          jahr: jahr,
          heute: DateTime.now(),
          vorhanden: [for (final d in dokumente) (d.typ, d.kategorie)],
        ),
        kennzahlen: kennzahlenAus(
          jahr: jahr,
          saldiJahr: BilanzService.saldiPerStichtag(saldoInput, stichtag),
          saldiVorjahr: BilanzService.saldiPerStichtag(saldoInput, stichtagVj),
          laeufe: laeufe,
        ),
        bilanz: BilanzService.erstelle(saldoInput, infos, stichtag),
        bilanzVorjahr: BilanzService.erstelle(saldoInput, infos, stichtagVj),
        er: erfolg(jahr),
        erVorjahr: erfolg(jahr - 1),
        konten: aufstellung(jahr),
        kontenVorjahr: aufstellung(jahr - 1),
      );
    });
