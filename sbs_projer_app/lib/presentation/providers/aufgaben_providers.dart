import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_vorschlag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

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

/// Offene eigene Aufgabe (mit DB-id für Erledigen).
class EigeneAufgabe {
  final String id;
  final Aufgabe aufgabe;
  const EigeneAufgabe(this.id, this.aufgabe);
}

class AufgabenStand {
  final List<Aufgabe> offene; // Detektoren, nach Snooze/Marker
  final List<EigeneAufgabe> eigene; // offene eigene, sichtbar
  int get badge => offene.length + eigene.length;
  const AufgabenStand(this.offene, this.eigene);
  static const leer = AufgabenStand([], []);
}

final aufgabenProvider = FutureProvider<AufgabenStand>((ref) async {
  if (SupabaseService.currentUser == null) return AufgabenStand.leer;
  final heute = DateTime.now();
  final client = SupabaseService.client;

  List<Map<String, dynamic>> zeilen = const [];
  try {
    zeilen = await AufgabenRepository.alleZeilen();
  } catch (e) {
    debugPrint('[Aufgaben] Tabelle nicht ladbar: $e');
    return AufgabenStand.leer;
  }
  final marker = zeilen
      .where((z) => z['typ'] == 'marker' && z['key'] != null)
      .map((z) => z['key'] as String)
      .toSet();
  final snoozes = <String, DateTime>{};
  for (final z in zeilen.where((z) => z['typ'] == 'snooze')) {
    final bis = DateTime.tryParse(z['snooze_bis'] as String? ?? '');
    if (z['key'] != null && bis != null) snoozes[z['key'] as String] = bis;
  }

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

  // c) Mahnlauf — offene Kundenrechnungen über den bestehenden Schwellen.
  try {
    final rows = await client
        .from('rechnungen')
        .select()
        .inFilter('zahlungsstatus', [
          'offen',
          'erinnert',
          'mahnung_1',
          'mahnung_2',
        ])
        .neq('rechnungstyp', 'heineken_monat')
        .limit(2000);
    if (rows.length >= 2000) debugPrint('[Aufgaben] Mahnlauf-Query am Limit');
    final anzahl = rows
        .map((r) => Rechnung.fromJson(r))
        .where((r) => ForderungService.istMahnfaellig(r, heute: heute))
        .length;
    final a = mahnlaufAufgabe(anzahl);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Mahnlauf-Detektor: $e');
  }

  // d) Saisondaten — bestehender Tourenplan-Provider.
  try {
    final a = saisondatenAufgabe(ref.watch(saisonAnkerFehltProvider).length);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Saisondaten-Detektor: $e');
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
  try {
    final grenze = heute.subtract(const Duration(days: 1));
    final rows = await client
        .from('rechnungen')
        .select('id, betrieb_id, created_at')
        .eq('zahlungsstatus', 'offen')
        .neq('rechnungstyp', 'heineken_monat')
        .lt('created_at', grenze.toIso8601String())
        .gte(
          'created_at',
          heute.subtract(const Duration(days: 60)).toIso8601String(),
        )
        .limit(500);

    // Nur solche, deren Reinigung wirklich per Mail abgerechnet wird —
    // «Tresen» und «bar» stehen zu Recht auf offen.
    var verdaechtig = 0;
    for (final r in rows) {
      final betriebId = r['betrieb_id']?.toString();
      if (betriebId == null) continue;
      final rein = await client
          .from('reinigungen')
          .select('id')
          .eq('betrieb_id', betriebId)
          .eq('zahlungsart', 'rechnung_mail')
          .eq('datum', (r['created_at'] as String).split('T').first)
          .limit(1);
      if (rein.isNotEmpty) verdaechtig++;
    }
    final a = versandvermerkAufgabe(verdaechtig);
    if (a != null) detektoren.add(a);
  } catch (e) {
    debugPrint('[Aufgaben] Versandvermerk-Detektor: $e');
  }

  final offene = sortiereAufgaben(
    detektoren.where((a) => !snoozeAktiv(snoozes[a.key], heute)).toList(),
  );

  final eigeneMitDatum = <(DateTime?, EigeneAufgabe)>[];
  for (final z in zeilen.where((z) => z['typ'] == 'eigene')) {
    if (z['erledigt_am'] != null) continue;
    final faellig = DateTime.tryParse(z['faellig_am'] as String? ?? '');
    if (!eigeneSichtbar(faellig, heute)) continue;
    final key = 'eigene:${z['id']}';
    if (snoozeAktiv(snoozes[key], heute)) continue;
    final istDringend =
        faellig != null &&
        !faellig.isAfter(DateTime(heute.year, heute.month, heute.day));
    eigeneMitDatum.add((
      faellig,
      EigeneAufgabe(
        z['id'] as String,
        Aufgabe(
          key: key,
          titel: (z['titel'] ?? '?') as String,
          dringend: istDringend,
          manuellErledigbar: true,
        ),
      ),
    ));
  }
  // Deterministisch: erst dringend desc, dann faellig_am asc (null zuletzt).
  eigeneMitDatum.sort((a, b) {
    final d = (b.$2.aufgabe.dringend ? 1 : 0) - (a.$2.aufgabe.dringend ? 1 : 0);
    if (d != 0) return d;
    if (a.$1 == null && b.$1 == null) return 0;
    if (a.$1 == null) return 1;
    if (b.$1 == null) return -1;
    return a.$1!.compareTo(b.$1!);
  });
  final eigene = eigeneMitDatum.map((e) => e.$2).toList();

  return AufgabenStand(offene, eigene);
});

/// Die eine Aufgabenliste (B6): Detektoren + eigene Aufgaben + anstehende
/// Einsätze + Saison-Vorschläge + bestätigte Saison-Termine +
/// Änderungsvorschläge, nach Fälligkeit. Glocke, Startkarte, Kachel, Sheet
/// und Screen lesen alle hier.
final aufgabenListeProvider = FutureProvider<List<AufgabenEintrag>>((
  ref,
) async {
  if (!_eingeloggt()) return const [];
  final heute = DateTime.now();
  final heuteTag = DateTime(heute.year, heute.month, heute.day);
  final betriebe = ref.watch(betriebLookupProvider);

  final detektoren = await ref.watch(aufgabenDetektorenProvider.future);
  final zeilen = await ref.watch(aufgabenZeilenProvider.future);
  final termine = await ref.watch(offeneTermineProvider.future);

  final saisonVorschlaege = <SaisonVorschlag>[
    for (final e in ref.watch(autoTermineProvider(heuteTag)))
      if (e.betriebId != null && e.zielDatum != null)
        if (e.faelligkeit == FaelligkeitsStatus.endreinigungFaellig ||
            e.faelligkeit == FaelligkeitsStatus.eroeffnungFaellig)
          (
            betriebId: e.betriebId!,
            betriebName: e.betriebName,
            betriebOrt: e.betriebOrt,
            typ: e.faelligkeit == FaelligkeitsStatus.endreinigungFaellig
                ? 'endreinigung'
                : 'eroeffnungsreinigung',
            zielDatum: e.zielDatum!,
            beschreibung: e.beschreibung,
          ),
  ];

  final saisonTermine = <SaisonTerminEintrag>[
    for (final t in termine)
      if (t.typ == 'eroeffnungsreinigung' || t.typ == 'endreinigung')
        (
          id: t.id,
          betriebId: t.betriebId,
          betriebName: betriebe[t.betriebId]?.name ?? '?',
          betriebOrt: betriebe[t.betriebId]?.ort,
          typ: t.typ,
          datum: t.datum,
          titel: t.titel,
        ),
  ];

  return baueAufgabenListe(
    detektoren: detektoren,
    aufgabenZeilen: zeilen,
    anstehend: ref.watch(anstehendeEinsaetzeProvider),
    saisonVorschlaege: saisonVorschlaege,
    saisonTermine: saisonTermine,
    aenderungsVorschlaege: ref.watch(offeneVorschlaegeAnzahlProvider),
    heute: heute,
  );
});

/// Der Ausschnitt «jetzt fällig» — leer, solange die Liste lädt (Glocke,
/// Karte und Kachel vertragen das; das Sheet zeigt den Ladezustand selbst).
final aufgabenJetztProvider = Provider<List<AufgabenEintrag>>((ref) {
  final liste = ref.watch(aufgabenListeProvider).valueOrNull ?? const [];
  final heute = DateTime.now();
  return liste.where((a) => jetztFaellig(a, heute)).toList();
});

/// Glocken-Badge und Kachelzähler — dieselbe Zahl.
final aufgabenBadgeProvider = Provider<int>(
  (ref) => ref.watch(aufgabenJetztProvider).length,
);
