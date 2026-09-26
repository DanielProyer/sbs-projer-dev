import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/einsatz_start.dart';
import 'package:sbs_projer_app/presentation/providers/heute_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tagesuebersicht_provider.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

const _wochentage = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
  'Freitag', 'Samstag', 'Sonntag',
];

/// Betrag ohne Rappen, mit Schweizer Tausender-Apostroph: 105084.25 → 105'084.
///
/// Die Jahreswerte sind sechsstellig; ohne Trennzeichen sind sie in einer
/// 11-px-Zeile nicht mehr auf einen Blick zu lesen. Rappen braucht die
/// Kopfzeile nicht — genau wird es in der Buchhaltung.
String _ganz(double v) => chf(v).split('.').first;

/// Stil der Vorjahres-Angabe: bewusst leiser als der Wert davor, sie ist
/// Einordnung und nicht die Hauptzahl.
final _vergleichStil = TextStyle(
  fontSize: 11,
  color: AppColors.textSecondary.withValues(alpha: 0.75),
);

const _wertStil = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: AppColors.textSecondary,
);

/// Eine Umsatzzeile: der Wert, dahinter in Grau der Vergleich zum Vorjahr.
///
/// `Text.rich` statt zwei Texten nebeneinander, damit beide zusammen
/// umbrechen bzw. gekürzt werden und die Zeile rechtsbündig bleibt.
class _UmsatzZeile extends StatelessWidget {
  final String wert;
  final String? vorjahr;

  const _UmsatzZeile({required this.wert, this.vorjahr});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: wert, style: _wertStil),
          if (vorjahr != null)
            TextSpan(text: '  ·  Vj $vorjahr', style: _vergleichStil),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
  }
}

/// Darstellung ohne Datenanbindung — so ist sie ohne Supabase testbar.
class HeuteListeInhalt extends StatelessWidget {
  final List<TourEintrag> stopps;
  final int erledigt;
  final int gesamt;
  final void Function(TourEintrag) onStart;
  final void Function(TourEintrag) onOeffnen;
  final VoidCallback onTourenplan;
  final DateTime? heute;
  // Vorgabewert 0 zwingend: sonst würde der Parameter verpflichtend und alle
  // bestehenden Tests in heute_liste_test.dart bräuchen ihn nachgetragen.
  final double monatsUmsatzCHF;

  /// Umsatz des heutigen Tages über alle Einsatzarten — dieselbe Zahl, die
  /// die alte Tagesübersicht als Chip zeigte (Daniel 14.09.2026: «was mir in
  /// der App noch fehlt ist ein Überblick über den Tagesumsatz wie wir ihn
  /// vorher hatten»). Beim Umbau auf die Heute-Liste war nur der
  /// Monatsumsatz mitgenommen worden.
  final double tagesUmsatzCHF;

  /// Umsatz im selben Zeitraum des Vorjahres (gleicher Monat bis zum heutigen
  /// Tag) — als Einordnung unter dem Monatswert.
  final double vorjahrUmsatzCHF;

  /// Umsatz seit dem 1. Januar bis heute.
  final double jahrUmsatzCHF;

  /// Derselbe Zeitraum im Vorjahr: 1. Januar bis zum gleichen Kalendertag.
  final double vorjahrJahrUmsatzCHF;

  const HeuteListeInhalt({
    super.key,
    required this.stopps,
    required this.erledigt,
    required this.gesamt,
    required this.onStart,
    required this.onOeffnen,
    required this.onTourenplan,
    this.heute,
    this.monatsUmsatzCHF = 0,
    this.tagesUmsatzCHF = 0,
    this.vorjahrUmsatzCHF = 0,
    this.jahrUmsatzCHF = 0,
    this.vorjahrJahrUmsatzCHF = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tag = heute ?? DateTime.now();
    final datumStr =
        '${_wochentage[tag.weekday - 1].substring(0, 2)}, '
        '${tag.day.toString().padLeft(2, '0')}.'
        '${tag.month.toString().padLeft(2, '0')}.';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // `spaceBetween` schiebt die Umsatzzahlen an den rechten
              // Kartenrand, ohne dass eine Hälfte den Platz der anderen
              // frisst: Beide Seiten nehmen nur ihre natürliche Breite, die
              // Lücke dazwischen wächst. Mit `Expanded` links standen die
              // Zahlen in der Mitte, mit `flex: 0` rechts liefen sie über.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.today, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                // Links `flex: 0` — Datum und Fortschritt bekommen ihre
                // natürliche Breite und werden nie gekürzt. Sie sind in der
                // Länge begrenzt («Mo, 14.09.» plus höchstens «13 von 13»),
                // ein Überlauf droht von dieser Seite nicht. Mit einem
                // Flex-Anteil stand dort «Mo, 14…».
                Flexible(
                  flex: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          datumStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (gesamt > 0) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$erledigt von $gesamt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Gerettet aus der alten _TagesUebersicht (vor Task 10 hier
                // ersetzt): Tages- und Monatsumsatz brauchen weiterhin einen
                // Platz auf der Startseite, nur eben in dieser Kopfzeile
                // statt in der eigenen Karte. Der Tagesumsatz steht oben und
                // in der Akzentfarbe — er ist die Zahl, die Daniel abends
                // sucht; der Monatsumsatz ist der Zusammenhang dazu.
                if (tagesUmsatzCHF > 0 ||
                    monatsUmsatzCHF > 0 ||
                    jahrUmsatzCHF > 0) ...[
                  const SizedBox(width: 8),
                  // Rechts `flex: 1` — der Block nimmt den verbleibenden
                  // Platz, richtet seinen Text rechtsbündig darin aus und
                  // kürzt notfalls. Wird es eng, verliert lieber die
                  // Vergleichszahl ein paar Stellen als das Datum.
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tagesUmsatzCHF > 0)
                          Text(
                            '${_ganz(tagesUmsatzCHF)} CHF heute',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        // Vorjahr steht in derselben Zeile wie sein
                        // Bezugswert (Daniel 14.09.) — aus fünf Zeilen werden
                        // drei, und die Zuordnung ergibt sich nicht mehr nur
                        // aus der Reihenfolge. Beide Vergleichswerte messen
                        // denselben Zeitraum wie der Wert davor: gleicher
                        // Monat bzw. ab 1. Januar, jeweils nur bis zum
                        // heutigen Kalendertag. Sonst stünde ein halber Monat
                        // gegen einen vollen.
                        if (monatsUmsatzCHF > 0)
                          _UmsatzZeile(
                            wert: '${_ganz(monatsUmsatzCHF)} / Monat',
                            vorjahr: vorjahrUmsatzCHF > 0
                                ? _ganz(vorjahrUmsatzCHF)
                                : null,
                          ),
                        if (jahrUmsatzCHF > 0)
                          _UmsatzZeile(
                            wert: '${_ganz(jahrUmsatzCHF)} / Jahr',
                            vorjahr: vorjahrJahrUmsatzCHF > 0
                                ? _ganz(vorjahrJahrUmsatzCHF)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (gesamt == 0)
              _Leerzustand(onTourenplan: onTourenplan)
            else if (stopps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Alles erledigt für heute',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              )
            else
              // Kein eigener Scrollbereich: Entscheid Daniel 13.09.2026,
              // morgens sollen alle offenen Stopps sichtbar sein — Kürzen
              // oder Verstecken hinter einem zweiten Scrollbalken kommt
              // nicht infrage, das würde auf dem Handy zudem die Wischgeste
              // der scrollenden Startseite abfangen. Die Karte darf beliebig
              // hoch werden, weil sie in deren `ListView` liegt (unbegrenzte
              // Höhe je Kachel) — die Seite scrollt einfach weiter.
              for (var i = 0; i < stopps.length; i++)
                _StoppZeile(
                  eintrag: stopps[i],
                  position: i + 1,
                  onStart: () => onStart(stopps[i]),
                  onOeffnen: () => onOeffnen(stopps[i]),
                ),
            if (gesamt > 0)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTourenplan,
                child: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Im Tourenplan öffnen',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Eine Zeile des Tagesplans — bewusst aus `InkWell` + `Container` + `Row`
/// statt `ListTile`: CanvasKit-Web hat Material-Komfort-Widgets in dieser App
/// schon dreimal unsichtbar oder unklickbar gerendert (siehe CLAUDE.md).
class _StoppZeile extends StatelessWidget {
  final TourEintrag eintrag;
  final int position;
  final VoidCallback onStart;
  final VoidCallback onOeffnen;

  const _StoppZeile({
    required this.eintrag,
    required this.position,
    required this.onStart,
    required this.onOeffnen,
  });

  @override
  Widget build(BuildContext context) {
    // Uhrzeit nur, wo ein Termin-Anker gesetzt ist. Eine gerechnete
    // Ankunftszeit gibt es hier bewusst nicht — die entsteht erst in der
    // Zeitachse des Tourenplans (Spec 13.09.2026).
    final marke = eintrag.ankerZeit ?? '$position.';
    final untertitel = [
      if (eintrag.betriebOrt != null && eintrag.betriebOrt!.isNotEmpty)
        eintrag.betriebOrt!,
      if (eintrag.anlageIds.length > 1) '${eintrag.anlageIds.length} Anlagen',
      if (eintrag.servicezeit != null) eintrag.servicezeit!,
    ].join(' · ');

    return InkWell(
      onTap: onOeffnen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x11000000))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                marke,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eintrag.betriebName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (untertitel.isNotEmpty)
                    Text(
                      untertitel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            // Mindestens 48x48 als Tippfläche: Die ganze Zeile ist tippbar
            // und öffnet den Betrieb — ein danebengegangener Tipp auf den
            // Pfeil landet also auf der falschen Aktion. Daniel bedient das
            // Handy einhändig im Keller, oft mit nassen Händen.
            GestureDetector(
              key: Key('heute_start_${eintrag.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onStart,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.play_arrow,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Leerzustand extends StatelessWidget {
  final VoidCallback onTourenplan;
  const _Leerzustand({required this.onTourenplan});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Kein Tagesplan für heute',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTourenplan,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              'Plan erstellen',
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Angebundene Fassung für den Startbildschirm.
class HeuteListe extends ConsumerWidget {
  const HeuteListe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offen = ref.watch(heuteOffeneStoppsProvider);
    final zaehler = ref.watch(heuteZaehlerProvider);
    final uebersicht = ref.watch(tagesUebersichtProvider);
    final monatsUmsatzCHF = uebersicht.monatsUmsatzCHF;
    // `totalCHF` zählt alle heute erfassten Einsatzarten zusammen, nicht nur
    // die Reinigungen aus dem Tagesplan — genau wie in der alten Karte.
    final tagesUmsatzCHF = uebersicht.totalCHF;

    return offen.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stopps) => HeuteListeInhalt(
        stopps: stopps,
        erledigt: zaehler?.erledigt ?? 0,
        gesamt: zaehler?.gesamt ?? 0,
        monatsUmsatzCHF: monatsUmsatzCHF,
        tagesUmsatzCHF: tagesUmsatzCHF,
        vorjahrUmsatzCHF: uebersicht.vorjahrUmsatzCHF,
        jahrUmsatzCHF: uebersicht.jahrUmsatzCHF,
        vorjahrJahrUmsatzCHF: uebersicht.vorjahrJahrUmsatzCHF,
        onStart: (e) => _starte(context, e),
        onOeffnen: (e) {
          if (e.betriebId != null) context.push('/betriebe/${e.betriebId}');
        },
        onTourenplan: () => context.push('/touren'),
      ),
    );
  }

  /// Ein Start-Weg für alle Stopps (V3): eine geplante Störung/Montage öffnet
  /// den Einsatz selbst, eine Saison-Reinigung bringt ihre Service-Art mit.
  void _starte(BuildContext context, TourEintrag e) {
    if (e.betriebId == null && geplanteEinsatzId(e) == null) return;
    context.push(startRoute(e));
  }
}
