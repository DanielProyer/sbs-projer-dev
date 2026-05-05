import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/eigenauftrag_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final _nf = NumberFormat('#,##0', 'de_CH');
String _chf(double v) => '${_nf.format(v.round())} CHF';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class EigenauftragListScreen extends ConsumerStatefulWidget {
  const EigenauftragListScreen({super.key});

  @override
  ConsumerState<EigenauftragListScreen> createState() =>
      _EigenauftragListScreenState();
}

class _EigenauftragListScreenState
    extends ConsumerState<EigenauftragListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final eigenauftraege = ref.watch(eigenauftraegeProvider);
    final betriebe = ref.watch(betriebeProvider);

    final betriebNames = <String, String>{};
    final betriebOrte = <String, String>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebNames[b.serverId!] = b.name;
        if (b.ort != null) betriebOrte[b.serverId!] = b.ort!;
      }
    }

    // Verfügbare Jahre
    final jahreSet = <int>{};
    for (final e in eigenauftraege) {
      jahreSet.add(e.datum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<EigenauftragLocal>.from(eigenauftraege)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    final filtered = sorted.where((e) {
      if (e.datum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && e.datum.month != _selectedMonth) return false;
      if (_statusFilter != 'alle' && e.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName =
            (e.betriebId != null ? betriebNames[e.betriebId!] : null)
                    ?.toLowerCase() ??
                '';
        final betriebOrt =
            (e.betriebId != null ? betriebOrte[e.betriebId!] : null)
                    ?.toLowerCase() ??
                '';
        return betriebName.contains(query) ||
            betriebOrt.contains(query) ||
            e.stoerungsnummer.toLowerCase().contains(query) ||
            e.problemBeschreibung.toLowerCase().contains(query) ||
            (e.notizen?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Monats- und Tagesgruppierung
    final groups = <_MonatsGruppe>[];
    for (final e in filtered) {
      final m = e.datum.month;
      final d = DateTime(e.datum.year, e.datum.month, e.datum.day);
      if (groups.isEmpty || groups.last.monat != m) {
        groups.add(_MonatsGruppe(jahr: e.datum.year, monat: m));
      }
      final g = groups.last;
      if (g.tage.isEmpty || g.tage.last.datum != d) {
        g.tage.add(_TagesGruppe(datum: d));
      }
      g.tage.last.eintraege.add(e);
    }

    final jahrSumme =
        filtered.fold(0.0, (sum, e) => sum + (e.pauschale ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eigenaufträge'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              _filterItem('alle', 'Alle'),
              _filterItem('behoben', 'Behoben'),
              _filterItem('nicht_behebbar', 'Nicht behebbar'),
              _filterItem('nachbearbeitung_noetig', 'Nachbearbeitung'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Eigenauftrag suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                  items: jahre
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (y) {
                    if (y != null) setState(() => _selectedYear = y);
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedMonth,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                  items: [
                    const DropdownMenuItem(
                        value: 0, child: Text('Alle Monate')),
                    for (int m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text(_monatNamen[m])),
                  ],
                  onChanged: (m) {
                    if (m != null) setState(() => _selectedMonth = m);
                  },
                ),
                const Spacer(),
                Text(
                  jahrSumme > 0
                      ? '${filtered.length} – ${_chf(jahrSumme)}'
                      : '${filtered.length} Eigenaufträge',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (_statusFilter != 'alle')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text(_statusFilter),
                    onDeleted: () =>
                        setState(() => _statusFilter = 'alle'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
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
                      final entry = item as EigenauftragLocal;
                      return _EigenauftragListItem(
                        eigenauftrag: entry,
                        betriebName: entry.betriebId != null
                            ? betriebNames[entry.betriebId!]
                            : null,
                        betriebOrt: entry.betriebId != null
                            ? betriebOrte[entry.betriebId!]
                            : null,
                        onTap: () =>
                            context.push('/eigenauftraege/${entry.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/eigenauftraege/neu'),
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
            t.eintraege.fold(0.0, (s, e) => s + (e.pauschale ?? 0)));
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
        .fold(0.0, (sum, e) => sum + (e.pauschale ?? 0));
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

  PopupMenuItem<String> _filterItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_statusFilter == value)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Eigenaufträge',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Erfasse einen neuen Eigenauftrag mit dem + Button',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MonatsGruppe {
  final int jahr;
  final int monat;
  final List<_TagesGruppe> tage = [];
  _MonatsGruppe({required this.jahr, required this.monat});
}

class _TagesGruppe {
  final DateTime datum;
  final List<EigenauftragLocal> eintraege = [];
  _TagesGruppe({required this.datum});
}

class _EigenauftragListItem extends StatelessWidget {
  final EigenauftragLocal eigenauftrag;
  final String? betriebName;
  final String? betriebOrt;
  final VoidCallback onTap;

  const _EigenauftragListItem({
    required this.eigenauftrag,
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
          child: Text(
            eigenauftrag.stoerungsnummer.padLeft(3, '0'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _statusColor,
            ),
          ),
        ),
        title: Text(
          betriebOrt != null
              ? '$betriebOrt – ${betriebName ?? 'Unbekannt'}'
              : betriebName ?? eigenauftrag.stoerungsnummer,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!eigenauftrag.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            if (eigenauftrag.status == 'behoben')
              const Icon(Icons.check_circle,
                  size: 16, color: AppColors.success),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    parts.add(eigenauftrag.stoerungsnummer);
    parts.add(_formatDate(eigenauftrag.datum));
    if (eigenauftrag.pauschale != null) {
      parts.add(_chf(eigenauftrag.pauschale!));
    }
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color get _statusColor {
    switch (eigenauftrag.status) {
      case 'behoben':
        return AppColors.success;
      case 'nicht_behebbar':
        return AppColors.inaktiv;
      case 'nachbearbeitung_noetig':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
}
