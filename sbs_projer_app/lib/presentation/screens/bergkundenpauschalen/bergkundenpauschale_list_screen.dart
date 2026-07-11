import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/bergkundenpauschale_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/bergkundenpauschale_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';

final _nf = NumberFormat('#,##0', 'de_CH');
String _chf(double v) => '${_nf.format(v.round())} CHF';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class BergkundenpauschaleListScreen extends ConsumerStatefulWidget {
  const BergkundenpauschaleListScreen({super.key});

  @override
  ConsumerState<BergkundenpauschaleListScreen> createState() =>
      _BergkundenpauschaleListScreenState();
}

class _BergkundenpauschaleListScreenState
    extends ConsumerState<BergkundenpauschaleListScreen> {
  String _searchQuery = '';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0; // 0 = alle

  @override
  Widget build(BuildContext context) {
    final pauschalen = ref.watch(bergkundenpauschaleProvider);
    final betriebNames = ref.watch(betriebNameMapProvider);
    final betriebOrte = ref.watch(betriebOrtMapProvider);

    // Verfügbare Jahre
    final jahreSet = <int>{};
    for (final p in pauschalen) {
      jahreSet.add(p.datum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    // Sortieren nach Datum (neueste zuerst)
    final sorted = List<BergkundenpauschaleLocal>.from(pauschalen)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    // Filter
    final filtered = sorted.where((p) {
      if (p.datum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && p.datum.month != _selectedMonth) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName =
            betriebNames[p.betriebId]?.toLowerCase() ?? '';
        return betriebName.contains(query) ||
            (betriebOrte[p.betriebId]?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Monats- und Tagesgruppierung
    final groups = <_MonatsGruppe>[];
    for (final p in filtered) {
      final m = p.datum.month;
      final d = DateTime(p.datum.year, p.datum.month, p.datum.day);
      if (groups.isEmpty || groups.last.monat != m) {
        groups.add(_MonatsGruppe(jahr: p.datum.year, monat: m));
      }
      final g = groups.last;
      if (g.tage.isEmpty || g.tage.last.datum != d) {
        g.tage.add(_TagesGruppe(datum: d));
      }
      g.tage.last.eintraege.add(p);
    }

    // Jahressumme
    final jahrSumme = filtered.fold(0.0, (sum, p) => sum + p.betrag);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bergkundenpauschalen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Bergkunde suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
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
                  : '${filtered.length} Pauschalen',
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
                      final entry = item as BergkundenpauschaleLocal;
                      return _PauschaleListItem(
                        pauschale: entry,
                        betriebName: betriebNames[entry.betriebId],
                        betriebOrt: betriebOrte[entry.betriebId],
                        onTap: () => context.push(
                            '/bergkundenpauschalen/${entry.routeId}'),
                      );
                    },
                  ),
          ),
        ],
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
            sum + t.eintraege.fold(0.0, (s, p) => s + p.betrag));
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
    final summe =
        gruppe.eintraege.fold(0.0, (sum, p) => sum + p.betrag);
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
          Icon(Icons.landscape_outlined,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Keine Ergebnisse'
                : 'Keine Bergkundenpauschalen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Versuche einen anderen Suchbegriff oder Filter'
                : 'Werden automatisch bei Reinigungen von Bergkunden erstellt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
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
  final List<BergkundenpauschaleLocal> eintraege = [];
  _TagesGruppe({required this.datum});
}

class _PauschaleListItem extends StatelessWidget {
  final BergkundenpauschaleLocal pauschale;
  final String? betriebName;
  final String? betriebOrt;
  final VoidCallback onTap;

  const _PauschaleListItem({
    required this.pauschale,
    this.betriebName,
    this.betriebOrt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(25),
          child: const Icon(Icons.landscape, color: AppColors.primary, size: 20),
        ),
        title: Text(
          betriebOrt != null
              ? '$betriebOrt – ${betriebName ?? 'Unbekannt'}'
              : betriebName ?? 'Unbekannt',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pauschale.abgerechnet)
              const Icon(Icons.check_circle, size: 16, color: AppColors.success),
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
    if (betriebOrt != null) parts.add(betriebOrt!);
    parts.add(_formatDate(pauschale.datum));
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
