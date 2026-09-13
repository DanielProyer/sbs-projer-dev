import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/heute_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tagesuebersicht_provider.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

const _wochentage = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
  'Freitag', 'Samstag', 'Sonntag',
];

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
              children: [
                const Icon(Icons.today, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  datumStr,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (gesamt > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$erledigt von $gesamt',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                // Gerettet aus der alten _TagesUebersicht (vor Task 10 hier
                // ersetzt): der Monatsumsatz braucht weiterhin einen Platz
                // auf der Startseite, nur eben in dieser Kopfzeile statt in
                // der eigenen Karte.
                if (monatsUmsatzCHF > 0) ...[
                  const Spacer(),
                  Text(
                    '${monatsUmsatzCHF.toStringAsFixed(0)} CHF / Monat',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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
            GestureDetector(
              key: Key('heute_start_${eintrag.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onStart,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(
                  Icons.play_arrow,
                  color: AppColors.primary,
                  size: 22,
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
    final monatsUmsatzCHF = ref.watch(tagesUebersichtProvider).monatsUmsatzCHF;

    return offen.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stopps) => HeuteListeInhalt(
        stopps: stopps,
        erledigt: zaehler?.erledigt ?? 0,
        gesamt: zaehler?.gesamt ?? 0,
        monatsUmsatzCHF: monatsUmsatzCHF,
        onStart: (e) => _starte(context, e),
        onOeffnen: (e) {
          if (e.betriebId != null) context.push('/betriebe/${e.betriebId}');
        },
        onTourenplan: () => context.push('/touren'),
      ),
    );
  }

  void _starte(BuildContext context, TourEintrag e) {
    if (e.betriebId == null) return;
    switch (e.typ) {
      case TourEintragTyp.reinigung:
        final ids = e.anlageIds.isNotEmpty
            ? e.anlageIds
            : [if (e.anlageId != null) e.anlageId!];
        context.push(
          '/reinigungen/neu?betriebId=${e.betriebId}&anlageIds=${ids.join(',')}',
        );
      case TourEintragTyp.stoerung:
        context.push('/stoerungen/neu?betriebId=${e.betriebId}');
      case TourEintragTyp.montage:
      case TourEintragTyp.heigenie:
        context.push('/montagen/neu?betriebId=${e.betriebId}');
    }
  }
}
