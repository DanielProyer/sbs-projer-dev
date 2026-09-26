import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/data/local/region_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_akte_providers.dart';
import 'package:sbs_projer_app/presentation/providers/einsatz_providers.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_typ_wahl.dart';
import 'package:sbs_projer_app/presentation/widgets/einsatz_zeile.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

String _anlageTypLabel(String typ) =>
    typ.isEmpty ? typ : typ[0].toUpperCase() + typ.substring(1);

/// Darstellung ohne Datenanbindung — testbar ohne Provider.
class EinsaetzeInhalt extends StatelessWidget {
  final List<Einsatz> alle;
  final EinsatzFilter filter;
  final List<int> jahre;
  final List<RegionLocal> regionen;
  final List<String> anlagenTypen;
  final ValueChanged<EinsatzFilter> onFilter;
  final ValueChanged<Einsatz> onOeffnen;

  /// `null` heisst: kein eindeutiger Typ gewählt — der Screen fragt nach.
  final ValueChanged<EinsatzTyp?> onNeu;

  /// Name des Betriebs, auf den `filter.betriebId` einschränkt (Chip).
  final String? betriebName;

  const EinsaetzeInhalt({
    super.key,
    required this.alle,
    required this.filter,
    required this.jahre,
    required this.regionen,
    required this.anlagenTypen,
    required this.onFilter,
    required this.onOeffnen,
    required this.onNeu,
    this.betriebName,
  });

  @override
  Widget build(BuildContext context) {
    final gefiltert = filtereEinsaetze(alle, filter);
    final summe = gefiltert.fold(0.0, (s, e) => s + (e.betragCHF ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einsätze'),
        actions: [
          if (regionen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AppFilterMultiDropdown<String>(
                label: 'Regionen',
                options: [
                  for (final r in regionen)
                    if (r.serverId != null) (r.serverId!, r.name),
                ],
                selected: filter.regionIds,
                onChanged: (s) => onFilter(filter.copyWith(regionIds: s)),
              ).build(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              hintText: 'Betrieb, Ort oder Nummer…',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => onFilter(filter.copyWith(suche: v)),
            ),
          ),
          // Typ und Status als Mehrfach-Dropdowns, keine Chip-Reihe: Sieben
          // Typen wären auf 360 px zwei Zeilen Chips (Regel «kompakte
          // Dropdowns statt Chips», ui_smartphone_first).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: AppFilterMultiDropdown<EinsatzTyp>(
                    label: 'Typen',
                    isExpanded: true,
                    options: [
                      for (final t in EinsatzTyp.values)
                        (t, einsatzTypLabel(t)),
                    ],
                    selected: filter.typen,
                    onChanged: (s) => onFilter(filter.copyWith(typen: s)),
                  ).build(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppFilterMultiDropdown<EinsatzStatus>(
                    label: 'Status',
                    isExpanded: true,
                    options: [
                      for (final s in EinsatzStatus.values)
                        (s, einsatzStatusLabel(s)),
                    ],
                    selected: filter.status,
                    onChanged: (s) => onFilter(filter.copyWith(status: s)),
                  ).build(context),
                ),
              ],
            ),
          ),
          // Die drei Störungs-Zusatzfilter aus Paket 06 — nur wenn genau
          // «Störung» gewählt ist, sonst belasten sie die Liste ohne Nutzen.
          if (filter.nurStoerung)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: AppFilterDropdown<String>(
                      hint: 'Anlage',
                      isExpanded: true,
                      value: filter.anlageTyp,
                      options: [
                        for (final t in anlagenTypen) (t, _anlageTypLabel(t)),
                        ('ohne', 'Ohne Typ'),
                      ],
                      onChanged: (v) => onFilter(filter.copyWith(anlageTyp: v)),
                    ).build(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppFilterDropdown<String>(
                      hint: 'Art',
                      isExpanded: true,
                      nullable: false,
                      value: filter.kmFilter,
                      options: const [
                        ('ohne', 'Störung'),
                        ('mit', 'Kilometerabrechnung'),
                        ('alle', 'Alle'),
                      ],
                      onChanged: (v) =>
                          onFilter(filter.copyWith(kmFilter: v ?? 'alle')),
                    ).build(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppFilterDropdown<int>(
                      hint: 'Bereich',
                      isExpanded: true,
                      value: filter.bereich,
                      options: const [
                        (1, '1 - Zapfhahn'),
                        (2, '2 - Leitung'),
                        (3, '3 - Kühler'),
                        (4, '4 - Zapfkopf'),
                        (5, '5 - Gas'),
                      ],
                      onChanged: (v) => onFilter(filter.copyWith(bereich: v)),
                    ).build(context),
                  ),
                ],
              ),
            ),
          if (filter.betriebId != null)
            _BetriebChipZeile(
              name: betriebName ?? 'Betrieb',
              anzahl: gefiltert.length,
              onEntfernen: () => onFilter(
                filter.copyWith(betriebId: null, jahr: DateTime.now().year),
              ),
            )
          else
            AppJahrMonatLeiste(
              jahre: jahre,
              selectedJahr: filter.jahr,
              onJahrChanged: (j) => onFilter(filter.copyWith(jahr: j)),
              selectedMonat: filter.monat,
              onMonatChanged: (m) => onFilter(filter.copyWith(monat: m)),
              trailing: Text(
                summe > 0
                    ? '${gefiltert.length} – ${chf(summe)}'
                    : '${gefiltert.length} Einsätze',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Expanded(
            child: gefiltert.isEmpty
                ? const Center(
                    child: Text(
                      'Keine Einsätze für diese Auswahl',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: gefiltert.length,
                    itemBuilder: (_, i) => EinsatzZeile(
                      einsatz: gefiltert[i],
                      onTap: () => onOeffnen(gefiltert[i]),
                      imBetrieb: filter.betriebId != null,
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _istGast()
          ? null
          : FloatingActionButton(
              key: const Key('einsaetze_neu'),
              onPressed: () =>
                  onNeu(filter.typen.length == 1 ? filter.typen.single : null),
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// In Tests ist Supabase nicht initialisiert — `SupabaseService.currentUser`
/// würde dann werfen. Der Gast-Check darf den Screen nicht zum Absturz
/// bringen, wenn er ausserhalb der echten App (z.B. im Widget-Test) läuft.
bool _istGast() {
  try {
    return SupabaseService.isGuest;
  } catch (_) {
    return false;
  }
}

/// «Betrieb: Name ×» anstelle der Jahr/Monat-Leiste, wenn der Screen aus
/// der Betriebsseite kommt (`/einsaetze?betrieb=<id>`). Die Akte reicht über
/// alle Jahre, deshalb gibt es hier keine Jahresauswahl. InkWell + Container
/// statt Chip-Widget (CanvasKit-Regel).
class _BetriebChipZeile extends StatelessWidget {
  final String name;
  final int anzahl;
  final VoidCallback onEntfernen;
  const _BetriebChipZeile({
    required this.name,
    required this.anzahl,
    required this.onEntfernen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              key: const Key('einsaetze_betrieb_chip'),
              onTap: onEntfernen,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Betrieb: $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.close, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$anzahl Einsätze, alle Jahre',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Angebunden: hält den Filterzustand, lädt das Jahr, navigiert.
class EinsaetzeScreen extends ConsumerStatefulWidget {
  final EinsatzTyp? vorgewaehlterTyp;

  /// Server-Id aus `?betrieb=` — dann nur dieser Betrieb, über alle Jahre.
  final String? betriebId;
  const EinsaetzeScreen({super.key, this.vorgewaehlterTyp, this.betriebId});

  @override
  ConsumerState<EinsaetzeScreen> createState() => _EinsaetzeScreenState();
}

class _EinsaetzeScreenState extends ConsumerState<EinsaetzeScreen> {
  late EinsatzFilter _filter;

  @override
  void initState() {
    super.initState();
    final betriebId = widget.betriebId;
    _filter = EinsatzFilter(
      jahr: betriebId != null ? 0 : DateTime.now().year,
      betriebId: betriebId,
      typen: widget.vorgewaehlterTyp == null
          ? const {}
          : {widget.vorgewaehlterTyp!},
    );
  }

  @override
  Widget build(BuildContext context) {
    var jahre =
        ref.watch(reinigungJahreProvider).valueOrNull ?? [DateTime.now().year];
    if (_filter.jahr != 0 && !jahre.contains(_filter.jahr)) {
      jahre = [_filter.jahr, ...jahre];
    }
    final regionen = ref.watch(regionenProvider);
    final betriebId = _filter.betriebId;
    // Mit Betrieb: nur dessen Einsätze, alle Jahre (dieselbe Quelle wie die
    // Akte auf der Betriebsseite). Sonst das Kalenderjahr aller Betriebe.
    final einsaetze = betriebId != null
        ? ref.watch(
            betriebEinsaetzeProvider((betriebId: betriebId, anlageId: null)),
          )
        : ref.watch(einsaetzeProvider(_filter.jahr));
    final betriebName = betriebId == null
        ? null
        : ref.watch(betriebLookupProvider)[betriebId]?.name;

    return einsaetze.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Einsätze')),
        body: Center(child: Text('Einsätze konnten nicht geladen werden: $e')),
      ),
      data: (alle) {
        final anlagenTypen =
            alle
                .where((e) => e.typ == EinsatzTyp.stoerung)
                .map((e) => e.anlageTyp)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
        return EinsaetzeInhalt(
          alle: alle,
          filter: _filter,
          jahre: jahre,
          regionen: regionen,
          anlagenTypen: anlagenTypen,
          betriebName: betriebName,
          onFilter: (f) => setState(() => _filter = f),
          onOeffnen: (e) => context.push(e.detailRoute),
          onNeu: (typ) => typ == null
              ? _typWaehlen(context)
              : _neu(GoRouter.of(context), typ),
        );
      },
    );
  }

  /// Nimmt den Router, nicht den Kontext: Aus dem «+»-Sheet heraus ist der
  /// Sheet-Kontext nach `Navigator.pop` nicht mehr gültig (Lehre aus
  /// `diktat_sheet.dart`, A4).
  void _neu(GoRouter router, EinsatzTyp typ) {
    router.push(einsatzNeuRoute(typ, betriebId: _filter.betriebId));
  }

  void _typWaehlen(BuildContext context) {
    final router = GoRouter.of(context);
    zeigeEinsatzTypWahl(
      context,
      typen: [
        for (final t in EinsatzTyp.values)
          if (t != EinsatzTyp.termin) t,
      ],
      onWahl: (t) => _neu(router, t),
    );
  }
}
