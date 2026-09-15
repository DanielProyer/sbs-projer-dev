import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_detektoren_provider.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_vorschlag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
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
