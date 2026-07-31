import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/betrieb_vorschlag.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_vorschlag_repository.dart';

/// Offene Änderungsvorschläge aus Google/Website (`betrieb_vorschlaege`,
/// Migration 160), neueste zuerst.
final offeneVorschlaegeProvider = FutureProvider<List<BetriebVorschlagDto>>((
  ref,
) {
  return BetriebVorschlagRepository.offene();
});

/// Anzahl offener Vorschläge — steuert die Zeile im Aufgaben-Screen
/// («N Änderungsvorschläge prüfen»), die nur bei N > 0 sichtbar ist.
final offeneVorschlaegeAnzahlProvider = Provider<int>((ref) {
  return ref.watch(offeneVorschlaegeProvider).valueOrNull?.length ?? 0;
});
