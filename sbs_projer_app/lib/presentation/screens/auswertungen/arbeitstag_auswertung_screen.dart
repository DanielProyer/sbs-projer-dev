import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/arbeitstag_auswertung.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Monats-Schlüssel der Auswertung. Record statt DateTime, damit zwei
/// Aufrufe desselben Monats garantiert denselben Provider treffen — ein
/// DateTime mit abweichender Uhrzeit wäre ein anderer family-Schlüssel und
/// würde denselben Monat ein zweites Mal laden.
typedef AuswertungsMonat = ({int jahr, int monat});

/// Roh erfasster Arbeitstag-Rahmen aus `tagesplaene`.
typedef ArbeitstagRohdaten = ({
  DateTime datum,
  String? beginn,
  String? ende,
  int? kmStart,
  int? kmEnde,
});

String _datumStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Alle erfassten Arbeitstag-Rahmen eines Monats.
///
/// Eigener Provider statt `gespeicherterTagesplanProvider` je Tag: für eine
/// Monatsauswertung wären das bis zu 31 Einzelabfragen. Die Einträge
/// (`eintraege`) bleiben bewusst aussen vor — geplant ist nicht gearbeitet,
/// die Besuchszahl kommt aus den abgeschlossenen Reinigungen.
final arbeitstageProvider =
    FutureProvider.family<List<ArbeitstagRohdaten>, AuswertungsMonat>((
      ref,
      m,
    ) async {
      final von = DateTime(m.jahr, m.monat, 1);
      final bis = DateTime(
        m.jahr,
        m.monat + 1,
        1,
      ); // Monat 13 → Januar Folgejahr
      final rows = await SupabaseService.client
          .from('tagesplaene')
          .select('datum, arbeitsbeginn, arbeitsende, km_start, km_stand')
          .gte('datum', _datumStr(von))
          .lt('datum', _datumStr(bis))
          .order('datum');
      return [
        for (final r in rows)
          (
            datum: DateTime.parse(r['datum'] as String),
            beginn: r['arbeitsbeginn'] as String?,
            ende: r['arbeitsende'] as String?,
            kmStart: (r['km_start'] as num?)?.toInt(),
            kmEnde: (r['km_stand'] as num?)?.toInt(),
          ),
      ];
    });

const _wochentagKurz = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _monatsNamen = [
  '',
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

class ArbeitstagAuswertungScreen extends ConsumerStatefulWidget {
  const ArbeitstagAuswertungScreen({super.key});

  @override
  ConsumerState<ArbeitstagAuswertungScreen> createState() =>
      _ArbeitstagAuswertungScreenState();
}

class _ArbeitstagAuswertungScreenState
    extends ConsumerState<ArbeitstagAuswertungScreen> {
  late AuswertungsMonat _monat;

  @override
  void initState() {
    super.initState();
    final heute = DateTime.now();
    _monat = (jahr: heute.year, monat: heute.month);
  }

  void _blaettern(int schritte) {
    final neu = DateTime(_monat.jahr, _monat.monat + schritte);
    setState(() => _monat = (jahr: neu.year, monat: neu.month));
  }

  /// Vorwärts nur bis zum laufenden Monat — in der Zukunft ist nichts erfasst,
  /// und ein leerer Monat sieht aus wie ein Fehler.
  bool get _kannVorwaerts {
    final heute = DateTime.now();
    return _monat.jahr < heute.year ||
        (_monat.jahr == heute.year && _monat.monat < heute.month);
  }

  /// Rohdaten + Besuche zu den auswertbaren Tagen des Monats verbinden.
  ///
  /// Tage mit Besuchen, aber ohne Tagesplan-Zeile, kommen mit dazu: gearbeitet
  /// wurde dort nachweislich, nur Zeit/km fehlen. Ohne sie wäre die
  /// Besuchssumme des Monats unvollständig.
  List<Arbeitstagsdaten> _tage(
    List<ArbeitstagRohdaten> rohdaten,
    Map<DateTime, int> besuche,
  ) {
    final proTag = <DateTime, Arbeitstagsdaten>{};
    for (final r in rohdaten) {
      final tag = nurDatum(r.datum);
      proTag[tag] = (
        datum: tag,
        beginn: r.beginn,
        ende: r.ende,
        kmStart: r.kmStart,
        kmEnde: r.kmEnde,
        besuche: besuche[tag] ?? 0,
      );
    }
    for (final e in besuche.entries) {
      if (e.key.year != _monat.jahr || e.key.month != _monat.monat) continue;
      proTag.putIfAbsent(
        e.key,
        () => (
          datum: e.key,
          beginn: null,
          ende: null,
          kmStart: null,
          kmEnde: null,
          besuche: e.value,
        ),
      );
    }
    // Neueste zuoberst: der zuletzt erfasste Tag ist der, den man prüfen will.
    return proTag.values.where(hatErfassung).toList()
      ..sort((a, b) => b.datum.compareTo(a.datum));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(arbeitstageProvider(_monat));
    final besuche = besucheJeTag([
      for (final r in ref.watch(reinigungenProvider))
        if (r.status == 'abgeschlossen' && r.betriebId.isNotEmpty)
          (datum: r.datum, betriebId: r.betriebId),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('Auswertung Arbeitstage')),
      body: Column(
        children: [
          _MonatsWahl(
            titel: '${_monatsNamen[_monat.monat]} ${_monat.jahr}',
            onZurueck: () => _blaettern(-1),
            onVor: _kannVorwaerts ? () => _blaettern(1) : null,
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Daten konnten nicht geladen werden.\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              data: (rohdaten) {
                final tage = _tage(rohdaten, besuche);
                if (tage.isEmpty) return const _LeererMonat();
                final k = berechneKennzahlen(tage);
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(arbeitstageProvider(_monat)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                    children: [
                      _Kennzahlen(k: k),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          'Einzelne Tage',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      for (final t in tage) _TagesZeile(t: t),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonatsWahl extends StatelessWidget {
  final String titel;
  final VoidCallback onZurueck;
  final VoidCallback? onVor;

  const _MonatsWahl({required this.titel, required this.onZurueck, this.onVor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onZurueck,
            tooltip: 'Vorheriger Monat',
          ),
          Expanded(
            child: Text(
              titel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onVor,
            tooltip: 'Nächster Monat',
          ),
        ],
      ),
    );
  }
}

class _Kennzahlen extends StatelessWidget {
  final ArbeitstagKennzahlen k;

  const _Kennzahlen({required this.k});

  @override
  Widget build(BuildContext context) {
    // Fester Zwei-Spalten-Raster: auf dem Handy einhändig lesbar, ohne
    // horizontales Scrollen. Karten sind nicht tappbar (reine Anzeige).
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        _KennzahlKarte(
          label: 'Arbeitstage',
          wert: '${k.anzahlTage}',
          icon: Icons.event_available,
        ),
        _KennzahlKarte(
          label: 'Besuche',
          wert: '${k.anzahlBesuche}',
          icon: Icons.store,
        ),
        _KennzahlKarte(
          label: 'Total km',
          wert: '${k.totalKm}',
          zusatz: 'an ${k.tageMitKm} Tagen erfasst',
          icon: Icons.route,
        ),
        _KennzahlKarte(
          label: 'Ø km/Tag',
          wert: schnittText(k.schnittKm, nachkomma: 0),
          icon: Icons.speed,
        ),
        _KennzahlKarte(
          label: 'Total Arbeitszeit',
          wert: dauerText(k.totalMinuten),
          zusatz: 'an ${k.tageMitZeit} Tagen erfasst',
          icon: Icons.schedule,
        ),
        _KennzahlKarte(
          label: 'Ø Arbeitszeit/Tag',
          wert: k.schnittMinuten == null
              ? '–'
              : dauerText(k.schnittMinuten!.round()),
          icon: Icons.hourglass_bottom,
        ),
        _KennzahlKarte(
          label: 'Ø Besuche/Tag',
          wert: schnittText(k.schnittBesuche),
          icon: Icons.checklist,
        ),
        _KennzahlKarte(
          label: 'Ø km je Besuch',
          wert: schnittText(k.kmJeBesuch),
          icon: Icons.alt_route,
        ),
        _KennzahlKarte(
          label: 'Ø Min. je Besuch',
          wert: schnittText(k.minutenJeBesuch, nachkomma: 0),
          icon: Icons.timer_outlined,
        ),
      ],
    );
  }
}

class _KennzahlKarte extends StatelessWidget {
  final String label;
  final String wert;
  final String? zusatz;
  final IconData icon;

  const _KennzahlKarte({
    required this.label,
    required this.wert,
    required this.icon,
    this.zusatz,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                wert,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (zusatz != null)
              Text(
                zusatz!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TagesZeile extends StatelessWidget {
  final Arbeitstagsdaten t;

  const _TagesZeile({required this.t});

  @override
  Widget build(BuildContext context) {
    final km = tagesKm(kmStart: t.kmStart, kmEnde: t.kmEnde);
    final minuten = arbeitsMinuten(beginn: t.beginn, ende: t.ende);
    // Halb erfasste Tage zeigen die vorhandene Hälfte mit '?' auf der anderen
    // Seite — so ist auf einen Blick klar, was nachzutragen wäre.
    final zeitraum = (t.beginn == null && t.ende == null)
        ? null
        : '${t.beginn ?? '?'}–${t.ende ?? '?'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(
                '${_wochentagKurz[t.datum.weekday - 1]} '
                '${t.datum.day.toString().padLeft(2, '0')}.'
                '${t.datum.month.toString().padLeft(2, '0')}.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zeitraum ?? 'keine Zeiten',
                    style: TextStyle(
                      fontSize: 12,
                      color: zeitraum == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    [
                      if (minuten != null) dauerText(minuten),
                      if (km != null) '$km km',
                      '${t.besuche} ${t.besuche == 1 ? 'Besuch' : 'Besuche'}',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeererMonat extends StatelessWidget {
  const _LeererMonat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.query_stats,
              size: 42,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Für diesen Monat ist nichts erfasst.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Arbeitsbeginn, Feierabend und die km-Stände werden auf dem '
              'Startbildschirm im Arbeitstag erfasst — sobald ein Tag dort '
              'gestartet und beendet ist, erscheint er hier.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
