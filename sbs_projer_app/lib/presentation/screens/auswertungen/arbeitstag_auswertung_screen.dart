import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/arbeitstag_auswertung.dart';
import 'package:sbs_projer_app/core/util/fahrten_aus_kette.dart'
    show TagesFahrten;
import 'package:sbs_projer_app/presentation/providers/arbeitstag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/fahrten_providers.dart';

// Monats-Provider und -Typen liegen seit 27.09.2026 in
// `arbeitstag_providers.dart` (auch «Fahrten aus der Kette» braucht sie);
// Weiterexport, damit bestehende Importe dieses Screens gültig bleiben.
export 'package:sbs_projer_app/presentation/providers/arbeitstag_providers.dart'
    show
        AuswertungsMonat,
        ArbeitstagRohdaten,
        arbeitstageProvider,
        besucheImMonatProvider;

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

  Widget _inhalt({
    required Object? fehler,
    required bool ladend,
    required Map<DateTime, TagesFahrten>? fahrten,
    required bool fahrtenGescheitert,
  }) {
    if (fehler != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Daten konnten nicht geladen werden.\n$fehler',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    if (ladend) return const Center(child: CircularProgressIndicator());

    final rohdaten = ref.read(arbeitstageProvider(_monat)).requireValue;
    final besuche = ref.read(besucheImMonatProvider(_monat)).requireValue;
    final tage = _tage(rohdaten, besuche);
    if (tage.isEmpty) return const _LeererMonat();
    final k = berechneKennzahlen(tage);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(besucheImMonatProvider(_monat));
        fahrtenNeuLaden(ref, _monat); // inkl. arbeitstageProvider
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
        children: [
          _Kennzahlen(
            k: k,
            fahrten: fahrten,
            fahrtenGescheitert: fahrtenGescheitert,
          ),
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
          for (final t in tage) _TagesZeile(t: t, fahrten: fahrten?[t.datum]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Beide Quellen zählen gleich viel: Ohne die Besuche wäre die Seite zwar
    // vollständig gezeichnet, würde aber überall 0 Besuche behaupten. Deshalb
    // wird erst gezeigt, wenn beide da sind — und ein Fehler wird benannt.
    final tageAsync = ref.watch(arbeitstageProvider(_monat));
    final besucheAsync = ref.watch(besucheImMonatProvider(_monat));
    final fehler = tageAsync.error ?? besucheAsync.error;
    final ladend = tageAsync.isLoading || besucheAsync.isLoading;
    // Fahrten sind Zusatz: Solange sie laden (oder scheitern), zeigt die
    // Tageszeile einfach keine Fahrten-Angabe — nie eine erfundene «0 km».
    // Der Fehler selbst erscheint im Detail-Screen samt «Erneut laden».
    // Hier beobachtet (nicht erst in der Liste), damit die Abfragen parallel
    // zu Tagesplan und Besuchen starten.
    final fahrtenAsync = ref.watch(monatsFahrtenProvider(_monat));
    final fahrten = fahrtenAsync.valueOrNull;
    // Gescheitert und nicht gerade neu am Laden: Die Kennzahl zeigt dann «–»
    // statt für immer «wird berechnet».
    final fahrtenGescheitert = fahrtenAsync.hasError && !fahrtenAsync.isLoading;

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
            child: _inhalt(
              fehler: fehler,
              ladend: ladend,
              fahrten: fahrten,
              fahrtenGescheitert: fahrtenGescheitert,
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

  /// `null`, solange «Fahrten aus der Kette» lädt oder gescheitert ist.
  final Map<DateTime, TagesFahrten>? fahrten;

  /// Gescheitert (und nicht neu am Laden) — «–» statt «wird berechnet».
  final bool fahrtenGescheitert;

  const _Kennzahlen({
    required this.k,
    required this.fahrten,
    required this.fahrtenGescheitert,
  });

  @override
  Widget build(BuildContext context) {
    final f = fahrten;
    final fahrtenKm = f?.values.fold<double>(0, (s, t) => s + t.kmFahrten);
    final anzahlFahrten = f?.values.fold<int>(
      0,
      (s, t) => s + t.fahrten.length,
    );
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
        // Summe der Fahrten aus der Kette (nur geroutete Strecken und
        // erfasste Anfahrten, keine Schätzung) — neben «Total km» vom
        // Zähler; die Differenz je Tag steht in der Liste.
        _KennzahlKarte(
          label: 'Fahrten-km (Kette)',
          wert: fahrtenKm == null ? '–' : '${fahrtenKm.round()}',
          zusatz: anzahlFahrten != null
              ? '$anzahlFahrten Fahrten an ${f!.length} Tagen'
              : (fahrtenGescheitert ? null : 'wird berechnet'),
          icon: Icons.directions_car_outlined,
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

/// 'YYYY-MM-DD' für den Pfad des Fahrten-Screens.
String _datumPfad(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// «Fahrten 132 km · Δ +16 km» — Δ = Zähler − Fahrten, rot, wenn ausserhalb
/// der Toleranz (`differenzIstAuffaellig`), sonst grau. Ohne Zählerstand nur
/// die Fahrten-km. Fehlen Strecken, steht die Lücke statt des Δ da
/// («Fahrten 70 km (1 ohne Strecke)») — seit 29.09.2026 gibt es keine
/// Luftlinien-km mehr, die sie füllten.
class _FahrtenAngabe extends StatelessWidget {
  final TagesFahrten f;

  const _FahrtenAngabe({required this.f});

  /// Erst auf ganze km runden, dann das Vorzeichen wählen — sonst stünde bei
  /// −0.4 ein «Δ −0 km». Null heisst «±0».
  static String _delta(double d) {
    final km = d.round();
    if (km == 0) return '±0';
    return '${km < 0 ? '−' : '+'}${km.abs()}';
  }

  @override
  Widget build(BuildContext context) {
    final d = f.differenz; // null, solange Strecken fehlen
    final ohne = f.fahrtenOhneKm;
    final luecke = ohne > 0 ? ' ($ohne ohne Strecke)' : '';
    const grau = TextStyle(fontSize: 11, color: AppColors.textSecondary);
    return Text.rich(
      TextSpan(
        style: grau,
        children: [
          TextSpan(text: 'Fahrten ${f.kmFahrten.round()} km$luecke'),
          if (d != null) ...[
            const TextSpan(text: ' · '),
            TextSpan(
              text: 'Δ ${_delta(d)} km',
              style: f.differenzAuffaellig
                  ? const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _TagesZeile extends StatelessWidget {
  final Arbeitstagsdaten t;

  /// `null`, solange die Fahrten laden (dann keine Angabe statt «0 km»).
  final TagesFahrten? fahrten;

  const _TagesZeile({required this.t, required this.fahrten});

  @override
  Widget build(BuildContext context) {
    final km = tagesKm(kmStart: t.kmStart, kmEnde: t.kmEnde);
    final minuten = arbeitsMinuten(beginn: t.beginn, ende: t.ende);
    final f = fahrten;
    // Halb erfasste Tage zeigen die vorhandene Hälfte mit '?' auf der anderen
    // Seite — so ist auf einen Blick klar, was nachzutragen wäre.
    final zeitraum = (t.beginn == null && t.ende == null)
        ? null
        : '${t.beginn ?? '?'}–${t.ende ?? '?'}';

    // InkWell IN der Card (clip), damit die Welle auf der Karte liegt.
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/auswertungen/arbeitstage/${_datumPfad(t.datum)}/fahrten',
        ),
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
                        '${t.besuche} '
                            '${t.besuche == 1 ? 'Besuch' : 'Besuche'}',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (f != null) _FahrtenAngabe(f: f),
                  ],
                ),
              ),
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
