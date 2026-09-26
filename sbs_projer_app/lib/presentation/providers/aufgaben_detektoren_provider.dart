import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/monats_pruef_provider.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/mahnlauf_provider.dart';
import 'package:sbs_projer_app/data/repositories/mahnfall_repository.dart';
import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/einsatz/einsatz_diktat_entwurf_speicher.dart';
import 'package:sbs_projer_app/services/storage/reinigung_entwurf_speicher.dart';

/// Ist ein Nutzer angemeldet? Im VM-Test ohne `Supabase.initialize()` wirft
/// `SupabaseService.currentUser` selbst — dort gilt: eingeloggt, die Provider
/// unter Test werden ohnehin per Override gespeist (B6).
bool _eingeloggt() {
  try {
    return SupabaseService.currentUser != null;
  } catch (_) {
    return true;
  }
}

/// Die Zeilen der Tabelle `aufgaben` (eigene, Snoozes, Marker) — eine
/// Abfrage, die Detektoren und die Liste teilen. Nach jeder Aktion
/// invalidieren.
final aufgabenZeilenProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  if (!_eingeloggt()) return const [];
  try {
    return await AufgabenRepository.alleZeilen();
  } catch (e) {
    debugPrint('[Aufgaben] Tabelle nicht ladbar: $e');
    return const [];
  }
});

/// Die sechs Detektoren (Heineken-Rechnung, MWST, Mahnlauf, Saisondaten,
/// fehlende Buchungen, Versandvermerk) — unverändert aus dem früheren
/// einzelnen Aufgaben-Provider (B6). Ohne Snooze: den wendet
/// `baueAufgabenListe` an.
/// Jeder Detektor ist einzeln abgesichert; einer, der fällt, leert nicht die
/// Liste.
final aufgabenDetektorenProvider = FutureProvider<List<Aufgabe>>((ref) async {
  if (!_eingeloggt()) return const [];
  final heute = DateTime.now();
  final client = SupabaseService.client;
  final zeilen = await ref.watch(aufgabenZeilenProvider.future);
  final marker = zeilen
      .where((z) => z['typ'] == 'marker' && z['key'] != null)
      .map((z) => z['key'] as String)
      .toSet();

  final detektoren = <Aufgabe>[];

  // a) Heineken — Rechnung des Vormonats gezielt abfragen.
  try {
    final vormonat = DateTime(heute.year, heute.month - 1, 1);
    final rows = await client
        .from('rechnungen')
        .select('zahlungsstatus')
        .eq('rechnungstyp', 'heineken_monat')
        .eq('heineken_monat', vormonat.toIso8601String().split('T').first)
        .limit(1);
    final a = heinekenAufgabe(
      heute: heute,
      rechnungExistiert: rows.isNotEmpty,
      rechnungOffen: rows.isNotEmpty && rows.first['zahlungsstatus'] == 'offen',
    );
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Heineken-Detektor: $e');
  }

  // b) MWST — alle unmarkierten der letzten 4 Quartale.
  try {
    detektoren.addAll(mwstAufgaben(heute: heute, markerKeys: marker));
  } catch (e) {
    debugPrint('[Aufgaben] MWST-Detektor: $e');
  }

  // c) Mahnlauf — eigener Provider (`mahnlaufAufgabeProvider`), damit ein
  //    Neuladen des Mahnlaufs nicht alle Detektoren hier neu rechnet.

  // d) Saisondaten — bestehender Tourenplan-Provider.
  try {
    final a = saisondatenAufgabe(ref.watch(saisonAnkerFehltProvider).length);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Saisondaten-Detektor: $e');
  }

  // d2) Saison-Angabe kaputt — Betrieb faellt dauerhaft aus dem Plan.
  try {
    final a = saisonLueckeAufgabe(ref.watch(saisonLueckenProvider).length);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Saisonluecken-Detektor: $e');
  }

  // e) Fehlende Ertragsbuchungen — dieselbe Quelle wie die Warnung in den
  //    Forderungen, damit beide nie auseinanderlaufen.
  try {
    final offen = await ref.watch(fehlendeBuchungenProvider.future);
    final a = fehlendeBuchungenAufgabe(offen.where((e) => !e.gesperrt).length);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Buchungs-Detektor: $e');
  }

  // f) Versandvermerk — Mail-Rechnungen, die auf «offen» stehen geblieben
  //    sind. Erst ab dem Folgetag: am Tag selbst kann der Versand noch
  //    ausstehen (Funkloch, Nachversand), das wäre nur Rauschen.
  //    Seit V9 zwei Abfragen statt bis zu 500: Mail-Reinigungen des Fensters
  //    einmal laden, der Abgleich Betrieb + Tag läuft in Dart
  //    (`zaehleVersandvermerke`).
  try {
    final grenze = heute.subtract(const Duration(days: 1));
    final ab = heute.subtract(const Duration(days: 60));
    final rows = await client
        .from('rechnungen')
        .select('id, betrieb_id, created_at')
        .eq('zahlungsstatus', 'offen')
        .neq('rechnungstyp', 'heineken_monat')
        .lt('created_at', grenze.toIso8601String())
        .gte('created_at', ab.toIso8601String())
        .limit(500);

    var verdaechtig = 0;
    if (rows.isNotEmpty) {
      // Nur solche, deren Reinigung wirklich per Mail abgerechnet wird —
      // «Tresen» und «bar» stehen zu Recht auf offen. Ein Tag Puffer vor
      // dem Fenster: created_at ist UTC, das Reinigungsdatum lokal.
      final reinigungen = await client
          .from('reinigungen')
          .select('betrieb_id, datum')
          .eq('zahlungsart', 'rechnung_mail')
          .gte(
            'datum',
            ab
                .subtract(const Duration(days: 1))
                .toIso8601String()
                .split('T')
                .first,
          )
          .order('datum')
          .order('id')
          // ~60 Zeilen im Fenster (26.09.2026); 1000 ist die PostgREST-Decke.
          .limit(1000);
      verdaechtig = zaehleVersandvermerke(
        rechnungen: rows,
        mailReinigungen: reinigungen,
      );
    }
    final a = versandvermerkAufgabe(verdaechtig);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Versandvermerk-Detektor: $e');
  }

  // f2) Reinigungen ohne Protokollfoto — nur ab dem Stichtag, ab dem der
  //     Upload sofort nach der Aufnahme läuft (T1). Heineken-Monteur-Einsätze
  //     haben kein Protokoll. `ist_heineken_monteur` ist nullable (Migration
  //     043: nur DEFAULT FALSE) — deshalb weder .neq() noch .eq(false)
  //     (NULL-Falle), sondern mitlesen und in Dart aussortieren.
  try {
    final rows = await client
        .from('reinigungen')
        .select('id, ist_heineken_monteur')
        .eq('status', 'abgeschlossen')
        .isFilter('protokoll_foto_pfad', null)
        .gte('datum', protokollPflichtAb.toIso8601String().split('T').first)
        .limit(500);
    final anzahl =
        rows.where((r) => r['ist_heineken_monteur'] != true).length;
    final a = protokollFehltAufgabe(anzahl);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Protokollfoto-Detektor: $e');
  }

  // g) Bank-Prüfliste — camt-Buchungen, die der Import nicht zuordnen
  //    konnte. Derselbe Provider wie der Prüflisten-Screen, damit beide nie
  //    auseinanderlaufen.
  try {
    final offen = await ref.watch(camtPrueflisteProvider.future);
    final a = bankPrueflisteAufgabe(offen.length);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Bank-Prüfliste-Detektor: $e');
  }

  // h) Eingangsrechnungen, die noch nicht zur Zahlung vorgemerkt sind.
  try {
    final alle = await ref.watch(eingangsrechnungenProvider.future);
    const offeneStati = {'erkannt', 'bestaetigt', 'gebucht'};
    final anzahl = alle.where((e) => offeneStati.contains(e.status)).length;
    final a = eingangsrechnungenAufgabe(anzahl);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Eingangsrechnungs-Detektor: $e');
  }

  // i) Monatsabschluss des Vormonats — die Zahl der nicht-grünen Regeln.
  //    Ein Vorrat: gehört ins Büro, nicht in die Glocke (B4).
  try {
    final m = vormonat(heute);
    final befunde = await ref.watch(monatsPruefungProvider(m).future);
    final offen = befunde.where((b) => b.status != PruefStatus.gruen).length;
    final a = monatsabschlussAufgabe(offen, monatsName(m.monat));
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Monatsabschluss-Detektor: $e');
  }

  return detektoren;
});

/// Mahnlauf-Aufgabe (v0.134.0) — bewusst NICHT in
/// [aufgabenDetektorenProvider]: Die Mahnlauf-Seite lädt vor jedem Erstellen
/// neu (`ref.invalidate(mahnlaufProvider)`). Hinge die Aufgabe dort drin,
/// rechnete jedes Neuladen alle anderen Detektoren mit (Review 23.09.2026,
/// I-3). So trifft es nur diese Aufgabe; die Liste setzt sich daraus neu
/// zusammen. Dieselbe Aufbereitung wie die Seite (Stichtag = Bankauszug,
/// Sperren), gezählt je Betrieb.
///
/// Seit v0.135.0 eine Liste: neben «N Betriebe fällig» steht die eigene
/// Aufgabe «Heineken einschalten» (`eskalationAufgabe`), sobald die letzte
/// Mahnung samt Frist abgelaufen ist.
final mahnlaufAufgabeProvider = FutureProvider<List<Aufgabe>>((ref) async {
  if (!_eingeloggt()) return const [];
  try {
    final m = await ref.watch(mahnlaufProvider.future);
    final mahnlauf = m.bankGesperrt
        ? mahnlaufAufgabe(m.betriebeHinterBanksperre, bankGesperrt: true)
        : mahnlaufAufgabe(m.betriebe.length);
    final eskalation = eskalationAufgabe(m.eskalation.length);
    return [
      if (mahnlauf != null) mahnlauf,
      if (eskalation != null) eskalation,
    ];
  } catch (e) {
    debugPrint('[Aufgaben] Mahnlauf-Detektor: $e');
    return const [];
  }
});

/// Mahnfall-Fristen in der Glocke (v0.135.0, Task 7): offene Fälle
/// (`MahnfallRepository.getOffene`) und erledigte Fälle mit noch offener
/// Heineken-Übernahme (`getMitOffenerUebernahme`, Notiz-Markierung
/// `[UEBERNAHME OFFEN]`, siehe `MahnfallService.kUebernahmeOffen`) — je Fall
/// über `mahnfallAufgaben(...)`. Eigener Provider wie
/// [mahnlaufAufgabeProvider]: eine eigene DB-Abfrage, die nicht bei jedem
/// Neuladen der übrigen Detektoren mitläuft.
final mahnfallAufgabenProvider = FutureProvider<List<Aufgabe>>((ref) async {
  if (!_eingeloggt()) return const [];
  try {
    final heute = DateTime.now();
    final betriebe = ref.watch(betriebAnzeigeMapProvider);
    final offene = await MahnfallRepository.getOffene();
    final uebernahmeOffen = await MahnfallRepository.getMitOffenerUebernahme();
    final faelle = [...offene, ...uebernahmeOffen];
    final aufgaben = <Aufgabe>[];
    for (final f in faelle) {
      aufgaben.addAll(mahnfallAufgaben(
        fallId: f.id,
        betrieb: betriebe[f.betriebId] ?? 'Unbekannter Betrieb',
        status: f.status,
        heinekenKontaktAm: f.heinekenKontaktAm,
        heinekenFristBis: f.heinekenFristBis,
        zahlungsbefehlAm: f.zahlungsbefehlAm,
        rechtsvorschlag: f.rechtsvorschlag,
        fortsetzungAm: f.fortsetzungAm,
        erledigung: f.erledigung,
        uebernahmeVerbucht: false,
        heute: heute,
      ));
    }
    return aufgaben;
  } catch (e) {
    debugPrint('[Aufgaben] Mahnfall-Detektor: $e');
    return const [];
  }
});

/// Halbe Zustände von draussen (V9): angefangene Reinigungen im Gerät,
/// Arbeit ohne «Beenden», Arbeitstag ohne Feierabend/km, Diktate in der
/// Warteschlange. Alles `draussen: true` — sie stehen auf der Heute-Karte.
/// Eigener Provider wie die Mahnlauf-Aufgaben: lokale Speicher und eigene
/// Abfragen, die das Neuladen der Büro-Detektoren nicht mitziehen soll.
/// Jeder Block einzeln abgesichert.
final draussenAufgabenProvider = FutureProvider<List<Aufgabe>>((ref) async {
  if (!_eingeloggt()) return const [];
  final heute = DateTime.now();
  final aufgaben = <Aufgabe>[];
  // Neu rechnen, sobald eine Störung oder Montage sich ändert («Beenden»).
  // Entwürfe und Diktate liegen lokal: Wer sie ändert, invalidiert diesen
  // Provider (Reinigungsformular, Diktat-Sheet, Aufgaben-Aktionen).
  ref.watch(stoerungenProvider);
  ref.watch(montagenProvider);
  final namen = {
    for (final b in ref.watch(betriebeProvider))
      if (b.serverId != null) b.serverId!: b.name,
  };

  // a) Angefangene Reinigungen — lokal gesicherte Entwürfe (V2).
  try {
    final offen = await ReinigungEntwurfSpeicher.alleOffen();
    aufgaben.addAll(angefangeneReinigungAufgaben(offen, namen));
  } catch (e) {
    debugPrint('[Aufgaben] Entwurf-Detektor: $e');
  }

  // b) Laufende Arbeit von gestern — «Beginn» gedrückt, «Beenden» nie.
  //    `arbeit_bis` leer per isFilter (NULL-Falle: nie neq). Der Tag des
  //    Einsatzes ist der geplante, sonst das Datum; «vor heute» in Dart.
  //    Status ebenfalls in Dart: Abgeschlossenes ohne `arbeit_bis` zählt nicht.
  try {
    final client = SupabaseService.client;
    final ab = heute
        .subtract(const Duration(days: 14))
        .toIso8601String()
        .split('T')
        .first;
    final offen = <OffeneArbeit>[];
    for (final (tabelle, typ) in [
      ('stoerungen', 'stoerung'),
      ('montagen', 'montage'),
    ]) {
      final rows = await client
          .from(tabelle)
          .select('id, betrieb_id, datum, geplant_am, status')
          .not('arbeit_von', 'is', null)
          .isFilter('arbeit_bis', null)
          .gte('datum', ab)
          .order('datum')
          .order('id')
          .limit(100);
      for (final r in rows) {
        if (!einsatzArbeitLaeuft(typ, r['status'] as String?)) continue;
        final tag = DateTime.tryParse(
          (r['geplant_am'] ?? r['datum'] ?? '').toString(),
        );
        if (tag == null) continue;
        offen.add((
          typ: typ,
          id: r['id'].toString(),
          betriebName: namen[r['betrieb_id']?.toString()] ?? 'Unbekannter Betrieb',
          datum: tag,
        ));
      }
    }
    aufgaben.addAll(laufendeArbeitAufgaben(offen, heute));
  } catch (e) {
    debugPrint('[Aufgaben] Laufende-Arbeit-Detektor: $e');
  }

  // c) Arbeitstag vor heute mit Beginn, aber ohne Feierabend oder km-Stand
  //    (`tagesplaene`, dieselben Felder wie die Arbeitstag-Karte).
  try {
    final ab = heute
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .split('T')
        .first;
    final rows = await SupabaseService.client
        .from('tagesplaene')
        .select('datum, arbeitsbeginn, arbeitsende, km_stand')
        .gte('datum', ab)
        .not('arbeitsbeginn', 'is', null)
        .order('datum')
        .order('id')
        .limit(50);
    final a = arbeitstagOffenAufgabe([
      for (final r in rows)
        if (DateTime.tryParse(r['datum']?.toString() ?? '') case final d?)
          (
            datum: d,
            beginn: r['arbeitsbeginn'] as String?,
            ende: r['arbeitsende'] as String?,
            km: (r['km_stand'] as num?)?.toInt(),
          ),
    ], heute);
    if (a != null) aufgaben.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Arbeitstag-Detektor: $e');
  }

  // d) Diktate, deren Auswertung im Funkloch scheiterte (lokal).
  try {
    final a = diktateWartenAufgabe(
      (await EinsatzDiktatEntwurfSpeicher.laden()).length,
    );
    if (a != null) aufgaben.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Diktat-Detektor: $e');
  }

  return aufgaben;
});
