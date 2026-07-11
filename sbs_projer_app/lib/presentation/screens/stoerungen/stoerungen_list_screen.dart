import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/stoerung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final _nf = NumberFormat('#,##0', 'de_CH');
String _chf(double v) => '${_nf.format(v.round())} CHF';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class StoerungenListScreen extends ConsumerStatefulWidget {
  const StoerungenListScreen({super.key});

  @override
  ConsumerState<StoerungenListScreen> createState() =>
      _StoerungenListScreenState();
}

class _StoerungenListScreenState
    extends ConsumerState<StoerungenListScreen> {
  String _searchQuery = '';
  String? _anlagenTypFilter; // null = alle, 'ohne' = ohne Anlagentyp
  String _kmFilter = 'alle'; // 'alle' | 'mit' | 'ohne'
  int? _bereichFilter; // null = alle; 1..5 = Störungsbereich
  Set<String> _selectedRegionIds = {};
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final stoerungen = ref.watch(stoerungenProvider);
    final betriebNames = ref.watch(betriebNameMapProvider);
    final betriebOrte = ref.watch(betriebOrtMapProvider);
    final betriebRegionIds = ref.watch(betriebRegionIdMapProvider);
    final regionen = ref.watch(regionenProvider);

    // Anlagentyp-Optionen (dynamisch) + Zombie-Schutz gegen weggefallene Typen.
    final anlagenTypen = stoerungen
        .map((s) => s.anlageTyp)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final hatOhneTyp = stoerungen.any((s) => s.anlageTyp == null);
    final gueltigeTypen = {
      ...anlagenTypen,
      if (hatOhneTyp) 'ohne',
    };
    final effektiverTyp = (_anlagenTypFilter == null ||
            gueltigeTypen.contains(_anlagenTypFilter))
        ? _anlagenTypFilter
        : null;

    // Region-Filter (Störung -> Betrieb -> Region), Zombie-Schutz.
    final regionOptionIds = {
      for (final r in regionen)
        if (r.serverId != null) r.serverId!,
    };
    final aktiveRegionIds = _selectedRegionIds.intersection(regionOptionIds);

    // Verfügbare Jahre
    final jahreSet = <int>{};
    for (final s in stoerungen) {
      jahreSet.add(s.datum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<StoerungLocal>.from(stoerungen)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    final filtered = sorted.where((s) {
      if (s.datum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && s.datum.month != _selectedMonth) return false;
      if (effektiverTyp != null) {
        if (effektiverTyp == 'ohne') {
          if (s.anlageTyp != null) return false;
        } else if (s.anlageTyp != effektiverTyp) {
          return false;
        }
      }
      if (_kmFilter == 'mit' && !s.istKilometerabrechnung) return false;
      if (_kmFilter == 'ohne' && s.istKilometerabrechnung) return false;
      if (_bereichFilter != null &&
          !(s.stoerungBereiche?.contains(_bereichFilter) ?? false)) {
        return false;
      }
      if (aktiveRegionIds.isNotEmpty) {
        final regionId =
            s.betriebId != null ? betriebRegionIds[s.betriebId!] : null;
        if (regionId == null || !aktiveRegionIds.contains(regionId)) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName =
            (s.betriebId != null ? betriebNames[s.betriebId!] : null)
                    ?.toLowerCase() ??
                '';
        final betriebOrt =
            (s.betriebId != null ? betriebOrte[s.betriebId!] : null)
                    ?.toLowerCase() ??
                '';
        return betriebName.contains(query) ||
            betriebOrt.contains(query) ||
            (s.stoerungsnummer?.toLowerCase().contains(query) ?? false) ||
            (s.referenzNr?.toLowerCase().contains(query) ?? false) ||
            s.problemBeschreibung.toLowerCase().contains(query) ||
            (s.notizen?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Monats- und Tagesgruppierung
    final groups = <_MonatsGruppe>[];
    for (final s in filtered) {
      final m = s.datum.month;
      final d = DateTime(s.datum.year, s.datum.month, s.datum.day);
      if (groups.isEmpty || groups.last.monat != m) {
        groups.add(_MonatsGruppe(jahr: s.datum.year, monat: m));
      }
      final g = groups.last;
      if (g.tage.isEmpty || g.tage.last.datum != d) {
        g.tage.add(_TagesGruppe(datum: d));
      }
      g.tage.last.eintraege.add(s);
    }

    final jahrSumme =
        filtered.fold(0.0, (sum, s) => sum + (s.preisNetto ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Störungen'),
        actions: [
          // Region-Filter oben rechts (Störung über ihren Betrieb)
          if (regionen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: AppFilterMultiDropdown<String>(
                label: 'Regionen',
                options: [
                  for (final r in regionen)
                    if (r.serverId != null) (r.serverId!, r.name),
                ],
                selected: aktiveRegionIds,
                onChanged: (s) => setState(() => _selectedRegionIds = s),
              ).build(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Störung suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Drei gleich breite, zentrierte Filter-Spalten (Pixel 9):
          // Anlagentyp · Art · Störungsbereich
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: AppFilterDropdown<String>(
                    hint: 'Alle Typen',
                    isExpanded: true,
                    value: effektiverTyp,
                    options: [
                      for (final t in anlagenTypen) (t, _typLabel(t)),
                      if (hatOhneTyp) ('ohne', 'Ohne Typ'),
                    ],
                    onChanged: (v) => setState(() => _anlagenTypFilter = v),
                  ).build(context),
                ),
                const SizedBox(width: 8),
                // Art des Eintrags: Störung vs. reine Kilometerabrechnung
                Expanded(
                  child: AppFilterDropdown<String>(
                    hint: 'Alle Arten',
                    isExpanded: true,
                    nullable: false,
                    value: _kmFilter,
                    options: const [
                      ('ohne', 'Störung'),
                      ('mit', 'Kilometerabrechnung'),
                      ('alle', 'Alle Arten'),
                    ],
                    onChanged: (v) => setState(() => _kmFilter = v ?? 'alle'),
                  ).build(context),
                ),
                const SizedBox(width: 8),
                // Störungsbereich (1..5) – zeigt Störungen mit diesem Bereich.
                Expanded(
                  child: AppFilterDropdown<int>(
                    hint: 'Alle Bereiche',
                    isExpanded: true,
                    value: _bereichFilter,
                    options: const [
                      (1, '1 Zapfhahn'),
                      (2, '2 Leitung'),
                      (3, '3 Kühler'),
                      (4, '4 Zapfkopf'),
                      (5, '5 Gas'),
                    ],
                    onChanged: (v) => setState(() => _bereichFilter = v),
                  ).build(context),
                ),
              ],
            ),
          ),
          AppJahrMonatLeiste(
            jahre: jahre,
            selectedJahr: _selectedYear,
            onJahrChanged: (y) => setState(() => _selectedYear = y),
            selectedMonat: _selectedMonth,
            onMonatChanged: (m) => setState(() => _selectedMonth = m),
            trailing: Text(
              jahrSumme > 0
                  ? '${filtered.length} – ${_chf(jahrSumme)}'
                  : '${filtered.length} Störungen',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: _listItemCount(groups),
                    itemBuilder: (context, index) {
                      final item = _listItemAt(groups, index);
                      if (item is _MonatsGruppe) {
                        return _buildMonatsHeader(context, item);
                      }
                      if (item is _TagesGruppe) {
                        return _buildTagesHeader(context, item);
                      }
                      final entry = item as StoerungLocal;
                      return _StoerungListItem(
                        stoerung: entry,
                        betriebName: entry.betriebId != null
                            ? betriebNames[entry.betriebId!]
                            : null,
                        betriebOrt: entry.betriebId != null
                            ? betriebOrte[entry.betriebId!]
                            : null,
                        onTap: () =>
                            context.push('/stoerungen/${entry.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/stoerungen/neu'),
              child: const Icon(Icons.add),
            ),
    );
  }

  int _listItemCount(List<_MonatsGruppe> groups) {
    int count = 0;
    for (final g in groups) {
      count++;
      for (final t in g.tage) {
        count += 1 + t.eintraege.length;
      }
    }
    return count;
  }

  Object _listItemAt(List<_MonatsGruppe> groups, int index) {
    int pos = 0;
    for (final g in groups) {
      if (index == pos) return g;
      pos++;
      for (final t in g.tage) {
        if (index == pos) return t;
        pos++;
        if (index < pos + t.eintraege.length) {
          return t.eintraege[index - pos];
        }
        pos += t.eintraege.length;
      }
    }
    return groups.last;
  }

  Widget _buildMonatsHeader(BuildContext context, _MonatsGruppe gruppe) {
    final count =
        gruppe.tage.fold(0, (sum, t) => sum + t.eintraege.length);
    final summe = gruppe.tage.fold(
        0.0,
        (sum, t) =>
            sum +
            t.eintraege.fold(0.0, (s, e) => s + (e.preisNetto ?? 0)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_monatNamen[gruppe.monat]} ${gruppe.jahr}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          Text('$count St.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          if (summe > 0) ...[
            const SizedBox(width: 8),
            Text(_chf(summe),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildTagesHeader(BuildContext context, _TagesGruppe gruppe) {
    final count = gruppe.eintraege.length;
    final summe = gruppe.eintraege
        .fold(0.0, (sum, e) => sum + (e.preisNetto ?? 0));
    final tag =
        '${gruppe.datum.day.toString().padLeft(2, '0')}.${gruppe.datum.month.toString().padLeft(2, '0')}';
    const wt = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Text('${wt[gruppe.datum.weekday - 1]} $tag',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    )),
          ),
          Text('$count St.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 11)),
          if (summe > 0) ...[
            const SizedBox(width: 6),
            Text(_chf(summe),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Störungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Erfasse eine neue Störung mit dem + Button',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  String _typLabel(String typ) =>
      typ.isEmpty ? typ : typ[0].toUpperCase() + typ.substring(1);

}

class _MonatsGruppe {
  final int jahr;
  final int monat;
  final List<_TagesGruppe> tage = [];
  _MonatsGruppe({required this.jahr, required this.monat});
}

class _TagesGruppe {
  final DateTime datum;
  final List<StoerungLocal> eintraege = [];
  _TagesGruppe({required this.datum});
}

class _StoerungListItem extends StatelessWidget {
  final StoerungLocal stoerung;
  final String? betriebName;
  final String? betriebOrt;
  final VoidCallback onTap;

  const _StoerungListItem({
    required this.stoerung,
    this.betriebName,
    this.betriebOrt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child: stoerung.istKilometerabrechnung
              ? Icon(Icons.directions_car, color: _statusColor, size: 20)
              : stoerung.referenzNr != null
                  ? Text(
                      stoerung.referenzNr!.padLeft(3, '0'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    )
                  : Icon(Icons.warning_amber, color: _statusColor, size: 20),
        ),
        title: Text(
          stoerung.istKilometerabrechnung
              ? stoerung.problemBeschreibung
              : betriebOrt != null
                  ? '$betriebOrt – ${betriebName ?? 'Unbekannt'}'
                  : betriebName ?? stoerung.stoerungsnummer ?? 'Störung',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(stoerung.istKilometerabrechnung
            ? _buildKmSubtitle()
            : _buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!stoerung.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            if (stoerung.status == 'behoben')
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.success),
            if (stoerung.istPikettEinsatz)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.nightlight_round,
                    size: 16, color: AppColors.info),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _buildKmSubtitle() {
    final parts = <String>[];
    if (stoerung.stoerungBereiche != null && stoerung.stoerungBereiche!.isNotEmpty) {
      parts.add('Bereich ${stoerung.stoerungBereiche!.join(', ')}');
    }
    if (stoerung.preisNetto != null) {
      parts.add(_chf(stoerung.preisNetto!));
    }
    return parts.join(' · ');
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (stoerung.stoerungBereiche != null && stoerung.stoerungBereiche!.isNotEmpty) {
      parts.add('Bereich ${stoerung.stoerungBereiche!.join(', ')}');
    }
    if (stoerung.preisNetto != null) {
      parts.add(_chf(stoerung.preisNetto!));
    }
    return parts.join(' · ');
  }

  Color get _statusColor {
    switch (stoerung.status) {
      case 'offen':
        return AppColors.warning;
      case 'behoben':
        return AppColors.success;
      case 'nicht_behebbar':
        return AppColors.inaktiv;
      default:
        return AppColors.textSecondary;
    }
  }
}
