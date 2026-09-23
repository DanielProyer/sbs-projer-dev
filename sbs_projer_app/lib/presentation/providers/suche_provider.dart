import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';
import 'package:sbs_projer_app/core/util/suche.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/core/util/betrieb_anzeige.dart';

/// Die Listen, in denen gesucht wird — alle ohnehin app-weit geladen.
///
/// Heineken-Monatsrechnungen bleiben draussen: eine pro Monat, über den
/// Reiter schneller gefunden als über die Suche (Spec, Abschnitt 2).
final suchEingabeProvider = Provider<SuchEingabe>((ref) {
  final betriebe = ref.watch(betriebeProvider);
  final kontakte = ref.watch(kontakteProvider).valueOrNull ?? const [];
  final rechnungen = ref.watch(rechnungenProvider);

  // «Name, Ort» neben Personen und Rechnungen — gleichnamige Betriebe.
  final namen = <String, String>{
    for (final b in betriebe)
      if (b.serverId != null) b.serverId!: betriebMitOrt(b.name, b.ort),
  };

  final bereiche = <SuchBereich>[];
  final indexVonZiel = <String, int>{};
  void neu(SuchBereich b) {
    // Mehr verweist auf die Bereichsseiten, die Bereichsseiten auf die
    // Screens — dasselbe Ziel soll nur einmal als Zeile erscheinen. Die
    // Stichwörter beider Fundstellen zusammenführen statt die zweiten zu
    // verwerfen: Mehr trägt oft einen anderen Titel/Untertitel als die
    // Bereichsseite, aber beide sollen über ihre Stichwörter treffen.
    final vorhandenerIndex = indexVonZiel[b.ziel];
    if (vorhandenerIndex == null) {
      indexVonZiel[b.ziel] = bereiche.length;
      bereiche.add(b);
      return;
    }
    final vorhanden = bereiche[vorhandenerIndex];
    bereiche[vorhandenerIndex] = (
      titel: vorhanden.titel,
      untertitel: vorhanden.untertitel,
      gruppe: vorhanden.gruppe,
      ziel: vorhanden.ziel,
      stichwoerter: [...vorhanden.stichwoerter, ...b.stichwoerter],
    );
  }

  for (final z in NavZiel.values) {
    neu((
      titel: navLabel(z),
      untertitel: null,
      gruppe: 'Leiste',
      ziel: navPfad(z),
      stichwoerter: const <String>[],
    ));
  }
  for (final e in kSuchZusatzZiele) {
    neu((
      titel: e.titel,
      untertitel: e.untertitel,
      gruppe: 'Einsätze',
      ziel: e.ziel,
      stichwoerter: e.stichwoerter,
    ));
  }
  for (final b in kAlleBereiche) {
    for (final g in b.gruppen) {
      for (final e in g.eintraege) {
        neu((
          titel: e.titel,
          untertitel: e.untertitel,
          gruppe: b.id == 'mehr' ? (g.titel ?? b.titel) : b.titel,
          ziel: e.ziel,
          stichwoerter: e.stichwoerter,
        ));
      }
    }
  }

  return SuchEingabe(
    betriebe: [
      for (final b in betriebe)
        if (b.serverId != null)
          (
            id: b.routeId,
            name: b.name,
            ort: b.ort,
            betriebNr: b.betriebNr,
            status: b.status,
          ),
    ],
    personen: [
      for (final k in kontakte)
        if (k.serverId != null)
          (
            id: k.routeId,
            vorname: k.vorname,
            nachname: k.nachname,
            telefon: k.telefon,
            betriebName: k.betriebId == null ? null : namen[k.betriebId],
          ),
    ],
    rechnungen: [
      for (final r in rechnungen)
        if (r.rechnungstyp != 'heineken_monat')
          (
            id: r.id,
            nummer: r.rechnungsnummer,
            betriebName: r.betriebId == null ? null : namen[r.betriebId],
            datum: r.rechnungsdatum,
            brutto: r.betragBrutto,
            zahlungsstatus: r.zahlungsstatus,
          ),
    ],
    bereiche: bereiche,
  );
});
