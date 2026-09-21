import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/offene_pro_betrieb.dart';
import 'package:sbs_projer_app/core/util/rechnung_zustellung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart'
    show betriebNameMapProvider, betriebOrtMapProvider;
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';

/// Offene Rechnungen, gebündelt pro Betrieb, wahlweise auf ein Jahr begrenzt.
///
/// WARUM als eigener Screen (21.09.2026, Wunsch Daniel): Der Forderungen-Hub
/// gruppiert nach Monat und Tag. Vor einem Anruf beim Wirt braucht es die
/// andere Achse — alles, was DIESER Betrieb offen hat, auf einem Blick.
///
/// Die Zustellung steht bewusst an jeder Zeile. Eine offene Rechnung ohne
/// Übergabe- und ohne Versanddatum ist kein Zahlungsverzug, sondern der
/// Verdacht, dass der Kunde sie nie gesehen hat. Mahnen wäre dort der falsche
/// Schritt.
class OffenProBetriebScreen extends ConsumerStatefulWidget {
  const OffenProBetriebScreen({super.key});

  @override
  ConsumerState<OffenProBetriebScreen> createState() =>
      _OffenProBetriebScreenState();
}

class _OffenProBetriebScreenState extends ConsumerState<OffenProBetriebScreen> {
  /// null = alle Jahre. Vorbelegt mit dem laufenden Jahr.
  int? _jahr = DateTime.now().year;
  final _offen = <String>{};
  String _suche = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rechnungenStreamProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Offen pro Betrieb  ·  v$kAppVersion')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Fehler beim Laden: $e'),
          ),
        ),
        data: (alle) => _inhalt(alle),
      ),
    );
  }

  Widget _inhalt(List<Rechnung> alle) {
    final namen = ref.watch(betriebNameMapProvider);
    final orte = ref.watch(betriebOrtMapProvider);

    // Jahre aus den OFFENEN Rechnungen ableiten, nicht aus allen — sonst
    // stehen Jahrgänge zur Wahl, die längst bezahlt sind und eine leere Liste
    // ergeben.
    final jahre =
        alle.where(istOffen).map((r) => r.rechnungsdatum.year).toSet().toList()
          ..sort((a, b) => b.compareTo(a));

    var gruppen = offeneProBetrieb(
      alle: alle,
      jahr: _jahr,
      namen: namen,
      orte: orte,
    );
    if (_suche.trim().isNotEmpty) {
      final q = _suche.toLowerCase().trim();
      gruppen = gruppen
          .where(
            (g) =>
                g.name.toLowerCase().contains(q) ||
                (g.ort ?? '').toLowerCase().contains(q),
          )
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _kopf(gruppen),
        ),
        AppFilterBar(
          items: [
            AppFilterDropdown<int>(
              hint: 'Alle Jahre',
              value: _jahr,
              options: [for (final j in jahre) (j, '$j')],
              onChanged: (v) => setState(() {
                _jahr = v;
                _offen.clear();
              }),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SearchBar(
            hintText: 'Betrieb oder Ort suchen',
            leading: const Icon(Icons.search, size: 20),
            onChanged: (v) => setState(() => _suche = v),
          ),
        ),
        Expanded(
          child: gruppen.isEmpty
              ? _leer()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: gruppen.length,
                  itemBuilder: (_, i) => _betriebKarte(gruppen[i]),
                ),
        ),
      ],
    );
  }

  Widget _leer() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            _suche.trim().isNotEmpty
                ? 'Kein Betrieb passt zur Suche.'
                : _jahr == null
                ? 'Keine offenen Rechnungen.'
                : 'Keine offenen Rechnungen aus $_jahr.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _kopf(List<BetriebOffen> gruppen) {
    final summe = gruppen.fold<double>(0, (s, g) => s + g.summe);
    final rechnungen = gruppen.fold<int>(0, (s, g) => s + g.anzahl);
    final ohne = gruppen.fold<int>(0, (s, g) => s + g.ohneZustellung);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _jahr == null ? 'Offen, alle Jahre' : 'Offen aus $_jahr',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  chf(summe),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                '${gruppen.length} '
                '${gruppen.length == 1 ? 'Betrieb' : 'Betriebe'} '
                '· $rechnungen Rg.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (ohne > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.help_outline, size: 15, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$ohne ohne Zustellnachweis — vor dem Mahnen prüfen, '
                    'ob die Rechnung je beim Kunden war.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Aufklappbare Betriebskarte.
  ///
  /// Bewusst GestureDetector + Container statt ExpansionTile: Letzteres hat auf
  /// dem produktiv genutzten CanvasKit-Web schon Titel und Untertitel gar nicht
  /// gezeichnet (13.08.2026, Stand-Übersicht). `test/canvaskit_sichere_widgets_test.dart`
  /// hält die Regel fest.
  Widget _betriebKarte(BetriebOffen g) {
    final key = g.betriebId ?? '__ohne__';
    final aufgeklappt = _offen.contains(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              aufgeklappt ? _offen.remove(key) : _offen.add(key);
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if ((g.ort ?? '').isNotEmpty) g.ort!,
                            '${g.anzahl} Rg.',
                            'ab ${_datum(g.aeltestes)}',
                            if (g.ohneZustellung > 0)
                              '${g.ohneZustellung} ohne Zustellung',
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: g.ohneZustellung > 0
                                ? AppColors.warning
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    chf(g.summe),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Icon(
                    aufgeklappt ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (aufgeklappt)
            for (final r in g.rechnungen) _rechnungZeile(r),
        ],
      ),
    );
  }

  Widget _rechnungZeile(Rechnung r) {
    final zustellung = zustellungsText(
      uebergebenAm: r.uebergebenAm,
      versendetAm: r.versendetAm,
    );
    final nieZugestellt = r.uebergebenAm == null && r.versendetAm == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/rechnungen/${r.id}'),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.rechnungsnummer ?? 'Entwurf'} · ${_datum(r.rechnungsdatum)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${versandartKurz(r.versandart)} · $zustellung',
                    style: TextStyle(
                      fontSize: 11,
                      color: nieZugestellt
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontWeight: nieZugestellt
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chf(r.betragBrutto),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.zahlungsstatus,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _datum(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
