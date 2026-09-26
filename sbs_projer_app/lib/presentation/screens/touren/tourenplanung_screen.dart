import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/besuch_buendelung.dart';
import 'package:sbs_projer_app/core/util/besuch_dauer.dart';
import 'package:sbs_projer_app/core/util/einsatz_faellig.dart';
import 'package:sbs_projer_app/core/util/einsatz_start.dart';
import 'package:sbs_projer_app/core/util/fahrzeit.dart';
import 'package:sbs_projer_app/core/util/ferien_vorjahr.dart';
import 'package:sbs_projer_app/core/util/kalenderwoche.dart';
import 'package:sbs_projer_app/core/util/saison_luecke.dart';
import 'package:sbs_projer_app/core/util/tagesplan_ist_zeiten.dart';
import 'package:sbs_projer_app/core/util/tagesplan_verschieben.dart';
import 'package:sbs_projer_app/core/util/tour_filter.dart';
import 'package:sbs_projer_app/core/util/tourenplan_refresh.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/core/util/touren_saison.dart';
import 'package:sbs_projer_app/core/util/war_geschlossen.dart';
import 'package:sbs_projer_app/core/util/zeitplan.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/data/repositories/fahrzeit_repository.dart';
import 'package:sbs_projer_app/data/repositories/montage_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/datum_auswahl.dart';
import 'package:sbs_projer_app/presentation/widgets/einplanen_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/gefahr_rueckfrage.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/zeit_auswahl.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeitstag_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/tour_filter_leiste.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/core/util/routen_optimierung.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/touren/saison_termine_sektion.dart';
import 'package:sbs_projer_app/presentation/widgets/war_geschlossen_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/zeitplan_leiste.dart';
import 'package:sbs_projer_app/presentation/screens/touren/widgets/wochen_leiste.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

class TourenplanungScreen extends ConsumerStatefulWidget {
  /// Startet auf diesem Tag statt auf heute — die Aufgabe «Arbeitstag ohne
  /// Feierabend» führt so direkt zum Tag, dessen Ende/km fehlt (V9).
  final DateTime? startDatum;

  const TourenplanungScreen({super.key, this.startDatum});

  @override
  ConsumerState<TourenplanungScreen> createState() =>
      _TourenplanungScreenState();
}

class _TourenplanungScreenState extends ConsumerState<TourenplanungScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late TabController _tabController;
  DateTime? _loadedForDate;
  bool _laedtNeu = false;

  /// Alle Tourenplan-Quellen frisch vom Server holen — Pull-to-Refresh im
  /// Fällig-Tab und Aktualisieren-Knopf in der AppBar. Ein Fehler wird
  /// gemeldet, nie verschluckt (Regel «still fehlgeschlagen», 11.08.2026).
  Future<void> _datenNeuLaden() async {
    if (_laedtNeu) return;
    setState(() => _laedtNeu = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await tourenplanNeuLaden(ProviderScope.containerOf(context));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Aktualisieren fehlgeschlagen: ${kurzeFehlermeldung(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _laedtNeu = false);
    }
  }

  bool get _istVergangenerTag {
    final j = DateTime.now();
    final heute = DateTime(j.year, j.month, j.day);
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).isBefore(heute);
  }

  @override
  void initState() {
    super.initState();
    final start = widget.startDatum ?? DateTime.now();
    _selectedDate = DateTime(start.year, start.month, start.day);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Wochenrechnung in Kalendertagen (`wochenStart`/`wochePlus`), nie mit
  // `Duration(days: …)`: über die Zeitumstellung landete «Nächste Woche» ab
  // Mo 19.10.2026 auf So 25.10. 23:00 (Review 26.09.2026).
  DateTime get _weekStart => wochenStart(_selectedDate);

  void _changeWeek(int delta) {
    setState(() {
      _selectedDate = wochePlus(_selectedDate, delta);
      _loadedForDate = null;
    });
  }

  /// [day] wird auf Mitternacht gesetzt — «Zur heutigen Woche» reicht
  /// `DateTime.now()` mit Uhrzeit herein. Mit Uhrzeit wäre `_selectedDate`
  /// ein anderer Schlüssel für `gespeicherterTagesplanProvider` als der
  /// Kalendertag, den alle anderen Stellen invalidieren.
  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = DateTime(day.year, day.month, day.day);
      _loadedForDate = null;
    });
  }

  /// Liegen beide Daten in derselben Kalenderwoche?
  bool _gleicheWoche(DateTime a, DateTime b) =>
      gleicherTag(wochenStart(a), wochenStart(b));

  @override
  Widget build(BuildContext context) {
    ref.read(aktiverTagesplanTagProvider.notifier).state = _selectedDate;

    final regionen = ref.watch(regionenProvider);
    final selectedRegionen = ref.watch(selectedRegionenProvider);
    final selectedFaelligkeit = ref.watch(selectedFaelligkeitProvider);
    final tagesplan = ref.watch(tagesplanProvider);
    final dayCounts = ref.watch(tagesCountsProvider(_weekStart));
    final faelligeEintraege = ref.watch(
      faelligeEintraegeProvider(_selectedDate),
    );
    // Bestätigte Saison-Termine + Auto-Vorschläge — erscheinen auch an
    // einem Schliessungstag (Fall Löwen Grossdietwil, 04.08.2026).
    final autoTermine = ref.watch(saisonTermineFuerTagProvider(_selectedDate));

    // Reaktives Laden: gespeicherter Plan hat Vorrang vor Vorschlag.
    final gespeichertAsync = ref.watch(
      gespeicherterTagesplanProvider(_selectedDate),
    );
    // Zweite Instanz: Eine Aufgabe mit `/touren?datum=B` öffnet per
    // `router.push` eine zweite Tourenplanung, die B in den EINEN globalen
    // `tagesplanProvider` lädt. Nach dem Zurück stand hier `_loadedForDate`
    // noch auf A, geladen wurde nicht neu, `gehoertZu(A)` blieb falsch — der
    // Ladekreis drehte ohne Ende (Review 26.09.2026). Gehört der Plan nicht
    // (mehr) zu diesem Tag, also neu übernehmen — aber nur als oberste
    // Route, sonst holten sich zwei Instanzen den Plan gegenseitig weg.
    // `ModalRoute.of` baut nach dem Zurück neu auf.
    final aufTag = ref
        .read(tagesplanProvider.notifier)
        .gehoertZu(_selectedDate);
    if (!aufTag && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _loadedForDate = null;
    }
    if (_loadedForDate != _selectedDate) {
      final tag = _selectedDate;
      void anwenden(GespeicherterTagesplan? gespeichert) {
        _loadedForDate = tag;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Arbeitstag-Rahmen übernehmen: liegt eine Zeile vor, ist sie für
          // Ende und km-Stand massgebend (auch leer — sonst käme ein gerade
          // gelöschter Wert beim nächsten Öffnen wieder). Nur beim Beginn
          // bleibt der Standard 06:00 stehen, wenn nichts gepflegt ist.
          if (gespeichert != null) {
            final aktuell = ref.read(arbeitstagProvider(tag));
            ref.read(arbeitstagProvider(tag).notifier).state = (
              // Ist vor Plan vor Standard — siehe Zeitachse weiter unten.
              beginn:
                  gespeichert.arbeitsbeginn ??
                  gespeichert.planBeginn ??
                  aktuell.beginn,
              ende: gespeichert.arbeitsende,
              km: gespeichert.kmStand,
              kmStart: gespeichert.kmStart,
              lat: gespeichert.startLat,
              lng: gespeichert.startLng,
              endLat: gespeichert.endLat,
              endLng: gespeichert.endLng,
              pauseMinuten: gespeichert.pauseMinuten,
              pauseStart: gespeichert.pauseStart,
            );
          }
          final notifier = ref.read(tagesplanProvider.notifier);
          // Race-Schutz: hat der User diesen Tag inzwischen bereits bearbeitet,
          // seinen Stand NICHT mit dem (evtl. älteren) Lade-Fetch überschreiben.
          if (notifier.datum == tag) return;
          if (gespeichert != null) {
            notifier.setFromGespeichert(tag, gespeichert.eintraege);
          } else {
            notifier.resetLeer(tag);
          }
        });
      }

      gespeichertAsync.when(
        data: (gespeichert) {
          if (_loadedForDate != tag) anwenden(gespeichert);
        },
        loading: () {},
        // Ladefehler ist NICHT «kein Plan»: kein resetLeer — sonst startete
        // der Tag leer, und die nächste Änderung überschriebe den echten
        // Plan in der DB (Review 26.09.2026). Der Tab zeigt den Fehler mit
        // «Erneut laden»; bis dahin bleiben die Plan-Aktionen gesperrt.
        error: (_, _) {},
      );
    }

    // Filter (Region + Fälligkeit) — nur für die „Fällig"-Liste (Auswahl,
    // was in den Plan übernommen wird).
    bool passesFilter(TourEintrag e) {
      // Region-Filter
      if (selectedRegionen.isNotEmpty &&
          e.regionId != null &&
          !selectedRegionen.contains(e.regionId)) {
        return false;
      }
      // Fälligkeits-Filter (überfällig/fällig/bald fällig/Saison/Alle) gilt
      // nur für Reinigungen — Störungen/Montagen kennen keine Fälligkeits-
      // Stufen. Ihr Datumsfilter läuft separat: `faelligeEintraegeProvider`
      // lässt sie nur an ihrem geplanten Tag durch (oder immer, solange sie
      // ungeplant/überfällig sind — Migration 163, `einsatz_faellig.dart`).
      if (selectedFaelligkeit.isNotEmpty && e.typ == TourEintragTyp.reinigung) {
        if (e.faelligkeit == null ||
            !sichtbarImTourfilter(e.faelligkeit!, selectedFaelligkeit)) {
          return false;
        }
      }
      return true;
    }

    // Tagesplan: KEIN Filter — zeigt den vollständigen Plan in EXAKT der
    // Eingabe-/manuellen Reihenfolge. Ein Filter würde die Anzeige-Indizes
    // gegenüber dem State verschieben → Drag-Reorder träfe die falschen
    // Einträge und die Reihenfolge ginge kaputt.
    //
    // VERGANGENE Tage zeigen nicht den (Test-)Plan, sondern die tatsächlich
    // abgeschlossenen Reinigungen des Tages — Pläne von gestern sind nicht
    // mehr relevant, nur was wirklich geschah (Daniel 31.07.2026).
    //
    // Dasselbe gilt, sobald der HEUTIGE Tag mit «Feierabend» abgeschlossen
    // ist: dann ist der Tag Geschichte, und der Rest-Plan «ab jetzt» wäre nur
    // noch irreführend (Daniel 31.07.2026: «es ist Feierabend, dann kannst du
    // den Tag mit den realen Daten anzeigen»).
    final feierabendErfasst =
        ref
            .watch(gespeicherterTagesplanProvider(_selectedDate))
            .valueOrNull
            ?.arbeitsende !=
        null;
    final istVergangenTag = _istVergangenerTag || feierabendErfasst;
    final angezeigtTagesplan = istVergangenTag
        ? ref.watch(tatsaechlicheReinigungenAlsEintraegeProvider(_selectedDate))
        : tagesplan;
    final angezeigtFaellig = faelligeEintraege.where(passesFilter).toList();

    // Lade-Fenster: Der Kopf zeigt den neuen Tag sofort, der Notifier hält
    // aber bis zum Eintreffen des Plans noch den des vorigen Tages. Solange
    // bleiben Zeitachse und Plan-Aktionen gesperrt (Review 26.09.2026).
    // `ref.watch(tagesplanProvider)` oben baut neu, sobald der Plan kommt.
    final planGehoertZumTag = ref
        .read(tagesplanProvider.notifier)
        .gehoertZu(_selectedDate);
    final ansicht = tagesplanAnsicht(
      nurIst: istVergangenTag,
      planGehoertZumTag: planGehoertZumTag,
      ladefehler: gespeichertAsync.hasError && !gespeichertAsync.isLoading,
    );

    final bereitsImPlan = planGehoertZumTag
        ? tagesplan.map((e) => e.id).toSet()
        : const <String>{};

    return Scaffold(
      appBar: AppBar(
        // Der Titel trägt die Woche, seit die Leiste darunter nur noch die
        // Tage zeigt (B5). «Tourenplanung» sagte nichts, was die
        // Navigationsleiste nicht schon zeigt.
        title: Text(wochenTitel(_weekStart)),
        actions: [
          // Zurück zur laufenden Woche. Wer ein paar Wochen vorausgeblättert
          // hat, kam bisher nur über die Pfeile zurück.
          if (!_gleicheWoche(_selectedDate, DateTime.now()))
            IconButton(
              tooltip: 'Zur heutigen Woche',
              onPressed: () => _selectDay(DateTime.now()),
              icon: const Icon(Icons.today),
            ),
          // Aktualisieren — für den PC, wo es keine Zieh-Geste gibt.
          IconButton(
            tooltip: 'Daten neu laden',
            onPressed: _laedtNeu ? null : _datenNeuLaden,
            icon: _laedtNeu
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          // Region-Filter oben rechts (kompakter Mehrfach-Dropdown)
          if (regionen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AppFilterMultiDropdown<String>(
                label: 'Regionen',
                options: [for (final r in regionen) (r.routeId, r.name)],
                selected: selectedRegionen,
                onChanged: (updated) {
                  ref.read(selectedRegionenProvider.notifier).state = updated;
                },
              ).build(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Wochenwechsel und Tageswahl in EINER Zeile (B5, v0.113.0) — die
          // Woche steht im AppBar-Titel. Vorher zwei Zeilen à rund 130 px
          // zusammen, die der Zeitachse fehlten.
          WochenLeiste(
            weekStart: _weekStart,
            selectedDate: _selectedDate,
            counts: dayCounts,
            onPrevious: () => _changeWeek(-1),
            onNext: () => _changeWeek(1),
            onSelect: _selectDay,
          ),

          const Divider(height: 1),

          // TabBar
          TabBar(
            controller: _tabController,
            tabs: [
              // Im Lade-Fenster keine Zahl — es wäre die des vorigen Tages.
              Tab(
                text: ansicht == TagesplanAnsicht.plan
                    ? 'Tagesplan (${angezeigtTagesplan.length})'
                    : 'Tagesplan',
              ),
              Tab(text: 'Fällig (${angezeigtFaellig.length})'),
            ],
          ),

          // Inline-Filter Fälligkeit (einzeilig, ohne Label — Region: AppBar)
          TourFilterLeiste(
            ausgewaehlt: selectedFaelligkeit,
            onChanged: (updated) {
              ref.read(selectedFaelligkeitProvider.notifier).state = updated;
            },
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // === Tab 1: Tagesplan ===
                Column(
                  children: [
                    _TagesplanHeader(
                      datum: _selectedDate,
                      readOnly: istVergangenTag,
                      gesperrt: !planGehoertZumTag,
                      onLeeren: _tagesplanLeeren,
                      onTagVerschieben: _ganzenTagVerschieben,
                      onAusFaelligBefuellen: () =>
                          _faelligeAlleUebernehmen(angezeigtFaellig),
                      onPlanUebernehmen: _planVonDatumUebernehmen,
                      onOptimieren: _reihenfolgeOptimieren,
                      // Route statt Navigator.push (T11): zählt im
                      // Nutzungszähler mit, Datum als Query-Parameter.
                      onKarte: () => context.push(
                        '/touren/karte?datum=${_selectedDate.toIso8601String().substring(0, 10)}',
                      ),
                    ),
                    _ArbeitstagZeile(datum: _selectedDate),
                    if (autoTermine.isNotEmpty)
                      SaisonTermineSektion(
                        eintraege: autoTermine,
                        onUebernehmen: (e) {
                          if (!_planBereit()) return;
                          ref
                              .read(tagesplanProvider.notifier)
                              .hinzufuegen(e.alsPlanEintrag());
                        },
                        onAlleUebernehmen: () {
                          if (!_planBereit()) return;
                          final notifier = ref.read(tagesplanProvider.notifier);
                          for (final e in autoTermine) {
                            notifier.hinzufuegen(e.alsPlanEintrag());
                          }
                        },
                        onTap: _navigateToDetail,
                      ),
                    Expanded(
                      child: ansicht == TagesplanAnsicht.laedt
                          ? _planLaedtHinweis()
                          : ansicht == TagesplanAnsicht.ladefehler
                          ? _planLadefehler(gespeichertAsync.error)
                          : angezeigtTagesplan.isEmpty
                          ? _buildEmpty(
                              istVergangenTag
                                  ? 'Keine Reinigungen'
                                  : 'Kein Tagesplan',
                              istVergangenTag
                                  ? 'An diesem Tag wurden keine\nReinigungen abgeschlossen.'
                                  : 'Wechsle zum Tab "Fällig" um Einträge\nzum Tagesplan hinzuzufügen.',
                            )
                          : _TagesplanZeitachse(
                              datum: _selectedDate,
                              eintraege: angezeigtTagesplan,
                              readOnly: istVergangenTag,
                              onReorder: istVergangenTag
                                  ? (old, neu) {}
                                  : (old, neu) => ref
                                        .read(tagesplanProvider.notifier)
                                        .reorder(old, neu),
                              onDismiss: istVergangenTag
                                  ? (id) {}
                                  : (id) => ref
                                        .read(tagesplanProvider.notifier)
                                        .entfernen(id),
                              onVerschieben: istVergangenTag
                                  ? null
                                  : _stoppVerschieben,
                            ),
                    ),
                  ],
                ),

                // === Tab 2: Fällig ===
                Column(
                  children: [
                    _warnungSaisonAnker(),
                    _warnungSaisonLuecke(),
                    Expanded(
                      // Pull-to-Refresh: auch der Leerzustand ist ziehbar —
                      // gerade eine (veraltet) leere Liste braucht den Weg
                      // zu frischen Daten.
                      child: RefreshIndicator(
                        onRefresh: _datenNeuLaden,
                        child: angezeigtFaellig.isEmpty
                            ? LayoutBuilder(
                                builder: (context, constraints) => ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: constraints.maxHeight,
                                      child: _buildEmpty(
                                        'Keine fälligen Einträge',
                                        'Zum ${_formatDate(_selectedDate)} sind keine\nReinigungen, Störungen oder Montagen fällig.',
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                itemCount: angezeigtFaellig.length,
                                itemBuilder: (_, i) {
                                  final e = angezeigtFaellig[i];
                                  final imPlan = bereitsImPlan.contains(e.id);
                                  return _FaelligEintragKarte(
                                    datum: _selectedDate,
                                    eintrag: e,
                                    imPlan: imPlan,
                                    onAdd: () => _faelligEintragUebernehmen(e),
                                    onTap: () => _navigateToDetail(e),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Saisonbetriebe, deren Saison-Angabe sie dauerhaft aus dem Plan wirft.
  ///
  /// Rot statt gelb: Ein Betrieb ohne Startdatum taucht nach seinem Enddatum
  /// nie wieder auf — das fällt erst auf, wenn der Kunde anruft. Am
  /// 20.09.2026 waren 25 von 96 operativen Saisonbetrieben betroffen.
  Widget _warnungSaisonLuecke() {
    final luecken = ref.watch(saisonLueckenProvider);
    if (luecken.isEmpty) return const SizedBox.shrink();
    final heute = DateTime.now();
    // Wie viele fallen demnächst wirklich heraus? Bei den übrigen fehlt die
    // Pause — falsch, aber nicht dringend (Korrektur 20.09.2026: vorher stand
    // hier «bereits weg», obwohl keiner draussen war).
    final fallenRaus = luecken.where((b) => saisonDeckungBis(b) != null).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${luecken.length} Betriebe mit Saison-Lücke'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in luecken)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.ort != null && b.ort!.isNotEmpty
                                  ? '${b.name}, ${b.ort}'
                                  : b.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${saisonLuecken(b).map((l) => l.kurz).join(' · ')}'
                              ' — ${saisonLueckeWirkung(b, heute)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ein Saisonfenster ohne Startdatum gilt nur «bis zum '
                      'Ende» — danach erscheint der Betrieb nie wieder im '
                      'Tourenplan. Dasselbe gilt, wenn weder Winter noch '
                      'Sommer angehakt ist. Beim Betrieb Start (und Ende) '
                      'der Saison eintragen.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Schliessen'),
              ),
              TapKnopf(
                text: 'Saisondaten nachtragen',
                icon: Icons.edit_calendar,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/betriebe/saisondaten');
                },
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(30),
            border: Border.all(color: AppColors.error.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.visibility_off,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fallenRaus > 0
                      ? '${luecken.length} Saisonbetriebe mit Lücke — '
                            '$fallenRaus fallen aus dem Plan'
                      : '${luecken.length} Saisonbetriebe: Saisonfenster ohne '
                            'Startdatum',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.error, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _warnungSaisonAnker() {
    final fehlt = ref.watch(saisonAnkerFehltProvider);
    if (fehlt.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${fehlt.length} Betriebe ohne Saisonstart'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Text(
                  '${fehlt.map((b) => b.ort != null && b.ort!.isNotEmpty ? '${b.name} ${b.ort}' : b.name).join('\n')}\n\n'
                  'Endreinigung erledigt, aber kein künftiger Saisonstart/'
                  'Ferien-Ende gepflegt — die Fälligkeits-Uhr kann nicht starten. '
                  'Bitte Saisondaten im Betrieb ergänzen.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Schliessen'),
              ),
              TapKnopf(
                text: 'Saisondaten nachtragen',
                icon: Icons.edit_calendar,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/betriebe/saisondaten');
                },
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(30),
            border: Border.all(color: AppColors.warning.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_busy, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${fehlt.length} Betriebe: Endreinigung ohne Saisonstart — Uhr kann nicht starten',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.warning,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
              size: 64,
              color: AppColors.textSecondary.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// Statt der Zeitachse, solange der Plan des Tages noch unterwegs ist —
  /// die Zeitachse zeigte in diesem Fenster den Plan des vorigen Tages.
  Widget _planLaedtHinweis() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Plan wird geladen…',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Der Plan liess sich nicht laden. Bewusst kein leerer Plan: dessen
  /// nächste Änderung würde den echten Plan in der DB überschreiben.
  Widget _planLadefehler(Object? fehler) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'Plan konnte nicht geladen werden',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (fehler != null) ...[
              const SizedBox(height: 6),
              Text(
                kurzeFehlermeldung(fehler),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TapKnopf(
              text: 'Erneut laden',
              icon: Icons.refresh,
              onTap: () => ref.invalidate(
                gespeicherterTagesplanProvider(_selectedDate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Plan-Aktionen nur, wenn der In-Memory-Plan dem angezeigten Tag gehört
  /// ([TagesplanNotifier.gehoertZu]) — sonst landeten sie im Plan des
  /// vorigen Tages. Meldet sich kurz, statt wortlos nichts zu tun.
  bool _planBereit() {
    if (ref.read(tagesplanProvider.notifier).gehoertZu(_selectedDate)) {
      return true;
    }
    final laden = ref.read(gespeicherterTagesplanProvider(_selectedDate));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          laden.hasError && !laden.isLoading
              ? 'Plan konnte nicht geladen werden — zuerst «Erneut laden»'
              : 'Plan wird noch geladen — bitte gleich nochmals',
        ),
      ),
    );
    return false;
  }

  /// Nach einem Dialog bzw. Warten: Zeigt der Screen noch [plantag], und
  /// gehört ihm der Plan noch? Sonst abbrechen — Verschieben/Leeren träfen
  /// sonst den Plan eines anderen Tages.
  bool _planNochAufTag(DateTime plantag) {
    if (gleicherTag(_selectedDate, plantag) &&
        ref.read(tagesplanProvider.notifier).gehoertZu(plantag)) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan hat gewechselt — bitte erneut')),
    );
    return false;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Fällig-Tab „in den Plan"-Aktion: bündelt Reinigungen beim selben
  /// Betrieb statt einen zweiten Besuchs-Block anzulegen (Spec §1). Die
  /// heute fälligen Geschwister-Anlagen des Betriebs kommen bewusst aus
  /// `faelligeAnlagenProvider`, NICHT aus der (evtl. gefilterten)
  /// Fällig-Eintragsliste: seit v0.54.17 lässt der «Alle»-Filter dort auch
  /// nicht fällige Anlagen durch — Spec §1 verlangt aber ausdrücklich nur
  /// die heute FÄLLIGEN Geschwister (Review 29.07.2026).
  void _faelligEintragUebernehmen(TourEintrag eintrag) {
    if (!_planBereit()) return;
    final notifier = ref.read(tagesplanProvider.notifier);
    final planVorher = ref.read(tagesplanProvider);
    final betriebId = eintrag.betriebId;
    final faelligeGeschwister = betriebId == null
        ? const <String>[]
        : faelligeAnlagenRouteIdsFuerBetrieb(
            ref.read(faelligeAnlagenProvider(_selectedDate)),
            betriebId,
          );

    final neuerPlan = buendleInPlan(
      plan: planVorher,
      neu: eintrag,
      faelligeAnlagenDesBetriebs: faelligeGeschwister,
    );
    // Gleiche Länge wie vorher = in bestehenden Besuch gebündelt (kein neuer
    // Eintrag angehängt) — das ist der Fall, der ohne Hinweis unbemerkt
    // bliebe (der neue Block wäre ja sonst sichtbar im Tagesplan-Tab).
    final wurdeGebuendelt = neuerPlan.length == planVorher.length;
    notifier.setzePlan(neuerPlan);

    if (wurdeGebuendelt && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('Anlage zu ${eintrag.betriebName} hinzugefügt'),
        ),
      );
    }
  }

  /// «Fällige übernehmen» (Bulk): wie das einzelne Übernehmen je Eintrag über
  /// [buendleInPlan] — ein Betrieb mit mehreren fälligen Anlagen wird EIN
  /// Besuchs-Block mit allen Anlagen, statt ein Block pro Anlage (das rohe
  /// Anhängen der Fällig-Einträge liess die Bündelung aus — Sunset-Fall,
  /// 31.07.2026).
  void _faelligeAlleUebernehmen(List<TourEintrag> faellige) {
    if (!_planBereit()) return;
    var plan = ref.read(tagesplanProvider);
    final vorhandene = plan.map((e) => e.id).toSet();
    final faelligeAnlagen = ref.read(faelligeAnlagenProvider(_selectedDate));
    for (final e in faellige) {
      if (vorhandene.contains(e.id)) continue;
      final geschwister =
          (e.typ == TourEintragTyp.reinigung && e.betriebId != null)
          ? faelligeAnlagenRouteIdsFuerBetrieb(faelligeAnlagen, e.betriebId!)
          : const <String>[];
      plan = buendleInPlan(
        plan: plan,
        neu: e,
        faelligeAnlagenDesBetriebs: geschwister,
      );
    }
    ref.read(tagesplanProvider.notifier).setzePlan(plan);
  }

  /// «Reihenfolge optimieren»: ordnet die Besuche so, dass die Summe der
  /// Fahrzeiten (inkl. Anfahrt und Heimweg) möglichst klein wird.
  ///
  /// Einträge mit Termin-Anker bleiben, wo sie sind — sie sind mit dem Kunden
  /// abgemacht. Das Verfahren prüft auch die bestehende Reihenfolge und nimmt
  /// die bessere; es kann also nie verschlechtern (siehe
  /// `routen_optimierung.dart`).
  void _reihenfolgeOptimieren() {
    if (!_planBereit()) return;
    final plan = ref.read(tagesplanProvider);
    if (plan.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zu wenige Einträge zum Optimieren'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final lookup = ref.read(betriebLookupProvider);
    final fahrzeiten =
        ref.read(fahrzeitenMapProvider).valueOrNull ??
        const <String, FahrzeitEintrag>{};
    final byId = {for (final e in plan) e.id: e};

    int fahrzeit(String vonId, String nachId) {
      final v = byId[vonId]?.betriebId;
      final n = byId[nachId]?.betriebId;
      if (v == null || n == null) return _kFahrzeitOhneGps;
      if (v == n) return 0;
      final gelernt = FahrzeitRepository.ausMap(fahrzeiten, v, n);
      if (gelernt != null) return gelernt.minuten;
      final bv = lookup[v];
      final bn = lookup[n];
      if (bv?.latitude == null ||
          bv?.longitude == null ||
          bn?.latitude == null ||
          bn?.longitude == null) {
        return _kFahrzeitOhneGps;
      }
      return heuristikMinuten(
        luftlinieKm: haversineKm(
          bv!.latitude!,
          bv.longitude!,
          bn!.latitude!,
          bn.longitude!,
        ),
      );
    }

    // Anfahrt/Heimweg nur, wenn ein Startort bekannt ist — sonst würde die
    // Optimierung einen Tagesrand erfinden, den es nicht gibt.
    final arbeitstag = ref.read(arbeitstagProvider(_selectedDate));
    final tagesstart = (arbeitstag.lat != null && arbeitstag.lng != null)
        ? (lat: arbeitstag.lat!, lng: arbeitstag.lng!)
        : ref.read(startortProvider);
    final anfahrtTabelle = ref.read(anfahrtszeitenProvider).valueOrNull;
    final startKey = startortSchluessel(tagesstart);
    final gerechnet = (startKey == null || anfahrtTabelle == null)
        ? null
        : anfahrtTabelle[startKey];

    int? randMinuten(String blockId) {
      final betriebId = byId[blockId]?.betriebId;
      if (betriebId == null || tagesstart == null) return null;
      final fertig = gerechnet?[betriebId];
      if (fertig != null) return fertig;
      final b = lookup[betriebId];
      if (b?.latitude == null || b?.longitude == null) return null;
      return heuristikMinuten(
        luftlinieKm: haversineKm(
          tagesstart.lat,
          tagesstart.lng,
          b!.latitude!,
          b.longitude!,
        ),
        mitRuestzeit: false,
      );
    }

    final rand = tagesstart == null
        ? null
        : (String id) => randMinuten(id) ?? _kFahrzeitOhneGps;

    final ids = plan.map((e) => e.id).toList();
    final vorher = gesamtFahrzeit(
      reihenfolge: ids,
      fahrzeitZwischen: fahrzeit,
      anfahrtVomStart: rand,
      heimwegZumStart: rand,
    );
    final neu = optimiereReihenfolge(
      blockIds: ids,
      fahrzeitZwischen: fahrzeit,
      anfahrtVomStart: rand,
      heimwegZumStart: rand,
      // Termin-Anker sind mit dem Kunden abgemacht — unantastbar.
      fixiert: {
        for (final e in plan)
          if (e.ankerZeit != null) e.id,
      },
    );
    final nachher = gesamtFahrzeit(
      reihenfolge: neu,
      fahrzeitZwischen: fahrzeit,
      anfahrtVomStart: rand,
      heimwegZumStart: rand,
    );

    final ersparnis = vorher - nachher;
    if (ersparnis <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reihenfolge ist bereits optimal'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ref.read(tagesplanProvider.notifier).setzePlan([
      for (final id in neu) byId[id]!,
    ]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reihenfolge optimiert — $ersparnis min weniger Fahrzeit',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// «Leeren» wirft den ganzen Tagesplan weg und speichert sofort (Auto-Save
  /// im Provider) — ein Fehltipp in der engen Kopfzeile kostete bisher den
  /// ganzen Tag. Deshalb erst nachfragen (R6, 25.09.2026).
  Future<void> _tagesplanLeeren() async {
    final plantag = _selectedDate;
    if (!_planBereit()) return;
    final anzahl = ref.read(tagesplanProvider).length;
    if (anzahl == 0) return;
    final ok = await gefahrRueckfrage(
      context,
      titel: 'Tagesplan leeren?',
      text:
          'Alle $anzahl ${anzahl == 1 ? 'Eintrag wird' : 'Einträge werden'} '
          'aus dem Plan dieses Tages entfernt. Das lässt sich nicht '
          'rückgängig machen.',
      bestaetigen: 'Leeren',
    );
    if (!ok || !mounted) return;
    if (!_planNochAufTag(plantag)) return;
    ref.read(tagesplanProvider.notifier).leeren();
  }

  // ─── Verschieben auf einen anderen Tag (Daniel 26.09.2026) ───

  /// Zieltag wählen: ab heute bis in einem Jahr, vorbelegt mit dem Folgetag.
  /// `null` bei Abbruch oder wenn derselbe Tag gewählt wurde.
  Future<DateTime?> _zieltagWaehlen(DateTime plantag) async {
    final j = DateTime.now();
    final heute = DateTime(j.year, j.month, j.day);
    // Kalendertage statt `Duration(days: …)` — sonst frisst die Umstellung
    // der Sommerzeit einen Tag.
    final gewaehlt = await zeigeDatumsauswahl(
      context,
      initial: DateTime(plantag.year, plantag.month, plantag.day + 1),
      erstes: heute,
      letztes: DateTime(heute.year, heute.month, heute.day + 365),
      hilfetext: 'Auf welchen Tag verschieben?',
    );
    if (gewaehlt == null) return null;
    final ziel = DateTime(gewaehlt.year, gewaehlt.month, gewaehlt.day);
    if (gleicherTag(ziel, plantag)) return null;
    return ziel;
  }

  /// Rückfrage mit «Verschieben»/«Abbrechen» — kein Gefahr-Rot, denn das
  /// Verschieben ist nicht destruktiv und lässt sich zurückschieben.
  Future<bool> _verschiebenBestaetigen({
    required String titel,
    required String text,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titel),
        content: Text(text),
        actions: [
          TapKnopf(
            text: 'Abbrechen',
            primaer: false,
            onTap: () => Navigator.pop(ctx, false),
          ),
          TapKnopf(
            text: 'Verschieben',
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Block-Sheet «Auf anderen Tag verschieben»: ein einzelner Stopp, ohne
  /// Rückfrage — ausser der Betrieb hat am Zieltag Ruhetag.
  Future<void> _stoppVerschieben(String eintragId) async {
    final plantag = _selectedDate;
    // Gehört der Plan noch dem vorigen Tag, hinge dessen Stopp am Zieltag an
    // und würde hier (im Plan von [plantag]) nicht entfernt — doppelt.
    if (!_planBereit()) return;
    final treffer = ref
        .read(tagesplanProvider)
        .where((e) => e.id == eintragId);
    if (treffer.isEmpty) return;
    final eintrag = treffer.first;
    final ziel = await _zieltagWaehlen(plantag);
    if (ziel == null || !mounted) return;
    if (istRuhetag(eintrag.ruhetage, ziel)) {
      final ok = await _verschiebenBestaetigen(
        titel: 'Ruhetag',
        text: ruhetagHinweisText(eintrag.betriebName, ziel),
      );
      if (!ok || !mounted) return;
    }
    if (!_planNochAufTag(plantag)) return;
    await _aufTagVerschieben(plantag, [eintrag], ziel);
  }

  /// Kopfzeilen-Menü «Ganzen Tag verschieben…»: alle offenen Stopps auf
  /// einen anderen Tag. Hier bleiben: erledigte (dieselbe Ermittlung wie die
  /// Zeitachse, dazu abgeschlossene Einsätze) und abgemachte Saison-Termine
  /// ([terminEintragIds]). Der Arbeitstag-Rahmen (Beginn/Ende/km) bleibt
  /// unberührt.
  Future<void> _ganzenTagVerschieben() async {
    final plantag = _selectedDate;
    // Siehe _stoppVerschieben: im Lade-Fenster wäre `plan` der des vorigen
    // Tages.
    if (!_planBereit()) return;
    final plan = ref.read(tagesplanProvider);
    final messenger = ScaffoldMessenger.of(context);

    final j = DateTime.now();
    final heute = DateTime(j.year, j.month, j.day);
    final erledigtePruefen = !plantag.isAfter(heute);
    var wegpunkte = const <WegpunktTag>[];
    if (erledigtePruefen) {
      try {
        wegpunkte = await ref.read(wegpunkteFuerTagProvider(plantag).future);
      } catch (_) {
        // Ohne Stempel gelten Störungen/Montagen als offen — sie gehen dann
        // mit, was sich zurückschieben lässt.
      }
      if (!mounted) return;
    }
    // Termine: ohne sie gingen abgemachte Saison-Termine mit, deren Datum
    // und Kalender-Ereignis am alten Tag blieben — lieber abbrechen.
    final List<TerminDto> termine;
    try {
      termine = await ref.read(offeneTermineProvider.future);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Termine nicht geladen — Verschieben abgebrochen '
            '(${kurzeFehlermeldung(e)})',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final historie = ref.read(besuchHistorieProvider);
    final erledigt = {
      ...ermittleIstZeiten(
        eintraege: plan,
        datum: plantag,
        erledigtePruefen: erledigtePruefen,
        reinigungen: erledigtePruefen
            ? ref.read(reinigungenProvider)
            : const <ReinigungLocal>[],
        wegpunkte: wegpunkte,
        dauerFuer: (e) => _dauerFuer(e, historie),
      ).keys,
      ...abgeschlosseneEinsatzEintragIds(
        plan,
        ref.read(einsatzStatusJePlanIdProvider),
      ),
    };
    final lookup = ref.read(betriebLookupProvider);
    final aufteilung = tagesplanAufteilen(
      plan,
      erledigtIds: erledigt,
      terminIds: terminEintragIds(
        plan,
        termine,
        plantag,
        betriebSchluessel: (id) => lookup[id]?.routeId ?? id,
      ),
    );
    final verschiebbar = aufteilung.mit;
    if (verschiebbar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nichts zu verschieben')),
      );
      return;
    }

    final ziel = await _zieltagWaehlen(plantag);
    if (ziel == null || !mounted) return;
    // `refresh` statt `read`: der Cache des Zieltags kann veraltet sein
    // (z. B. auf einem anderen Gerät geändert) — die Rückfrage soll die
    // wirkliche Zahl nennen. Ein Ladefehler bricht ab, statt «0 Einträge
    // dort» zu behaupten.
    final int schonDort;
    try {
      schonDort =
          (await ref.refresh(
            gespeicherterTagesplanProvider(ziel).future,
          ))?.eintraege.length ??
          0;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Plan vom ${kurzTag(ziel)} nicht geladen — Verschieben '
            'abgebrochen (${kurzeFehlermeldung(e)})',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final ok = await _verschiebenBestaetigen(
      titel: 'Tag verschieben?',
      text: verschiebenRueckfrageText(
        anzahl: verschiebbar.length,
        ziel: ziel,
        schonDort: schonDort,
        ruhetag: ruhetagBetriebe(verschiebbar, ziel),
        erledigt: aufteilung.erledigt,
        termine: aufteilung.termine,
      ),
    );
    if (!ok || !mounted) return;
    // Zwischen dem Lesen von `plan` und hier lagen mehrere Wartezeiten, in
    // denen die Wochenleiste bedienbar war.
    if (!_planNochAufTag(plantag)) return;
    await _aufTagVerschieben(plantag, verschiebbar, ziel);
  }

  /// Sperrt den Screen, solange [arbeit] läuft: ein Ladekreis, der sich
  /// weder per Tipp daneben noch per Zurück schliessen lässt.
  ///
  /// Warum (Review 26.09.2026): Das Verschieben braucht 0,5–3 s. Tippte
  /// Daniel währenddessen den Zieltag in der Wochenleiste an, lud der
  /// Notifier dessen alten Stand und überschrieb später das Angehängte — die
  /// Stopps stünden an keinem Tag mehr.
  ///
  /// Die Route wird selbst gebaut und am Ende gezielt entfernt statt per
  /// `pop`: so trifft das Schliessen sicher den Sperr-Dialog (und nie den
  /// Screen) — auch wenn die Arbeit vor dem ersten Frame endet oder der
  /// Screen inzwischen weg ist (dann bliebe die App sonst gesperrt).
  Future<T> _mitSperre<T>(Future<T> Function() arbeit) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final sperre = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    unawaited(navigator.push(sperre));
    try {
      return await arbeit();
    } finally {
      if (sperre.isActive) navigator.removeRoute(sperre);
    }
  }

  /// Gemeinsamer Ablauf für Stopp und ganzen Tag. Reihenfolge bewusst:
  /// Einsätze umplanen, **dann** am Zieltag anhängen, **erst danach** hier
  /// entfernen — bricht ein Schritt ab, steht nichts verloren da. Die
  /// Fehlermeldung sagt, wie weit es kam ([verschiebenFehlerText]).
  Future<void> _aufTagVerschieben(
    DateTime plantag,
    List<TourEintrag> eintraege,
    DateTime ziel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var einsaetzeUmgeplant = 0;
    var angehaengt = false;
    try {
      await _mitSperre(() async {
        einsaetzeUmgeplant = await _einsaetzeAufTagUmplanen(
          ref,
          eintraege,
          ziel,
        );
        await eintraegeInTagesplanAnhaengen(ref, ziel, [
          for (final e in eintraege) _alsVerschobenerEintrag(e, ziel),
        ]);
        angehaengt = true;
        await eintraegeAusTagesplanEntfernen(ref, plantag, {
          for (final e in eintraege) e.id,
        });
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            verschiebenFehlerText(
              fehler: kurzeFehlermeldung(e),
              ziel: ziel,
              angehaengt: angehaengt,
              einsaetzeUmgeplant: einsaetzeUmgeplant,
            ),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(verschobenText(eintraege.length, ziel)),
        duration: const Duration(seconds: 5),
        // Im selben Screen auf den Zieltag wechseln statt eine zweite
        // Tourenplanung zu öffnen: beide teilen sich den einen
        // `tagesplanProvider` — nach dem Zurück zeigte die erste sonst den
        // Plan des Zieltags unter dem alten Datum (und speicherte ihn dort).
        action: SnackBarAction(
          label: 'Anzeigen',
          onPressed: () {
            if (mounted) _selectDay(ziel);
          },
        ),
      ),
    );
  }

  /// Menüpunkt „Reinigungen eines Tages übernehmen": die TATSÄCHLICH
  /// abgeschlossenen Reinigungen des Quelltags (ohne Störungen/Montagen) in
  /// ihrer echten Reihenfolge an den aktuellen Plan anhängen — nicht den
  /// damals gespeicherten Plan (Daniel 31.07.2026: vergangene Pläne sind
  /// nicht mehr relevant, nur die tatsächlichen Tagesdaten).
  /// Betriebe, die im Zielplan schon einen Reinigungs-Besuch haben, werden
  /// nicht dupliziert; Besuche, deren Betrieb heute keine fällige Anlage
  /// hat, kommen als `uebernommen = true` (graue Darstellung) mit.
  Future<void> _planVonDatumUebernehmen() async {
    final plantag = _selectedDate;
    if (!_planBereit()) return;
    final heuteReal = DateTime.now();
    final heuteDatum = DateTime(heuteReal.year, heuteReal.month, heuteReal.day);
    final gewaehlt = await zeigeDatumsauswahl(
      context,
      initial: heuteDatum.subtract(const Duration(days: 1)),
      erstes: DateTime(2025, 1, 1),
      letztes: heuteDatum,
      hilfetext: 'Reinigungen von welchem Tag übernehmen?',
    );
    if (gewaehlt == null || !mounted) return;
    if (!_planNochAufTag(plantag)) return;
    final quelltag = DateTime(gewaehlt.year, gewaehlt.month, gewaehlt.day);

    final quellEintraege = ref.read(
      tatsaechlicheReinigungenAlsEintraegeProvider(quelltag),
    );
    if (quellEintraege.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Keine abgeschlossenen Reinigungen am ${_formatDate(quelltag)}',
          ),
        ),
      );
      return;
    }

    // Heute fällige Betriebe — massgebend für die „uebernommen"-Markierung.
    // Bewusst `faelligeAnlagenProvider`, NICHT `faelligeEintraegeProvider`:
    // letzterer folgt intern dem UI-Fällig-Filter — bei aktivem «Alle»-
    // Filter (seit v0.54.17) gälten dann ALLE Betriebe als „fällig" und kein
    // übernommener Besuch würde je grau markiert (Review 29.07.2026).
    final faelligeBetriebe = faelligeBetriebIds(
      ref.read(faelligeAnlagenProvider(_selectedDate)),
    );

    final planVorher = ref.read(tagesplanProvider);
    final vorhandeneBetriebe = {
      for (final e in planVorher)
        if (e.typ == TourEintragTyp.reinigung && e.betriebId != null)
          e.betriebId!,
    };
    final vorhandeneIds = planVorher.map((e) => e.id).toSet();

    final uebernahme = <TourEintrag>[];
    for (final original in quellEintraege) {
      final istReinigung = original.typ == TourEintragTyp.reinigung;
      if (istReinigung &&
          original.betriebId != null &&
          vorhandeneBetriebe.contains(original.betriebId)) {
        continue; // Betrieb hat im Zielplan schon einen Besuch
      }

      var eintrag = original.alsPlanEintrag();
      if (istReinigung) {
        final heuteFaellig =
            eintrag.betriebId != null &&
            faelligeBetriebe.contains(eintrag.betriebId);
        eintrag = eintrag.copyWith(uebernommen: !heuteFaellig);
        // Heute fällige Geschwister-Anlagen ergänzen: Altpläne tragen oft nur
        // die damalige Einzel-Anlage — ohne Ergänzung fehlt z.B. die zweite
        // Anlage eines Betriebs im Block (Sunset, 31.07.2026).
        if (eintrag.betriebId != null) {
          eintrag = ergaenzeFaelligeAnlagen(
            eintrag,
            faelligeAnlagenRouteIdsFuerBetrieb(
              ref.read(faelligeAnlagenProvider(_selectedDate)),
              eintrag.betriebId!,
            ),
          );
        }
      }
      // `hist_`-Marker ablegen: Er kennzeichnet die tatsächlichen Reinigungen
      // des QUELLTAGS — im heutigen Plan wäre er falsch (das Ist-Matching und
      // der Tap-Handler behandeln `hist_`-Einträge als Vergangenheit).
      if (eintrag.id.startsWith('hist_')) {
        eintrag = eintrag.mitId('u_${eintrag.id.substring(5)}');
      }
      // ID-Kollision (z.B. zweimalige Übernahme desselben Quelltags) →
      // eindeutig machen.
      if (vorhandeneIds.contains(eintrag.id)) {
        eintrag = eintrag.mitId(
          'u_${eintrag.id}_${quelltag.millisecondsSinceEpoch}',
        );
      }
      vorhandeneIds.add(eintrag.id);
      if (istReinigung && eintrag.betriebId != null) {
        vorhandeneBetriebe.add(eintrag.betriebId!);
      }
      uebernahme.add(eintrag);
    }

    ref.read(tagesplanProvider.notifier).setzePlan([
      ...planVorher,
      ...uebernahme,
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${uebernahme.length} Einträge übernommen')),
    );
  }

  void _navigateToDetail(TourEintrag eintrag) {
    switch (eintrag.typ) {
      case TourEintragTyp.reinigung:
        if (eintrag.anlageId != null) {
          context.push('/anlagen/${eintrag.anlageId}');
        }
        break;
      case TourEintragTyp.stoerung:
        final id = eintrag.id.substring(2);
        context.push('/stoerungen/$id');
        break;
      case TourEintragTyp.montage:
      case TourEintragTyp.heigenie:
        final id = eintrag.id.substring(2);
        context.push('/montagen/$id');
        break;
    }
  }
}

// ─── Tagesplan-Header ───

class _TagesplanHeader extends StatelessWidget {
  final DateTime datum;

  /// Vergangener Tag: zeigt die tatsächlichen Reinigungen — Plan-Aktionen
  /// (Übernehmen/Leeren) sind dort sinnlos und ausgeblendet.
  final bool readOnly;

  /// Plan des Tages noch nicht geladen (oder Ladefehler): Übernehmen, Menü
  /// mit Optimieren/Verschieben/Leeren gesperrt — sie träfen sonst den Plan
  /// des vorigen Tages ([TagesplanNotifier.gehoertZu]).
  final bool gesperrt;
  final VoidCallback onLeeren;
  final VoidCallback onTagVerschieben;
  final VoidCallback onAusFaelligBefuellen;
  final VoidCallback onPlanUebernehmen;
  final VoidCallback onKarte;
  final VoidCallback onOptimieren;

  const _TagesplanHeader({
    required this.datum,
    required this.readOnly,
    required this.gesperrt,
    required this.onLeeren,
    required this.onTagVerschieben,
    required this.onAusFaelligBefuellen,
    required this.onPlanUebernehmen,
    required this.onKarte,
    required this.onOptimieren,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EE, d. MMM', 'de_CH');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      child: Row(
        children: [
          Text(
            df.format(datum),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onKarte,
            icon: const Icon(Icons.map_outlined, size: 20),
            tooltip: 'Tag auf Karte',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          if (readOnly)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'tatsächliche Reinigungen',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else ...[
            TextButton.icon(
              onPressed: gesperrt ? null : onAusFaelligBefuellen,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text(
                'Fällige übernehmen',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            // Ein Menü statt vier Symbolen — die Kopfzeile muss auf 360 px
            // passen (mit vier Symbolen waren es rund 420 px, 26.09.2026).
            // Verschieben und Leeren fragen erst nach (_ganzenTagVerschieben,
            // _tagesplanLeeren); die rote Bestätigung fürs Leeren sitzt im
            // Dialog als TapKnopf(gefahr).
            PopupMenuButton<String>(
              enabled: !gesperrt,
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: 'Weitere Aktionen',
              padding: EdgeInsets.zero,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelected: (v) {
                if (v == 'optimieren') onOptimieren();
                if (v == 'uebernehmen') onPlanUebernehmen();
                if (v == 'verschieben') onTagVerschieben();
                if (v == 'leeren') onLeeren();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'optimieren',
                  child: Row(
                    children: [
                      Icon(Icons.auto_fix_high, size: 18),
                      SizedBox(width: 10),
                      Text('Reihenfolge optimieren'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'uebernehmen',
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18),
                      SizedBox(width: 10),
                      Text('Reinigungen eines Tages übernehmen…'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'verschieben',
                  child: Row(
                    children: [
                      Icon(Icons.event_repeat, size: 18),
                      SizedBox(width: 10),
                      Text('Ganzen Tag verschieben…'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'leeren',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text(
                        'Tagesplan leeren…',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Typ-Farben/-Symbole (geteilt von Fällig-Liste und Zeitachse) ───

Color _typColor(TourEintragTyp typ) {
  switch (typ) {
    case TourEintragTyp.reinigung:
      return AppColors.success;
    case TourEintragTyp.stoerung:
      return AppColors.error;
    case TourEintragTyp.montage:
      return AppColors.info;
    case TourEintragTyp.heigenie:
      return AppColors.warning;
  }
}

IconData _typIcon(TourEintragTyp typ) {
  switch (typ) {
    case TourEintragTyp.reinigung:
      return Icons.cleaning_services;
    case TourEintragTyp.stoerung:
      return Icons.warning_amber;
    case TourEintragTyp.montage:
      return Icons.construction;
    case TourEintragTyp.heigenie:
      return Icons.build;
  }
}

// ─── Zeitachse: Dauer- und Fahrzeit-Helfer ───

/// Anlagen dieses Besuchs. `anlageIds` ist fachlich führend; Alt-Einträge
/// tragen nur das einzelne `anlageId`.
List<String> _besuchsAnlagen(TourEintrag e) => e.anlageIds.isNotEmpty
    ? e.anlageIds
    : [if (e.anlageId != null) e.anlageId!];

/// Wirksame Dauer eines Plan-Eintrags: manuelle Übersteuerung hat Vorrang,
/// sonst die Median-Schätzung aus der Betriebs-Historie (Reinigung) bzw. der
/// Standardwert für Störung/Montage (Spec 2026-07-29 §2).
int _dauerFuer(TourEintrag e, Map<String, List<BesuchHistorie>> historie) {
  final manuell = e.dauerMinuten;
  if (manuell != null) return manuell;
  if (e.typ != TourEintragTyp.reinigung) return kDauerDefaultMinuten;
  final hist = e.betriebId != null
      ? (historie[e.betriebId!] ?? const <BesuchHistorie>[])
      : const <BesuchHistorie>[];
  final anlagen = _besuchsAnlagen(e).length;
  return geschaetzteDauer(
    historie: hist,
    anlagenZahl: anlagen == 0 ? 1 : anlagen,
  );
}

/// Fahrzeit, wenn zu mindestens einem der beiden Betriebe die Koordinaten
/// fehlen: nicht 0 (das würde eine Fahrt verschlucken) und nicht die
/// Heuristik (ohne GPS nicht berechenbar) — ein neutraler Ansatz, den die
/// erste beobachtete Fahrt später ersetzt.
const int _kFahrzeitOhneGps = 15;

// ─── Tagesplan als Zeitachse ───

class _TagesplanZeitachse extends ConsumerStatefulWidget {
  final DateTime datum;
  final List<TourEintrag> eintraege;

  /// Vergangener Tag mit tatsächlichen Reinigungen: kein Umsortieren, kein
  /// Entfernen, kein Block-Sheet — Tap öffnet direkt die Reinigung.
  final bool readOnly;
  final void Function(int, int) onReorder;
  final void Function(String) onDismiss;

  /// Block-Sheet «Auf anderen Tag verschieben» (null = nicht anbieten).
  final void Function(String eintragId)? onVerschieben;

  const _TagesplanZeitachse({
    required this.datum,
    required this.eintraege,
    this.readOnly = false,
    required this.onReorder,
    required this.onDismiss,
    this.onVerschieben,
  });

  @override
  ConsumerState<_TagesplanZeitachse> createState() =>
      _TagesplanZeitachseState();
}

class _TagesplanZeitachseState extends ConsumerState<_TagesplanZeitachse> {
  /// Bereits bei der Edge-Function angefragte Strecken — verhindert, dass
  /// jeder Rebuild dieselbe Route erneut anfordert.
  final Set<String> _routeAngefragt = {};

  /// Minutentakt des Live-Modus (nur am HEUTIGEN Tag): rueckt die
  /// Jetzt-Linie vor und holt frische Wegpunkte.
  Timer? _liveTimer;

  bool get _istHeute {
    final j = DateTime.now();
    return widget.datum.year == j.year &&
        widget.datum.month == j.month &&
        widget.datum.day == j.day;
  }

  bool get _istVergangen {
    final j = DateTime.now();
    final heute = DateTime(j.year, j.month, j.day);
    return DateTime(
      widget.datum.year,
      widget.datum.month,
      widget.datum.day,
    ).isBefore(heute);
  }

  @override
  void initState() {
    super.initState();
    _liveTimerAktualisieren();
  }

  @override
  void didUpdateWidget(covariant _TagesplanZeitachse alt) {
    super.didUpdateWidget(alt);
    if (alt.datum != widget.datum || alt.readOnly != widget.readOnly) {
      _liveTimerAktualisieren();
    }
  }

  void _liveTimerAktualisieren() {
    _liveTimer?.cancel();
    _liveTimer = null;
    // Nach dem Feierabend (readOnly) gibt es nichts mehr vorzurücken.
    if (!_istHeute || widget.readOnly) return;
    _liveTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      ref.invalidate(wegpunkteFuerTagProvider(widget.datum));
      setState(() {}); // Jetzt-Linie und Rest-Plan rücken mit der Uhr vor.
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(betriebLookupProvider);
    final historie = ref.watch(besuchHistorieProvider);
    final fahrzeiten =
        ref.watch(fahrzeitenMapProvider).valueOrNull ??
        const <String, FahrzeitEintrag>{};
    final arbeitstag = ref.watch(arbeitstagProvider(widget.datum));
    final anlagen = ref.watch(anlagenProvider);
    final startort = ref.watch(startortProvider);

    final eintraege = widget.eintraege;
    final byId = {for (final e in eintraege) e.id: e};

    // Nenner des Chips «n von m Anlagen»: aktive Anlagen je Betrieb.
    final anlagenJeBetrieb = <String, int>{};
    for (final a in anlagen) {
      if (a.status != 'aktiv') continue;
      final key = lookup[a.betriebId]?.routeId ?? a.betriebId;
      anlagenJeBetrieb[key] = (anlagenJeBetrieb[key] ?? 0) + 1;
    }

    // Quelle je Fahrt (für den Punkt an der Fahrt-Zeile) und die Paare ohne
    // gelernten/gerouteten Wert. Beides fällt beim Durchlaufen der Kaskade an,
    // die `berechneZeitplan` genau einmal je Übergang aufruft.
    final fahrtQuellen = <String, String>{};
    final fehlendePaare = <({String von, String nach})>[];

    int fahrzeitZwischen(String vonBlockId, String nachBlockId) {
      final vonBetrieb = byId[vonBlockId]?.betriebId;
      final nachBetrieb = byId[nachBlockId]?.betriebId;
      if (vonBetrieb == null || nachBetrieb == null) {
        fahrtQuellen[nachBlockId] = 'heuristik';
        return _kFahrzeitOhneGps;
      }
      // Zwei Einträge beim selben Betrieb (z.B. Reinigung + Störung): keine
      // Fahrt dazwischen.
      if (vonBetrieb == nachBetrieb) return 0;

      final gelernt = FahrzeitRepository.ausMap(
        fahrzeiten,
        vonBetrieb,
        nachBetrieb,
      );
      if (gelernt != null) {
        fahrtQuellen[nachBlockId] = gelernt.quelle;
        return gelernt.minuten;
      }

      fehlendePaare.add((von: vonBetrieb, nach: nachBetrieb));
      fahrtQuellen[nachBlockId] = 'heuristik';
      final bv = lookup[vonBetrieb];
      final bn = lookup[nachBetrieb];
      if (bv?.latitude != null &&
          bv?.longitude != null &&
          bn?.latitude != null &&
          bn?.longitude != null) {
        return heuristikMinuten(
          luftlinieKm: haversineKm(
            bv!.latitude!,
            bv.longitude!,
            bn!.latitude!,
            bn.longitude!,
          ),
        );
      }
      return _kFahrzeitOhneGps;
    }

    // Anfahrt/Heimweg ab Zuhause (Spec §3). Erste Wahl sind die gerechneten
    // Werte aus `anfahrtszeiten` (Google/OSRM, Migration 156/157) — die
    // Luftlinien-Heuristik lag bei Fernstrecken massiv daneben (Sonne
    // Seehotel Eich: 346 statt 117 min, Daniel 31.07.2026). Sie greift nur
    // noch, wenn für den Betrieb kein gerechneter Wert vorliegt.
    // Fehlt der Startort, oder hat der erste/letzte Eintrag keinen Betrieb
    // (z.B. eine freie Störung), entfällt das jeweilige Segment (null).
    int? anfahrtMinuten;
    int? heimwegMinuten;
    // Tagesstart-Position (GPS vom «Arbeitsbeginn»-Knopf) schlägt den festen
    // Startort: Daniel startet oft nicht von Zuhause (Domat/Ems), sondern
    // z.B. aus Chur. Der Heimweg zielt auf denselben Punkt — beste Annahme
    // ohne bekanntes Abend-Ziel.
    final tagesstart = (arbeitstag.lat != null && arbeitstag.lng != null)
        ? (lat: arbeitstag.lat!, lng: arbeitstag.lng!)
        : startort;
    // Gerechnete Werte des passenden Startorts (null, wenn der Tag weder in
    // Domat/Ems noch in Chur beginnt — dann bleibt nur die Heuristik).
    final anfahrtTabelle = ref.watch(anfahrtszeitenProvider).valueOrNull;
    final startortKey = startortSchluessel(tagesstart);
    final Map<String, int>? gerechneteAnfahrt =
        (startortKey == null || anfahrtTabelle == null)
        ? null
        : anfahrtTabelle[startortKey];

    if (tagesstart != null && eintraege.isNotEmpty) {
      final basis = tagesstart; // lokale, nicht-nullbare Kopie fürs Closure
      int? minutenAbStartort(BetriebLocal? betrieb, {required bool hin}) {
        final gerechnet = (betrieb == null || gerechneteAnfahrt == null)
            ? null
            : gerechneteAnfahrt[betrieb.serverId ?? betrieb.routeId];
        if (gerechnet != null) return gerechnet;
        if (betrieb?.latitude == null || betrieb?.longitude == null) {
          // Betrieb ohne GPS -> derselbe Fallback wie bei Fahrten zwischen
          // Betrieben (kein 0, keine unberechenbare Heuristik).
          return _kFahrzeitOhneGps;
        }
        final km = hin
            ? haversineKm(
                basis.lat,
                basis.lng,
                betrieb!.latitude!,
                betrieb.longitude!,
              )
            : haversineKm(
                betrieb!.latitude!,
                betrieb.longitude!,
                basis.lat,
                basis.lng,
              );
        // Reine Fahrzeit: am Tagesrand gibt es kein Umladen zwischen zwei
        // Kunden, das den Rüstzuschlag rechtfertigen würde.
        return heuristikMinuten(luftlinieKm: km, mitRuestzeit: false);
      }

      final ersterBetriebId = eintraege.first.betriebId;
      if (ersterBetriebId != null) {
        anfahrtMinuten = minutenAbStartort(lookup[ersterBetriebId], hin: true);
      }
      final letzterBetriebId = eintraege.last.betriebId;
      if (letzterBetriebId != null) {
        heimwegMinuten = minutenAbStartort(
          lookup[letzterBetriebId],
          hin: false,
        );
      }
    }

    // ── Gemessene Ist-Zeiten je Eintrag ──
    // Heute (Live-Modus): Erledigte Besuche laufen mit ihren ECHTEN Zeiten,
    // der Rest rechnet ab «jetzt» — Rückstand und freie Fenster sind so
    // jederzeit ablesbar (Daniel 30.07.2026).
    // Vergangene Tage: dieselben Ist-Zeiten, aber ohne «jetzt» — der Tag
    // zeigt, was wirklich geschah, statt einer Plan-Rechnung ab 06:00
    // (Daniel 30.07.2026, Fall «Plan vom 17.07. geladen, Zeiten stimmen
    // nicht»).
    // Live-Modus (Rest-Plan ab «jetzt») nur solange der Tag wirklich läuft.
    // `readOnly` heisst: vergangener Tag ODER heute mit erfasstem Feierabend
    // — dann ist der Tag abgeschlossen und wird statisch dargestellt.
    final istHeute = _istHeute && !widget.readOnly;
    // Ermittlung geteilt mit «Ganzen Tag verschieben» (erledigte Stopps
    // bleiben dort am alten Tag) — siehe `core/util/tagesplan_ist_zeiten.dart`.
    final erledigtePruefen = istHeute || _istVergangen || widget.readOnly;
    final istZeiten = ermittleIstZeiten(
      eintraege: eintraege,
      datum: widget.datum,
      erledigtePruefen: erledigtePruefen,
      reinigungen: erledigtePruefen
          ? ref.watch(reinigungenProvider)
          : const <ReinigungLocal>[],
      wegpunkte: erledigtePruefen
          ? (ref.watch(wegpunkteFuerTagProvider(widget.datum)).valueOrNull ??
                const <WegpunktTag>[])
          : const <WegpunktTag>[],
      dauerFuer: (e) => _dauerFuer(e, historie),
    );
    // Nicht verschiebbar (Block-Sheet ohne «Auf anderen Tag verschieben»),
    // zusätzlich zu den gemessenen: abgeschlossene Einsätze (K1) und
    // abgemachte Saison-Termine (M4) — gleiche Regeln wie beim ganzen Tag.
    final abgeschlosseneEinsaetze = abgeschlosseneEinsatzEintragIds(
      eintraege,
      ref.watch(einsatzStatusJePlanIdProvider),
    );
    final terminIds = terminEintragIds(
      eintraege,
      ref.watch(offeneTermineProvider).valueOrNull ?? const <TerminDto>[],
      widget.datum,
      betriebSchluessel: (id) => lookup[id]?.routeId ?? id,
    );
    final jetztNow = DateTime.now();
    final jetztMin = jetztNow.hour * 60 + jetztNow.minute;

    final bloecke = [
      for (final e in eintraege)
        PlanBlock(
          id: e.id,
          dauerMinuten: _dauerFuer(e, historie),
          ankerZeit: e.ankerZeit,
          istStartMin: istZeiten[e.id]?.von,
          istEndMin: istZeiten[e.id]?.bis,
        ),
    ];
    // Ohne ERFASSTEN Arbeitsbeginn startet die Ist-Achse beim ersten
    // gemessenen Ereignis — sonst erschiene der 06:00-Standard bis zur
    // ersten Reinigung als riesige «gemessene Anfahrt» (heute wie an
    // vergangenen Tagen).
    // Für die Zeitachse zählt zuerst der tatsächliche Beginn — ab wann
    // gearbeitet wurde, ist genauer als jede Planung. Fehlt er (der Tag hat
    // noch nicht begonnen), rechnet sie mit dem geplanten Beginn, und erst
    // danach mit dem ersten gemessenen Ereignis bzw. dem 06:00-Standard.
    // Beide Werte standen bis Migration 191 in derselben Spalte.
    final gespeicherterTag = ref
        .watch(gespeicherterTagesplanProvider(widget.datum))
        .valueOrNull;
    final erfassterBeginn =
        gespeicherterTag?.arbeitsbeginn ?? gespeicherterTag?.planBeginn;
    final ersterIstStart = istZeiten.isEmpty
        ? null
        : istZeiten.values.map((z) => z.von).reduce((a, b) => a < b ? a : b);
    final beginnFuerIst =
        erfassterBeginn ??
        (ersterIstStart != null
            ? hhmmAusMinuten(ersterIstStart)
            : arbeitstag.beginn);

    final segmente = istHeute
        ? berechneZeitplanMitIst(
            bloecke: bloecke,
            jetztMin: jetztMin,
            arbeitsbeginn: beginnFuerIst,
            anfahrtMinuten: anfahrtMinuten,
            heimwegMinuten: heimwegMinuten,
            fahrzeitZwischen: fahrzeitZwischen,
          )
        : istZeiten.isNotEmpty
        ? berechneZeitplanMitIst(
            // Vergangener Tag: kein «jetzt» -> jetztMin 0 erzeugt weder ein
            // frei-Segment noch verschiebt es offene Einträge — die folgen
            // direkt auf das letzte gemessene Ereignis.
            bloecke: bloecke,
            jetztMin: 0,
            arbeitsbeginn: beginnFuerIst,
            anfahrtMinuten: anfahrtMinuten,
            heimwegMinuten: heimwegMinuten,
            fahrzeitZwischen: fahrzeitZwischen,
          )
        : berechneZeitplan(
            bloecke: bloecke,
            arbeitsbeginn: arbeitstag.beginn,
            anfahrtMinuten: anfahrtMinuten,
            heimwegMinuten: heimwegMinuten,
            fahrzeitZwischen: fahrzeitZwischen,
          );

    final besuchSeg = <String, ZeitSegment>{};
    final fahrtSeg = <String, ZeitSegment>{};
    final warteSeg = <String, ZeitSegment>{};
    ZeitSegment? anfahrt;
    ZeitSegment? heimweg;
    ZeitSegment? frei;
    for (final s in segmente) {
      switch (s.art) {
        case SegmentArt.anfahrt:
          anfahrt = s;
        case SegmentArt.heimweg:
          heimweg = s;
        case SegmentArt.frei:
          frei = s;
        case SegmentArt.besuch:
          if (s.blockId != null) besuchSeg[s.blockId!] = s;
        case SegmentArt.fahrt:
          if (s.blockId != null) fahrtSeg[s.blockId!] = s;
        case SegmentArt.wartezeit:
          if (s.blockId != null) warteSeg[s.blockId!] = s;
      }
    }

    // Jetzt-Linie + frei-Fenster hängen am ERSTEN offenen Eintrag; sind alle
    // erledigt, kommen sie ans Listenende (vor den Heimweg).
    final ersteOffeneId = eintraege
        .where((e) => !istZeiten.containsKey(e.id))
        .map((e) => e.id)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final alleErledigt =
        istHeute && eintraege.isNotEmpty && ersteOffeneId == null;
    final jetztLabel = hhmmAusMinuten(jetztMin);

    if (fehlendePaare.isNotEmpty) {
      // Nach dem Frame, nie während des Builds (Provider-Invalidierung).
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _routenAnfordern(fehlendePaare),
      );
    }

    return Column(
      children: [
        if (anfahrt != null)
          RandSegmentZeile(segment: anfahrt, label: 'Anfahrt'),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            buildDefaultDragHandles: false,
            itemCount: eintraege.length,
            onReorder: widget.onReorder,
            proxyDecorator: (child, index, animation) =>
                Material(elevation: 4, color: Colors.transparent, child: child),
            itemBuilder: (context, index) {
              final eintrag = eintraege[index];
              final segment = besuchSeg[eintrag.id];
              // Sicherheitsnetz: ohne Segment (dürfte nicht vorkommen) bleibt
              // die Zeile leer, statt die ganze Liste scheitern zu lassen.
              if (segment == null) {
                return SizedBox.shrink(key: ValueKey(eintrag.id));
              }

              final betrieb = eintrag.betriebId == null
                  ? null
                  : lookup[eintrag.betriebId!];
              // Saison-Reinigungen dürfen am Rand einer Schliessung trotz
              // «geschlossen» geplant werden (Eröffnung am letzten, End-
              // reinigung am ersten Schliessungstag) — dann grauer Hinweis
              // statt rotem Warnband (Fall Löwen Grossdietwil, 04.08.2026).
              final saisonArt = switch (eintrag.faelligkeit) {
                FaelligkeitsStatus.eroeffnungFaellig => 'eroeffnungsreinigung',
                FaelligkeitsStatus.endreinigungFaellig => 'endreinigung',
                _ => null,
              };
              final saisonHinweis = (betrieb != null && saisonArt != null)
                  ? saisonPlanungsHinweis(
                      art: saisonArt,
                      betrieb: betrieb,
                      tag: widget.datum,
                    )
                  : null;
              final ruhetagKonflikt =
                  betrieb != null &&
                  !istOffenerTag(betrieb, widget.datum) &&
                  saisonHinweis == null;
              // Spec §4: der ganze Besuch (Ankunft bis Ende) muss ins
              // Servicefenster passen, nicht nur die Ankunft.
              final servicezeitKonflikt =
                  betrieb != null &&
                  besuchAusserhalbServicezeit(
                    segment.startMin,
                    segment.endMin,
                    betrieb.servicezeitMorgenAb,
                    betrieb.servicezeitMorgenBis,
                    betrieb.servicezeitNachmittagAb,
                    betrieb.servicezeitNachmittagBis,
                  );
              // Vorschlag nur, wenn nach der Ankunft noch ein Fenster beginnt.
              final vorschlagMin = servicezeitKonflikt
                  ? naechsterFensterStart(
                      segment.startMin,
                      betrieb.servicezeitMorgenAb,
                      betrieb.servicezeitMorgenBis,
                      betrieb.servicezeitNachmittagAb,
                      betrieb.servicezeitNachmittagBis,
                    )
                  : null;

              final betriebKey = betrieb?.routeId ?? eintrag.betriebId;
              final gesamt = betriebKey != null
                  ? (anlagenJeBetrieb[betriebKey] ?? 0)
                  : 0;

              return Dismissible(
                key: ValueKey(eintrag.id),
                direction: widget.readOnly
                    ? DismissDirection.none
                    : DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.error.withAlpha(30),
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
                onDismissed: (_) => widget.onDismiss(eintrag.id),
                child: ZeitplanZeile(
                  segment: segment,
                  fahrtDavor: fahrtSeg[eintrag.id],
                  wartezeitDavor: warteSeg[eintrag.id],
                  eintrag: eintrag,
                  anlagenGesamt: gesamt,
                  dauerGeschaetzt: eintrag.dauerMinuten == null,
                  ruhetagKonflikt: ruhetagKonflikt,
                  saisonHinweis: saisonHinweis,
                  schliessungsGrund: betrieb == null
                      ? null
                      : schliessungsGrund(betrieb, widget.datum),
                  vorjahresFerienText: betrieb == null
                      ? null
                      : _vorjahresFerienText(betrieb, widget.datum),
                  servicezeitKonflikt: servicezeitKonflikt,
                  servicezeit: betrieb == null
                      ? null
                      : servicezeitText(
                          betrieb.servicezeitMorgenAb,
                          betrieb.servicezeitMorgenBis,
                          betrieb.servicezeitNachmittagAb,
                          betrieb.servicezeitNachmittagBis,
                        ),
                  ruhetage: betrieb == null
                      ? null
                      : ruhetageText(betrieb.ruhetage),
                  fahrtQuelle: fahrtQuellen[eintrag.id],
                  erledigt: istZeiten.containsKey(eintrag.id),
                  freiDavor: eintrag.id == ersteOffeneId ? frei : null,
                  jetztZeit: istHeute && eintrag.id == ersteOffeneId
                      ? jetztLabel
                      : null,
                  ankerVorschlag:
                      vorschlagMin != null && !istZeiten.containsKey(eintrag.id)
                      ? hhmmAusMinuten(vorschlagMin)
                      : null,
                  onAnkerVorschlag: vorschlagMin != null
                      ? () => ref
                            .read(tagesplanProvider.notifier)
                            .ersetze(
                              eintrag.id,
                              eintrag.copyWith(
                                ankerZeit: hhmmAusMinuten(vorschlagMin),
                              ),
                            )
                      : null,
                  dragHandle: widget.readOnly
                      ? const SizedBox(width: 10)
                      : ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            width: 44,
                            alignment: Alignment.center,
                            color: AppColors.textSecondary.withAlpha(12),
                            child: const Icon(
                              Icons.drag_indicator,
                              color: AppColors.textSecondary,
                              size: 26,
                            ),
                          ),
                        ),
                  onTap: () => _oeffneBlockSheet(
                    eintrag,
                    erledigt:
                        istZeiten.containsKey(eintrag.id) ||
                        abgeschlosseneEinsaetze.contains(eintrag.id),
                    istTermin: terminIds.contains(eintrag.id),
                  ),
                ),
              );
            },
          ),
        ),
        // Alles erledigt: freies Fenster + Jetzt-Linie ans Listenende.
        if (alleErledigt) ...[
          if (frei != null) FreiZeile(segment: frei),
          JetztLinie(zeit: jetztLabel),
        ],
        if (heimweg != null)
          RandSegmentZeile(segment: heimweg, label: 'Heimweg'),
      ],
    );
  }

  /// Fehlende Strecken einmalig bei der Edge-Function anfragen (fire and
  /// forget). Kommt ein Wert zurück, wird die Fahrzeit-Map neu geladen und
  /// die Zeitachse rechnet mit dem gerouteten statt dem geschätzten Wert.
  Future<void> _routenAnfordern(List<({String von, String nach})> paare) async {
    var erfolg = false;
    for (final p in paare) {
      final key = '${p.von}>${p.nach}';
      if (!_routeAngefragt.add(key)) continue;
      final res = await FahrzeitRepository.routeAnfordern(p.von, p.nach);
      if (res != null) erfolg = true;
    }
    if (erfolg && mounted) ref.invalidate(fahrzeitenMapProvider);
  }

  void _oeffneBlockSheet(
    TourEintrag eintrag, {
    required bool erledigt,
    required bool istTermin,
  }) {
    // Vergangener Tag: die Blöcke sind tatsächliche Reinigungen — Tap führt
    // direkt zur Reinigung (das Block-Sheet bearbeitet nur Plan-Einträge).
    if (widget.readOnly) {
      if (eintrag.id.startsWith('hist_')) {
        context.push('/reinigungen/${eintrag.id.substring(5)}');
      }
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BlockSheet(
        eintragId: eintrag.id,
        datum: widget.datum,
        // Erledigte, tatsächliche (`hist_`) und abgemachte Termin-Stopps
        // bleiben, wo sie sind — ein Termin wird im Betrieb umgeplant.
        onVerschieben: erledigt || istTermin || eintrag.id.startsWith('hist_')
            ? null
            : widget.onVerschieben,
      ),
    );
  }
}

// ─── Block-Sheet: Anlagen, Dauer, Anker, Verschieben, Entfernen ───

class _BlockSheet extends ConsumerWidget {
  final String eintragId;
  final DateTime datum;

  /// «Auf anderen Tag verschieben» — null blendet die Aktion aus.
  final void Function(String eintragId)? onVerschieben;

  const _BlockSheet({
    required this.eintragId,
    required this.datum,
    this.onVerschieben,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tagesplanProvider);
    final treffer = plan.where((e) => e.id == eintragId);
    // Eintrag inzwischen entfernt (z.B. per Swipe) → Sheet leeren statt
    // auf einem verwaisten Stand weiterzuarbeiten.
    if (treffer.isEmpty) return const SizedBox.shrink();
    final eintrag = treffer.first;

    final lookup = ref.watch(betriebLookupProvider);
    final historie = ref.watch(besuchHistorieProvider);
    final betrieb = eintrag.betriebId == null
        ? null
        : lookup[eintrag.betriebId!];
    final gewaehlt = _besuchsAnlagen(eintrag);
    final dauer = _dauerFuer(eintrag, historie);

    // Aktive Anlagen des Betriebs. `AnlageLocal.betriebId` und
    // `TourEintrag.betriebId` tragen dieselbe Id-Konvention (Server-Id); der
    // Vergleich läuft trotzdem über den aufgelösten Betrieb, damit ein
    // Eintrag mit routeId statt serverId nicht durchfällt.
    final anlagen = <AnlageLocal>[
      if (betrieb != null)
        for (final a in ref.watch(anlagenProvider))
          if (a.status == 'aktiv' &&
              lookup[a.betriebId]?.routeId == betrieb.routeId)
            a,
    ];

    // Störung/Montage: Anker-Zeit und Dauer leben nicht nur am Tagesplan-
    // Eintrag, sondern werden auch an den Einsatz zurückgeschrieben
    // (`geplant_am`/`geplant_zeit`/`geplant_dauer_min`) — sonst ginge die
    // Planung verloren, sobald der Block aus dem Plan entfernt wird (Daniel
    // 31.07.2026, siehe `core/util/einsatz_faellig.dart`).
    void ersetze(TourEintrag neu) {
      ref.read(tagesplanProvider.notifier).ersetze(eintragId, neu);
      if (neu.typ != TourEintragTyp.reinigung) {
        _einsatzEinplanungZurueckschreiben(
          ref,
          neu,
          datum,
          ScaffoldMessenger.maybeOf(context),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Griff
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Icon(
                      _typIcon(eintrag.typ),
                      size: 18,
                      color: _typColor(eintrag.typ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        eintrag.betriebOrt != null &&
                                eintrag.betriebOrt!.isNotEmpty
                            ? '${eintrag.betriebName} - ${eintrag.betriebOrt}'
                            : eintrag.betriebName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ─── Einsatz direkt starten (häufigster Vorgang, deshalb an
              // erster Stelle): Sheet schliessen, dann ins Formular — sonst
              // bliebe das Sheet über dem Formular liegen (gleiches Muster
              // wie bei den übrigen Aktionen unten). `heigenie`-Einträge
              // laufen technisch über die Montage-Route (siehe
              // `_navigateToDetail` oben), deshalb hier wie `montage`
              // behandelt.
              //
              // Route über `startRoute` (V3): eine geplante Störung/Montage
              // öffnet den Einsatz selbst («Arbeit beginnen») statt ein
              // neues Formular — sonst entstand ein Doppel und der Stopp
              // blieb offen.
              if (eintrag.betriebId != null ||
                  geplanteEinsatzId(eintrag) != null)
                _SheetAktion(
                  icon: Icons.play_arrow,
                  text: switch (eintrag.typ) {
                    TourEintragTyp.reinigung => 'Reinigung beginnen',
                    TourEintragTyp.stoerung =>
                      geplanteEinsatzId(eintrag) != null
                          ? 'Störung öffnen'
                          : 'Störung erfassen',
                    TourEintragTyp.montage || TourEintragTyp.heigenie =>
                      geplanteEinsatzId(eintrag) != null
                          ? 'Montage öffnen'
                          : 'Montage erfassen',
                  },
                  onTap: () {
                    Navigator.pop(context);
                    context.push(startRoute(eintrag));
                  },
                ),
              if (betrieb != null)
                _SheetAktion(
                  icon: Icons.storefront_outlined,
                  text: 'Betriebsseite öffnen',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/betriebe/${betrieb.routeId}');
                  },
                ),

              // ─── Anlagen (nur Reinigung) ───
              if (eintrag.typ == TourEintragTyp.reinigung) ...[
                const _SheetTitel('Anlagen dieses Besuchs'),
                if (anlagen.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Keine aktiven Anlagen gefunden.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                for (final a in anlagen)
                  _AnlageZeile(
                    anlage: a,
                    gewaehlt: gewaehlt.contains(a.routeId),
                    onTap: () {
                      final neu = List<String>.of(gewaehlt);
                      final abwahl = neu.contains(a.routeId);
                      // Ein Besuch ohne Anlage ergibt fachlich nichts: die
                      // Dauer-Schätzung fiele auf «1 Anlage» zurück und
                      // «Reinigung starten» hätte kein Ziel mehr. Wer den
                      // Besuch loswerden will, entfernt ihn unten ganz.
                      if (abwahl && neu.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            duration: Duration(seconds: 3),
                            content: Text(
                              'Letzte Anlage — zum Entfernen des Besuchs '
                              'unten «Aus Plan entfernen»',
                            ),
                          ),
                        );
                        return;
                      }
                      if (abwahl) {
                        neu.remove(a.routeId);
                      } else {
                        neu.add(a.routeId);
                      }
                      // `dauerMinuten` bleibt unangetastet: ist nichts manuell
                      // gesetzt, folgt die Schätzung automatisch der neuen
                      // Anlagenzahl. `anlageId` (erste Anlage) bleibt als
                      // Kompatibilitäts-Feld für «Reinigung starten» erhalten.
                      ersetze(
                        eintrag.copyWith(anlageIds: neu, anlageId: neu.first),
                      );
                    },
                  ),
              ],

              // ─── Dauer ───
              const _SheetTitel('Dauer'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _RundKnopf(
                      icon: Icons.remove,
                      onTap: () => ersetze(
                        eintrag.copyWith(
                          dauerMinuten: dauer - 5 < 10 ? 10 : dauer - 5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${eintrag.dauerMinuten == null ? '~' : ''}$dauer min',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    _RundKnopf(
                      icon: Icons.add,
                      onTap: () =>
                          ersetze(eintrag.copyWith(dauerMinuten: dauer + 5)),
                    ),
                  ],
                ),
              ),
              if (eintrag.dauerMinuten != null)
                _SheetAktion(
                  icon: Icons.restart_alt,
                  text: 'auf Schätzung zurücksetzen',
                  onTap: () => ersetze(eintrag.copyWith(dauerMinuten: null)),
                ),

              // ─── Termin-Anker ───
              const _SheetTitel('Termin-Anker (frühestens ab)'),
              Row(
                children: [
                  Expanded(
                    child: _SheetAktion(
                      icon: Icons.push_pin_outlined,
                      text: eintrag.ankerZeit ?? '—',
                      onTap: () async {
                        final jetzt =
                            minutenAusHhmm(eintrag.ankerZeit) ?? 8 * 60;
                        final gewaehltZeit = await zeigeZeitauswahl(
                          context,
                          initial: TimeOfDay(
                            hour: jetzt ~/ 60,
                            minute: jetzt % 60,
                          ),
                        );
                        if (gewaehltZeit == null) return;
                        ersetze(
                          eintrag.copyWith(
                            ankerZeit: hhmmAusMinuten(
                              gewaehltZeit.hour * 60 + gewaehltZeit.minute,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (eintrag.ankerZeit != null)
                    GestureDetector(
                      onTap: () => ersetze(eintrag.copyWith(ankerZeit: null)),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),

              // ─── War geschlossen (nur heute/vergangen — für künftige
              // Tage steht noch nichts fest, Daniel 31.07.2026) ───
              if (betrieb != null && istHeuteOderVergangenerTag(datum))
                _SheetAktion(
                  icon: Icons.event_busy,
                  text: 'War geschlossen',
                  onTap: () {
                    Navigator.pop(context);
                    zeigeWarGeschlossenSheet(
                      context,
                      eintragId: eintragId,
                      betrieb: betrieb,
                    );
                  },
                ),

              const Divider(height: 20),
              if (onVerschieben != null)
                _SheetAktion(
                  icon: Icons.event_repeat,
                  text: 'Auf anderen Tag verschieben',
                  onTap: () {
                    Navigator.pop(context);
                    onVerschieben!(eintragId);
                  },
                ),
              _SheetAktion(
                icon: Icons.delete_outline,
                text: 'Aus Plan entfernen',
                farbe: AppColors.error,
                onTap: () {
                  ref.read(tagesplanProvider.notifier).entfernen(eintragId);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schreibt Anker-Zeit + Dauer eines Störungs-/Montage-Blocks an den
/// zugrundeliegenden Einsatz zurück (`StoerungRepository`/
/// `MontageRepository.einplanen`). `eintrag.id` trägt das Präfix `s_`/`m_`
/// vor der eigentlichen `routeId` (siehe `faelligeEintraegeProvider`,
/// gleiche Konvention wie `_navigateToDetail`). Fire-and-forget, dann die
/// Störung/Montage-Liste auffrischen (Web lädt sonst nicht neu). Fehler
/// landen im Log und — solange es ihn gibt — über [messenger] beim Nutzer;
/// bis 26.09.2026 liefen sie ungefangen durch (Review).
void _einsatzEinplanungZurueckschreiben(
  WidgetRef ref,
  TourEintrag eintrag,
  DateTime datum,
  ScaffoldMessengerState? messenger,
) {
  final id = eintrag.id.substring(2);
  final dauer = eintrag.dauerMinuten ?? kDauerDefaultMinuten;
  // Muss VOR dem Schreiben gelesen werden (siehe Doku bei `einsatzUmplanen`
  // in tour_providers.dart) — danach steht in der DB bereits das neue
  // Datum. Normalfall: der Block liegt schon im Plan von [datum], also
  // ändert sich hier nichts. Kam er aber per «Fällig übernehmen» aus einem
  // anderen (z.B. überfälligen) Tag in diesen Plan, schreibt dieser Aufruf
  // das Plandatum jetzt auf [datum] um — dann muss der alte Tagesplan-
  // Eintrag verschwinden, sonst bleibt er dort als „Geisterblock" stehen
  // (Fehlerbericht 02.08.2026).
  final altesDatum = eintrag.geplantAm;
  Future<void> alterEintragAufraeumen() async {
    if (mussAusAltemPlanEntfernt(altesDatum: altesDatum, neuesDatum: datum)) {
      final alterTag = DateTime(
        altesDatum!.year,
        altesDatum.month,
        altesDatum.day,
      );
      await einsatzAusTagesplanEntfernen(ref, alterTag, eintrag.id);
    }
  }

  void melden(String text, Object e) {
    debugPrint('[Tourenplan] $text: $e');
    messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('$text: ${kurzeFehlermeldung(e)}'),
      ),
    );
  }

  Future<void> zurueckschreiben() async {
    try {
      if (eintrag.typ == TourEintragTyp.stoerung) {
        await StoerungRepository.einplanen(
          id: id,
          tag: datum,
          zeit: eintrag.ankerZeit,
          dauerMin: dauer,
        );
        ref.invalidate(stoerungenStreamProvider);
      } else {
        await MontageRepository.einplanen(
          id: id,
          tag: datum,
          zeit: eintrag.ankerZeit,
          dauerMin: dauer,
        );
        ref.invalidate(montagenStreamProvider);
      }
    } catch (e) {
      melden('Zeit/Dauer nicht am Einsatz gespeichert', e);
      return;
    }
    try {
      await alterEintragAufraeumen();
    } catch (e) {
      final alt = altesDatum;
      melden(
        alt == null
            ? 'Alter Plan-Eintrag nicht entfernt'
            : 'Steht evtl. noch im Tagesplan vom ${kurzTag(alt)}',
        e,
      );
    }
  }

  unawaited(zurueckschreiben());
}

/// Plan-Eintrag für den Zieltag. Bei Einsätzen zieht `geplantAm` mit — das
/// wirkt NUR im Speicher, das Plan-JSON speichert `geplantAm` nicht (siehe
/// `tourEintragToJson`); nach dem nächsten Laden ist das Feld leer.
/// Einziger Nutzen: Landet der Eintrag im Notifier des Zieltags (Wechsel
/// während des Verschiebens), sieht [_einsatzEinplanungZurueckschreiben]
/// bei einer Änderung im Block-Sheet den Zieltag als bisheriges Plandatum
/// und räumt keinen fremden Tag auf. Massgebend bleibt `geplant_am` am
/// Einsatz (`umplanenAufTag`).
TourEintrag _alsVerschobenerEintrag(TourEintrag e, DateTime ziel) {
  final plan = e.alsPlanEintrag();
  return geplanteEinsatzId(e) != null ? plan.copyWith(geplantAm: ziel) : plan;
}

/// Setzt das Plandatum aller Störungen/Montagen (inkl. HeiGenie) unter
/// [eintraege] auf [ziel] und frischt deren Listen auf. Nur `geplant_am` —
/// Zeit und Dauer bleiben, wie sie am Einsatz stehen (`umplanenAufTag`;
/// früher überschrieb `einplanen` sie mit den Plan-Werten, eine 180-min-
/// Montage schrumpfte so auf 60 min). HeiGenie zählt mit: bliebe sein
/// `geplant_am` stehen, tauchte er am alten Tag wieder als fällig auf.
///
/// Ein nicht mehr offener Einsatz wird übersprungen — kein neues Plandatum
/// und kein Kalender-Push auf einen abgeschlossenen Einsatz (K1).
///
/// Anders als [_einsatzEinplanungZurueckschreiben] wird gewartet — schlägt
/// es fehl, bricht das Verschieben ab, bevor der Plan angefasst wird.
/// Liefert die Zahl der umgeplanten Einsätze (für eine ehrliche
/// Fehlermeldung, falls ein späterer Schritt scheitert).
Future<int> _einsaetzeAufTagUmplanen(
  WidgetRef ref,
  List<TourEintrag> eintraege,
  DateTime ziel,
) async {
  final abgeschlossen = abgeschlosseneEinsatzEintragIds(
    eintraege,
    ref.read(einsatzStatusJePlanIdProvider),
  );
  var stoerungen = false;
  var montagen = false;
  final auftraege = <Future<void>>[];
  for (final e in eintraege) {
    final id = geplanteEinsatzId(e);
    if (id == null || abgeschlossen.contains(e.id)) continue;
    if (e.typ == TourEintragTyp.stoerung) {
      stoerungen = true;
      auftraege.add(StoerungRepository.umplanenAufTag(id: id, tag: ziel));
    } else {
      // montage und heigenie — beide aus der `montagen`-Tabelle.
      montagen = true;
      auftraege.add(MontageRepository.umplanenAufTag(id: id, tag: ziel));
    }
  }
  if (auftraege.isEmpty) return 0;
  try {
    await Future.wait(auftraege);
    return auftraege.length;
  } finally {
    // Auch bei einem Teilfehler: was geschrieben wurde, soll sichtbar sein.
    if (stoerungen) ref.invalidate(stoerungenStreamProvider);
    if (montagen) ref.invalidate(montagenStreamProvider);
  }
}

class _SheetTitel extends StatelessWidget {
  final String text;

  const _SheetTitel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Tippbare Zeile im Sheet — bewusst GestureDetector + Container statt eines
/// Material-Buttons (CanvasKit-Regel: Material-Buttons in Sheets werden auf
/// Web nicht zuverlässig gezeichnet).
class _SheetAktion extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color farbe;
  final VoidCallback onTap;

  const _SheetAktion({
    required this.icon,
    required this.text,
    required this.onTap,
    this.farbe = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: farbe),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: farbe,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RundKnopf extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RundKnopf({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _AnlageZeile extends StatelessWidget {
  final AnlageLocal anlage;
  final bool gewaehlt;
  final VoidCallback onTap;

  const _AnlageZeile({
    required this.anlage,
    required this.gewaehlt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              gewaehlt ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22,
              color: gewaehlt ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${anlage.bezeichnung ?? anlage.typAnlage} · '
                '${anlage.anzahlHaehne} Hähne',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Arbeitstag: Start / Ende + km ───

class _ArbeitstagZeile extends ConsumerWidget {
  final DateTime datum;

  const _ArbeitstagZeile({required this.datum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = ref.watch(arbeitstagProvider(datum));
    // Diese Zeile plant — sie zeigt und schreibt den PLAN-Beginn, nicht den
    // tatsächlichen (Migration 191). Der Ist-Wert gehört der Arbeitstag-Karte
    // auf der Startseite und wird nur von «Jetzt starten» gesetzt; hier ihn
    // zu überschreiben liess den Tag als bereits begonnen erscheinen.
    // `at.beginn` trägt sonst den 06:00-Standard und würde einen nie
    // erfassten Wert vortäuschen.
    final erfassterBeginn = ref
        .watch(gespeicherterTagesplanProvider(datum))
        .valueOrNull
        ?.planBeginn;

    Future<void> speichern(Arbeitstag neu, {required String? beginnDb}) async {
      // Jeder Ausgang meldet sich (Daniel 11.08.2026): Fehler landeten hier
      // nur im debugPrint, und der Datum-Guard brach wortlos ab — es sah
      // beides nach «gespeichert» aus, obwohl nichts geschrieben wurde.
      final messenger = ScaffoldMessenger.of(context);
      // Das Speichern unten reicht den Ist-Beginn aus dem gespeicherten Plan
      // durch und schreibt ihn IMMER — bei einem Ladefehler als `null`, der
      // erfasste Arbeitsbeginn wäre gelöscht (Review 26.09.2026).
      if (!arbeitstagStandBereit(ref, datum, messenger)) return;
      ref.read(arbeitstagProvider(datum).notifier).state = neu;
      // Datum-Guard: gehört der In-Memory-Plan inzwischen einem anderen Tag
      // (Tagwechsel während des Dialogs), würde der Fallback-Pfad die Einträge
      // des Vortags auf diesen Tag schreiben. Dann lieber gar nicht speichern.
      if (ref.read(tagesplanProvider.notifier).datum != datum) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Nicht gespeichert — der Tagesplan gehört inzwischen zu einem '
              'anderen Tag. Bitte erneut versuchen.',
            ),
          ),
        );
        return;
      }
      try {
        // `arbeitsbeginn: null` ist hier kein Löschen: Der Ist-Wert wird von
        // dieser Zeile nie geschrieben. Das Update setzt ihn allerdings
        // wörtlich auf null — deshalb den vorhandenen Wert durchreichen,
        // sonst verlöre ein bereits gestarteter Tag beim Planen seinen
        // echten Beginn.
        final istBeginn = ref
            .read(gespeicherterTagesplanProvider(datum))
            .valueOrNull
            ?.arbeitsbeginn;
        await arbeitstagFelderSpeichern(
          datum,
          ref.read(tagesplanProvider),
          arbeitsbeginn: istBeginn,
          planBeginn: beginnDb,
          planBeginnSchreiben: true,
          arbeitsende: neu.ende,
          kmStand: neu.km,
          kmStart: neu.kmStart,
        );
        ref.invalidate(gespeicherterTagesplanProvider(datum));
        messenger.showSnackBar(
          const SnackBar(content: Text('Arbeitstag gespeichert')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: ${kurzeFehlermeldung(e)}'),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          _TippFeld(
            icon: Icons.schedule,
            text: 'Start ${erfassterBeginn ?? '—'}',
            onTap: () async {
              final start = minutenAusHhmm(at.beginn) ?? 6 * 60;
              final gewaehlt = await zeigeZeitauswahl(
                context,
                initial: TimeOfDay(hour: start ~/ 60, minute: start % 60),
              );
              if (gewaehlt == null) return;
              final neu = hhmmAusMinuten(gewaehlt.hour * 60 + gewaehlt.minute);
              await speichern((
                beginn: neu,
                ende: at.ende,
                km: at.km,
                kmStart: at.kmStart,
                lat: at.lat,
                lng: at.lng,
                endLat: at.endLat,
                endLng: at.endLng,
                pauseMinuten: at.pauseMinuten,
                pauseStart: at.pauseStart,
              ), beginnDb: neu);
            },
          ),
          const Spacer(),
          _TippFeld(
            icon: Icons.flag_outlined,
            text:
                'Ende ${at.ende ?? '—'} · ${at.km != null ? '${at.km} km' : '— km'}',
            onTap: () async {
              final eingabe = await showModalBottomSheet<ArbeitstagEingabe>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ArbeitstagAbschlussSheet(
                  aktuell: at,
                  erfassterBeginn: erfassterBeginn,
                ),
              );
              if (eingabe == null) return;
              await speichern((
                beginn: eingabe.beginn ?? '06:00',
                ende: eingabe.ende,
                km: eingabe.km,
                kmStart: eingabe.kmStart,
                lat: at.lat,
                lng: at.lng,
                endLat: at.endLat,
                endLng: at.endLng,
                pauseMinuten: at.pauseMinuten,
                pauseStart: at.pauseStart,
              ), beginnDb: eingabe.beginn);
            },
          ),
        ],
      ),
    );
  }
}

class _TippFeld extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TippFeld({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abend-Erfassung: Arbeitsende und km-Stand.
// ─── Info-Zeile: Ruhetage / Servicezeiten / Ruhetag-Warnung ───

class _TourInfoZeile extends ConsumerWidget {
  final DateTime datum;
  final TourEintrag eintrag;

  const _TourInfoZeile({required this.datum, required this.eintrag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ruhetage und Servicezeit immer frisch aus den Stammdaten — im
    // gespeicherten Tagesplan stehen sie nur als Kopie vom Speicherzeitpunkt.
    final betrieb = eintrag.betriebId == null
        ? null
        : ref.watch(betriebLookupProvider)[eintrag.betriebId!];
    final ruhetage = betrieb?.ruhetage ?? eintrag.ruhetage;
    final zeitTxt = betrieb != null
        ? servicezeitAus(betrieb)
        : eintrag.servicezeit;

    final heuteRuhetag = istRuhetag(ruhetage, datum);
    final ruheTxt = ruhetageText(ruhetage);
    // Fehlt die Servicezeit ganz, wird das benannt — sonst ist nicht
    // erkennbar, ob sie fehlt oder ob kein Service möglich ist.
    final zeitFehlt =
        zeitTxt == null && eintrag.typ == TourEintragTyp.reinigung;

    if (!heuteRuhetag && ruheTxt.isEmpty && zeitTxt == null && !zeitFehlt) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    if (heuteRuhetag) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.block, size: 13, color: AppColors.error),
            SizedBox(width: 3),
            Text(
              'Heute Ruhetag',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    } else if (ruheTxt.isNotEmpty) {
      children.add(_infoChip(Icons.event_busy, 'Ruhetag: $ruheTxt'));
    }

    if (zeitTxt != null) {
      children.add(_infoChip(Icons.schedule, zeitTxt));
    } else if (zeitFehlt) {
      children.add(_infoChip(Icons.schedule, 'Servicezeit fehlt'));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(spacing: 10, runSpacing: 2, children: children),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Status-Badge ───

class _StatusBadge extends StatelessWidget {
  final TourEintrag eintrag;

  const _StatusBadge({required this.eintrag});

  @override
  Widget build(BuildContext context) {
    String? label;
    Color? color;

    if (eintrag.faelligkeit == FaelligkeitsStatus.ueberfaellig) {
      label = 'überfällig';
      color = AppColors.error;
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.faellig) {
      label = 'fällig';
      color = AppColors.warning;
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.baldFaellig) {
      label = 'bald fällig';
      color = AppColors.success;
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.endreinigungFaellig) {
      label = 'Endreinigung';
      color = const Color(0xFFEA580C); // deep orange
    } else if (eintrag.faelligkeit == FaelligkeitsStatus.eroeffnungFaellig) {
      label = 'Eröffnung';
      color = AppColors.info;
    } else if (eintrag.typ == TourEintragTyp.stoerung) {
      label = 'offen';
      color = AppColors.error;
    } else if (eintrag.typ == TourEintragTyp.montage ||
        eintrag.typ == TourEintragTyp.heigenie) {
      label = 'geplant';
      color = AppColors.info;
    }

    if (label == null || color == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Fällig-Eintrag Karte (im Fällig-Tab) ───

class _FaelligEintragKarte extends ConsumerWidget {
  final DateTime datum;
  final TourEintrag eintrag;
  final bool imPlan;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  const _FaelligEintragKarte({
    required this.datum,
    required this.eintrag,
    required this.imPlan,
    required this.onAdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typColor(eintrag.typ);
    final letzteReinigung = eintrag.anlageId == null
        ? null
        : ref.watch(letzteReinigungJeAnlageProvider)[eintrag.anlageId!];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withAlpha(25),
                        child: Icon(
                          _typIcon(eintrag.typ),
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Betrieb + Ort in einer Grösse (Spec §7) — vorher
                            // stach der Ort optisch kleiner ab, obwohl er zum
                            // Wiedererkennen genauso wichtig ist.
                            Text(
                              eintrag.betriebOrt != null &&
                                      eintrag.betriebOrt!.isNotEmpty
                                  ? '${eintrag.betriebName} - ${eintrag.betriebOrt}'
                                  : eintrag.betriebName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              eintrag.beschreibung,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            _TourInfoZeile(datum: datum, eintrag: eintrag),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusBadge(eintrag: eintrag),
                          if (eintrag.typ == TourEintragTyp.reinigung &&
                              eintrag.anlageId != null &&
                              letzteReinigung != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'zuletzt ${DateFormat('dd.MM.yyyy').format(letzteReinigung)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Einplanen: nur Störung/Montage/HeiGenie — Reinigungen
                      // folgen der Fälligkeits-Rechnung, kein Plandatum
                      // (Migration 163, `core/util/einsatz_faellig.dart`).
                      if (eintrag.typ != TourEintragTyp.reinigung)
                        IconButton(
                          icon: const Icon(Icons.event_outlined),
                          color: AppColors.textSecondary,
                          onPressed: () => _einplanen(context, ref),
                          tooltip: 'Einplanen',
                          iconSize: 22,
                          visualDensity: VisualDensity.compact,
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          imPlan
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          color: imPlan ? AppColors.success : AppColors.primary,
                        ),
                        onPressed: imPlan ? null : onAdd,
                        tooltip: imPlan ? 'Bereits im Plan' : 'Zum Tagesplan',
                        iconSize: 24,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Öffnet das Einplanen-Sheet und schreibt das Ergebnis an den passenden
  /// Einsatz (`StoerungRepository`/`MontageRepository.einplanen`). `id`
  /// trägt das Präfix `s_`/`m_` vor der `routeId` — gleiche Konvention wie
  /// `_navigateToDetail` im Screen.
  Future<void> _einplanen(BuildContext context, WidgetRef ref) async {
    // Vor dem Sheet holen: danach kann die Kachel schon neu aufgebaut sein.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ergebnis = await zeigeEinplanenSheet(
      context,
      titel: eintrag.betriebOrt != null && eintrag.betriebOrt!.isNotEmpty
          ? '${eintrag.betriebName} - ${eintrag.betriebOrt}'
          : eintrag.betriebName,
      untertitel: eintrag.beschreibung,
      initialTag: eintrag.geplantAm,
      initialZeit: eintrag.geplantZeit,
      initialDauerMin: eintrag.geplantDauerMin,
    );
    if (ergebnis == null) return;
    final id = eintrag.id.substring(2);
    // Muss VOR dem Schreiben gelesen werden — siehe Doku bei
    // `einsatzUmplanen`. Ohne das Aufnehmen in den Tagesplan landet der
    // Einsatz nur in der Fällig-Liste des Zieltags, nie in der Zeitachse;
    // ohne das Entfernen aus dem alten Tag bleibt er dort als
    // „Geisterblock" stehen (Fehlerbericht 02.08.2026, beide Teile).
    final altesDatum = eintrag.geplantAm;
    // Ein Fehler (z. B. Tagesplan nicht ladbar) wird gemeldet — bis
    // 26.09.2026 lief er hier ungefangen durch. Welcher Schritt scheiterte,
    // ist offen, deshalb der Hinweis auf den Tagesplan.
    try {
      await einsatzUmplanen(
        ref,
        altesDatum: altesDatum,
        neuesDatum: ergebnis.tag,
        schreiben: () async {
          if (eintrag.typ == TourEintragTyp.stoerung) {
            await StoerungRepository.einplanen(
              id: id,
              tag: ergebnis.tag,
              zeit: ergebnis.zeit,
              dauerMin: ergebnis.dauerMin,
            );
            ref.invalidate(stoerungenStreamProvider);
          } else {
            await MontageRepository.einplanen(
              id: id,
              tag: ergebnis.tag,
              zeit: ergebnis.zeit,
              dauerMin: ergebnis.dauerMin,
            );
            ref.invalidate(montagenStreamProvider);
          }
        },
        eintrag: geplanterEinsatzEintrag(
          typ: eintrag.typ,
          routeId: id,
          betriebId: eintrag.betriebId,
          anlageId: eintrag.anlageId,
          betriebName: eintrag.betriebName,
          betriebOrt: eintrag.betriebOrt,
          regionId: eintrag.regionId,
          beschreibung: eintrag.beschreibung,
          ruhetage: eintrag.ruhetage,
          servicezeit: eintrag.servicezeit,
          tag: ergebnis.tag,
          zeit: ergebnis.zeit,
          dauerMin: ergebnis.dauerMin,
        ),
      );
    } catch (e) {
      debugPrint('[Tourenplan] Einplanen fehlgeschlagen: $e');
      messenger?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            'Einplanen nicht vollständig — bitte Tagesplan prüfen: '
            '${kurzeFehlermeldung(e)}',
          ),
        ),
      );
    }
  }
}

/// «Letztes Jahr hier Betriebsferien (20.07.–10.08.) — nachfragen»: der
/// Vorjahres-Ferienhinweis fuer den Besuchs-Block, oder `null`, wenn fuers
/// Jahr von [tag] schon etwas feststeht oder keine Vorjahresperiode passt.
/// Siehe `core/util/ferien_vorjahr.dart` (Daniel 31.07.2026).
String? _vorjahresFerienText(BetriebLocal b, DateTime tag) {
  final fenster = vorjahresFerienHinweis(
    perioden: b.ferienPerioden ?? const [],
    tag: tag,
    hatAussageFuerJahr: hatFerienAussageFuerJahr(b, tag.year),
  );
  if (fenster == null) return null;
  String d(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.';
  return 'Letztes Jahr hier Betriebsferien '
      '(${d(fenster.von)}–${d(fenster.bis)}) — nachfragen';
}
