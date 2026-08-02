import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/einsatz_faellig.dart';
import 'package:sbs_projer_app/core/util/termin_abgleich.dart';
import 'package:sbs_projer_app/data/repositories/aufgaben_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_vorschlag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/einplanen_sheet.dart';

/// Offene EIGENE Aufgaben — ALLE, auch mit Fälligkeitsdatum in der Zukunft.
/// Bewusst nicht `aufgabenProvider`: der filtert für die Erinnerungs-Glocke
/// auf «jetzt sichtbar» — ein Planungs-Screen braucht auch das, was erst
/// nächste Woche ansteht (Daniel 31.07.2026).
final offeneEigeneAufgabenProvider =
    FutureProvider<List<({String id, String titel, DateTime? faellig})>>((
      ref,
    ) async {
      final zeilen = await AufgabenRepository.alleZeilen();
      final offene = [
        for (final z in zeilen)
          if (z['typ'] == 'eigene' && z['erledigt_am'] == null)
            (
              id: z['id'] as String,
              titel: (z['titel'] ?? '?') as String,
              faellig: DateTime.tryParse(z['faellig_am'] as String? ?? ''),
            ),
      ];
      offene.sort((a, b) {
        if (a.faellig == null && b.faellig == null) return 0;
        if (a.faellig == null) return 1;
        if (b.faellig == null) return -1;
        return a.faellig!.compareTo(b.faellig!);
      });
      return offene;
    });

class _Eintrag {
  final DateTime? datum;
  final IconData icon;
  final Color farbe;
  final String titel;
  final String? untertitel;
  final VoidCallback? onTap;
  final Future<void> Function()? onErledigt;

  /// Nur Störung/Montage: öffnet das Einplanen-Sheet (Migration 163) — die
  /// bisher einzige Lücke im Screen war fehlende Aktion ausser Navigation
  /// (Daniel 31.07.2026).
  final Future<void> Function()? onEinplanen;

  /// Nur berechnete Eröffnungs-/Endreinigungs-Vorschläge (Etappe 4): legt
  /// einen bestätigten Termin mit Kalender-Erinnerung an. «Berechnet bleibt
  /// berechnet, bestätigt wird gespeichert.»
  final Future<void> Function()? onBestaetigen;

  const _Eintrag({
    required this.datum,
    required this.icon,
    required this.farbe,
    required this.titel,
    this.untertitel,
    this.onTap,
    this.onErledigt,
    this.onEinplanen,
    this.onBestaetigen,
  });
}

/// Aufgaben-Screen (Daniel 31.07.2026): alle anstehenden Arbeiten an einem
/// Ort, chronologisch — eigene Aufgaben (inkl. künftiger), offene Störungen,
/// geplante Montagen und anstehende Eröffnungs-/Endreinigungen. Ersetzt die
/// Events-Kachel auf dem Startbildschirm. Verknüpfung mit Google-Kalender
/// und direkter Tagesplan-Übernahme = geplanter Ausbau (ToDo.md).
class AufgabenScreen extends ConsumerWidget {
  const AufgabenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heute = DateTime.now();
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    final lookup = ref.watch(betriebLookupProvider);
    final eintraege = <_Eintrag>[];

    // Änderungsvorschläge aus Google/Website (Prüfliste, Migration 160) —
    // ohne Datum, damit sie nicht in einem bestimmten Tag "verschwinden".
    final vorschlaegeAnzahl = ref.watch(offeneVorschlaegeAnzahlProvider);
    if (vorschlaegeAnzahl > 0) {
      eintraege.add(
        _Eintrag(
          datum: null,
          icon: Icons.fact_check_outlined,
          farbe: AppColors.info,
          titel: '$vorschlaegeAnzahl Änderungsvorschläge prüfen',
          onTap: () => context.push('/betriebe/vorschlaege'),
        ),
      );
    }

    // Eigene Aufgaben (auch künftige).
    final eigene =
        ref.watch(offeneEigeneAufgabenProvider).valueOrNull ?? const [];
    for (final a in eigene) {
      eintraege.add(
        _Eintrag(
          datum: a.faellig,
          icon: Icons.task_alt,
          farbe: AppColors.warning,
          titel: a.titel,
          onErledigt: () async {
            await AufgabenRepository.eigeneErledigen(a.id);
            ref.invalidate(offeneEigeneAufgabenProvider);
          },
        ),
      );
    }

    // Offene Störungen (Datum = Meldedatum; Planungstext = geplant_am/_zeit).
    for (final s in ref.watch(stoerungenProvider)) {
      if (!stoerungOffen(s.status)) continue;
      final betrieb = s.betriebId != null ? lookup[s.betriebId!] : null;
      final plan = planungsText(
        geplantAm: s.geplantAm,
        geplantZeit: s.geplantZeit,
      );
      eintraege.add(
        _Eintrag(
          datum: s.datum,
          icon: Icons.warning_amber,
          farbe: AppColors.error,
          titel: 'Störung ${betrieb?.name ?? '?'}',
          untertitel: '${s.problemBeschreibung} · $plan',
          onTap: () => context.push('/stoerungen/${s.routeId}'),
          onEinplanen: () async {
            final titel = betrieb?.name ?? '?';
            final ergebnis = await zeigeEinplanenSheet(
              context,
              titel: titel,
              untertitel: s.problemBeschreibung,
              initialTag: s.geplantAm,
              initialZeit: s.geplantZeit,
              initialDauerMin: s.geplantDauerMin,
            );
            if (ergebnis == null) return;
            await StoerungRepository.einplanen(
              id: s.routeId,
              tag: ergebnis.tag,
              zeit: ergebnis.zeit,
              dauerMin: ergebnis.dauerMin,
            );
            ref.invalidate(stoerungenStreamProvider);
            // Ohne das hier landet der Einsatz nur in der Fällig-Liste des
            // Zieltags, nie in der Zeitachse — siehe Doku bei
            // `einsatzInTagesplanAufnehmen` (Fehlerbericht 02.08.2026).
            await einsatzInTagesplanAufnehmen(
              ref,
              ergebnis.tag,
              geplanterEinsatzEintrag(
                typ: TourEintragTyp.stoerung,
                routeId: s.routeId,
                betriebId: s.betriebId,
                anlageId: s.anlageId,
                betriebName: betrieb?.name ?? '?',
                betriebOrt: betrieb?.ort,
                regionId: betrieb?.regionId,
                beschreibung: s.problemBeschreibung,
                ruhetage: betrieb?.ruhetage ?? const [],
                servicezeit: servicezeitAus(betrieb),
                tag: ergebnis.tag,
                zeit: ergebnis.zeit,
                dauerMin: ergebnis.dauerMin,
              ),
            );
          },
        ),
      );
    }

    // Geplante Montagen (inkl. HeiGenie, inkl. Rebranding als Montage-Typ).
    for (final m in ref.watch(montagenProvider)) {
      if (!montageOffen(m.status)) continue;
      final betrieb = m.betriebId != null ? lookup[m.betriebId!] : null;
      final plan = planungsText(
        geplantAm: m.geplantAm,
        geplantZeit: m.geplantZeit,
      );
      eintraege.add(
        _Eintrag(
          datum: m.datum,
          icon: Icons.construction,
          farbe: AppColors.info,
          titel: 'Montage ${betrieb?.name ?? '?'}',
          untertitel: '${m.montageTyp} · $plan',
          onTap: () => context.push('/montagen/${m.routeId}'),
          onEinplanen: () async {
            final titel = betrieb?.name ?? '?';
            final ergebnis = await zeigeEinplanenSheet(
              context,
              titel: titel,
              untertitel: m.montageTyp,
              initialTag: m.geplantAm,
              initialZeit: m.geplantZeit,
              initialDauerMin: m.geplantDauerMin,
            );
            if (ergebnis == null) return;
            await MontageRepository.einplanen(
              id: m.routeId,
              tag: ergebnis.tag,
              zeit: ergebnis.zeit,
              dauerMin: ergebnis.dauerMin,
            );
            ref.invalidate(montagenStreamProvider);
            // Ohne das hier landet der Einsatz nur in der Fällig-Liste des
            // Zieltags, nie in der Zeitachse — siehe Doku bei
            // `einsatzInTagesplanAufnehmen` (Fehlerbericht 02.08.2026).
            await einsatzInTagesplanAufnehmen(
              ref,
              ergebnis.tag,
              geplanterEinsatzEintrag(
                typ: m.montageTyp == 'heigenie_service'
                    ? TourEintragTyp.heigenie
                    : TourEintragTyp.montage,
                routeId: m.routeId,
                betriebId: m.betriebId,
                anlageId: m.anlageId,
                betriebName: betrieb?.name ?? '?',
                betriebOrt: betrieb?.ort,
                regionId: betrieb?.regionId,
                beschreibung: m.beschreibung,
                ruhetage: betrieb?.ruhetage ?? const [],
                servicezeit: servicezeitAus(betrieb),
                tag: ergebnis.tag,
                zeit: ergebnis.zeit,
                dauerMin: ergebnis.dauerMin,
                montageTyp: m.montageTyp,
              ),
            );
          },
        ),
      );
    }

    // Bereits bestätigte Termine (Etappe 4 — «Berechnet bleibt berechnet,
    // bestätigt wird gespeichert»). Wird auch für den Doppelanzeige-Abgleich
    // gegen die berechneten Vorschläge unten gebraucht.
    final offeneTermine =
        ref.watch(offeneTermineProvider).valueOrNull ?? const [];
    final bestehendeReinigungsTermine = [
      for (final t in offeneTermine)
        if (t.typ == 'eroeffnungsreinigung' || t.typ == 'endreinigung')
          TerminVergleich(betriebId: t.betriebId, typ: t.typ, datum: t.datum),
    ];

    // Anstehende Eröffnungs-/Endreinigungen (Saison-Automatik). Ein
    // Vorschlag wird ausgeblendet, wenn dafür schon ein bestätigter Termin
    // existiert (±7 Tage, siehe termin_abgleich.dart) — sonst erscheint er
    // doppelt: einmal als Vorschlag, einmal als bestätigter Termin unten.
    for (final e in ref.watch(autoTermineProvider(heuteTag))) {
      final typ = e.faelligkeit == FaelligkeitsStatus.endreinigungFaellig
          ? 'endreinigung'
          : e.faelligkeit == FaelligkeitsStatus.eroeffnungFaellig
          ? 'eroeffnungsreinigung'
          : null;
      final betriebId = e.betriebId;
      final zielDatum = e.zielDatum;
      if (typ != null &&
          betriebId != null &&
          zielDatum != null &&
          terminDecktVorschlagAb(
            vorschlagBetriebId: betriebId,
            vorschlagTyp: typ,
            vorschlagDatum: zielDatum,
            bestehendeTermine: bestehendeReinigungsTermine,
          )) {
        continue;
      }
      eintraege.add(
        _Eintrag(
          datum: e.zielDatum,
          icon: Icons.cleaning_services_outlined,
          farbe: AppColors.primary,
          titel: '${e.beschreibung} ${e.betriebName}'.trim(),
          untertitel: e.betriebOrt,
          onTap: e.betriebId != null
              ? () {
                  final b = lookup[e.betriebId!];
                  if (b != null) context.push('/betriebe/${b.routeId}');
                }
              : null,
          onBestaetigen: typ == null || betriebId == null || zielDatum == null
              ? null
              : () async {
                  final label = typ == 'endreinigung'
                      ? 'Endreinigung'
                      : 'Eröffnungsreinigung';
                  await TerminRepository.anlegen(
                    betriebId: betriebId,
                    typ: typ,
                    datum: zielDatum,
                    titel: '$label ${e.betriebName}'.trim(),
                    anlass: typ == 'endreinigung'
                        ? 'saisonende'
                        : 'saisonstart',
                  );
                  ref.invalidate(offeneTermineProvider);
                },
        ),
      );
    }

    // Bestätigte Eröffnungs-/Endreinigungs-Termine selbst (mit
    // Kalender-Erinnerung) — erscheinen ab jetzt als Termin, nicht mehr als
    // Vorschlag.
    for (final t in offeneTermine) {
      if (t.typ != 'eroeffnungsreinigung' && t.typ != 'endreinigung') continue;
      final betrieb = lookup[t.betriebId];
      final label = t.typ == 'endreinigung'
          ? 'Endreinigung'
          : 'Eröffnungsreinigung';
      eintraege.add(
        _Eintrag(
          datum: t.datum,
          icon: Icons.cleaning_services,
          farbe: AppColors.success,
          titel: t.titel.isNotEmpty
              ? t.titel
              : '$label ${betrieb?.name ?? '?'}',
          untertitel: betrieb?.ort,
          onTap: betrieb != null
              ? () => context.push('/betriebe/${betrieb.routeId}')
              : null,
          onErledigt: () async {
            await TerminRepository.erledigen(t.id);
            ref.invalidate(offeneTermineProvider);
          },
        ),
      );
    }

    // Chronologisch, ohne Datum ans Ende.
    eintraege.sort((a, b) {
      if (a.datum == null && b.datum == null) return 0;
      if (a.datum == null) return 1;
      if (b.datum == null) return -1;
      return a.datum!.compareTo(b.datum!);
    });

    // Gruppieren nach Tag (Überfällig/Heute/Morgen/Datum/Ohne Datum).
    String gruppe(DateTime? d) {
      if (d == null) return 'Ohne Datum';
      final tag = DateTime(d.year, d.month, d.day);
      if (tag.isBefore(heuteTag)) return 'Überfällig';
      if (tag == heuteTag) return 'Heute';
      if (tag == heuteTag.add(const Duration(days: 1))) return 'Morgen';
      return DateFormat('EE, dd.MM.yyyy', 'de_CH').format(tag);
    }

    final kinder = <Widget>[];
    String? letzteGruppe;
    for (final e in eintraege) {
      final g = gruppe(e.datum);
      if (g != letzteGruppe) {
        letzteGruppe = g;
        kinder.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              g,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: g == 'Überfällig'
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }
      kinder.add(_EintragKarte(eintrag: e));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aufgaben')),
      body: eintraege.isEmpty
          ? const Center(
              child: Text(
                'Keine anstehenden Aufgaben.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: kinder,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _neueAufgabe(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _neueAufgabe(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    DateTime? faellig;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Neue Aufgabe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titel'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      faellig == null
                          ? 'Kein Datum'
                          : DateFormat('dd.MM.yyyy').format(faellig!),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final gewaehlt = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (gewaehlt != null) {
                        setState(() => faellig = gewaehlt);
                      }
                    },
                    child: const Text('Datum wählen'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anlegen'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    await AufgabenRepository.eigeneAnlegen(controller.text.trim(), faellig);
    ref.invalidate(offeneEigeneAufgabenProvider);
  }
}

class _EintragKarte extends StatelessWidget {
  final _Eintrag eintrag;

  const _EintragKarte({required this.eintrag});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: InkWell(
        onTap: eintrag.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(eintrag.icon, size: 20, color: eintrag.farbe),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eintrag.titel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (eintrag.untertitel != null &&
                        eintrag.untertitel!.isNotEmpty)
                      Text(
                        eintrag.untertitel!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (eintrag.onEinplanen != null)
                IconButton(
                  icon: const Icon(Icons.event_outlined),
                  color: AppColors.textSecondary,
                  tooltip: 'Einplanen',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => eintrag.onEinplanen!(),
                ),
              if (eintrag.onBestaetigen != null)
                IconButton(
                  icon: const Icon(Icons.event_available_outlined),
                  color: AppColors.primary,
                  tooltip: 'Termin bestätigen',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => eintrag.onBestaetigen!(),
                ),
              if (eintrag.onErledigt != null)
                IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  tooltip: 'Erledigt',
                  onPressed: () => eintrag.onErledigt!(),
                )
              else if (eintrag.onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
