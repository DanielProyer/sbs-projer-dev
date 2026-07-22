import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

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
        .inFilter('zahlungsstatus', ['offen', 'erinnert', 'mahnung_1', 'mahnung_2'])
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

  final offene = sortiereAufgaben(detektoren
      .where((a) => !snoozeAktiv(snoozes[a.key], heute))
      .toList());

  final eigene = <EigeneAufgabe>[];
  for (final z in zeilen.where((z) => z['typ'] == 'eigene')) {
    if (z['erledigt_am'] != null) continue;
    final faellig = DateTime.tryParse(z['faellig_am'] as String? ?? '');
    if (!eigeneSichtbar(faellig, heute)) continue;
    final key = 'eigene:${z['id']}';
    if (snoozeAktiv(snoozes[key], heute)) continue;
    final istDringend = faellig != null &&
        !faellig.isAfter(DateTime(heute.year, heute.month, heute.day));
    eigene.add(EigeneAufgabe(
      z['id'] as String,
      Aufgabe(
        key: key,
        titel: (z['titel'] ?? '?') as String,
        dringend: istDringend,
        manuellErledigbar: true,
      ),
    ));
  }
  eigene.sort((a, b) =>
      (b.aufgabe.dringend ? 1 : 0) - (a.aufgabe.dringend ? 1 : 0));

  return AufgabenStand(offene, eigene);
});
