import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
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
/// `aufgabenProvider` (B6). Ohne Snooze: den wendet `baueAufgabenListe` an.
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

  return detektoren;
});
