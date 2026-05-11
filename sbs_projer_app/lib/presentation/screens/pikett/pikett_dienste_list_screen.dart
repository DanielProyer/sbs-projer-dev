import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/pikett_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class PikettDiensteListScreen extends ConsumerStatefulWidget {
  const PikettDiensteListScreen({super.key});

  @override
  ConsumerState<PikettDiensteListScreen> createState() =>
      _PikettDiensteListScreenState();
}

class _PikettDiensteListScreenState
    extends ConsumerState<PikettDiensteListScreen> {
  String _searchQuery = '';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final dienste = ref.watch(pikettDiensteProvider);

    // Verfügbare Jahre (nach Montag der KW)
    final jahreSet = <int>{};
    for (final p in dienste) {
      jahreSet.add(_montagDerWoche(p.datumStart).year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<PikettDienstLocal>.from(dienste)
      ..sort((a, b) => b.datumStart.compareTo(a.datumStart));

    final filtered = sorted.where((p) {
      // Massgebend ist der Montag der KW, nicht datum_start (FR)
      final montag = _montagDerWoche(p.datumStart);
      if (montag.year != _selectedYear) return false;
      if (_selectedMonth != 0 && montag.month != _selectedMonth) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final kw = _kw(p.datumStart);
        return 'kw $kw'.contains(query) ||
            '$kw'.contains(query) ||
            _formatDate(p.datumStart).contains(query) ||
            _formatDate(p.datumEnde).contains(query);
      }
      return true;
    }).toList();

    // Monatsgruppierung (nach Montag der KW)
    final groups = <_MonatsGruppe>[];
    for (final p in filtered) {
      final montag = _montagDerWoche(p.datumStart);
      final m = montag.month;
      if (groups.isEmpty || groups.last.monat != m) {
        groups.add(_MonatsGruppe(jahr: montag.year, monat: m));
      }
      groups.last.eintraege.add(p);
    }

    double _getPreis(PikettDienstLocal p) =>
        p.pauschaleGesamt ?? p.pauschale ?? 0;

    final jahrSumme = filtered.fold(0.0, (sum, p) => sum + _getPreis(p));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pikett-Dienste'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'KW suchen...',
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
                      ? '${filtered.length} – ${jahrSumme.toStringAsFixed(2)} CHF'
                      : '${filtered.length} Pikett-Dienste',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
                      final entry = item as PikettDienstLocal;
                      return _PikettListItem(
                        pikett: entry,
                        onTap: () =>
                            context.push('/pikett/${entry.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/pikett/neu'),
              child: const Icon(Icons.add),
            ),
    );
  }

  int _listItemCount(List<_MonatsGruppe> groups) {
    int count = 0;
    for (final g in groups) {
      count += 1 + g.eintraege.length;
    }
    return count;
  }

  Object _listItemAt(List<_MonatsGruppe> groups, int index) {
    int pos = 0;
    for (final g in groups) {
      if (index == pos) return g;
      pos++;
      if (index < pos + g.eintraege.length) {
        return g.eintraege[index - pos];
      }
      pos += g.eintraege.length;
    }
    return groups.last;
  }

  Widget _buildMonatsHeader(BuildContext context, _MonatsGruppe gruppe) {
    final count = gruppe.eintraege.length;
    double getPreis(PikettDienstLocal p) =>
        p.pauschaleGesamt ?? p.pauschale ?? 0;
    final summe =
        gruppe.eintraege.fold(0.0, (sum, p) => sum + getPreis(p));
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
            Text('${summe.toStringAsFixed(2)} CHF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
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
          Icon(Icons.nightlight_round,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Keine Ergebnisse'
                : 'Noch keine Pikett-Dienste',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Versuche einen anderen Suchbegriff oder Filter'
                : 'Tippe auf + um einen Pikett-Dienst zu erfassen',
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
  final List<PikettDienstLocal> eintraege = [];
  _MonatsGruppe({required this.jahr, required this.monat});
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

/// Montag der ISO-Woche — UTC-Berechnung um DST-Fehler zu vermeiden.
DateTime _montagDerWoche(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final monday = d.subtract(Duration(days: d.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}

int _kw(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  return (thursday.difference(jan1).inDays / 7).floor() + 1;
}

class _PikettListItem extends StatelessWidget {
  final PikettDienstLocal pikett;
  final VoidCallback onTap;

  const _PikettListItem({
    required this.pikett,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(25),
          child: const Icon(
            Icons.nightlight_round,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          'KW ${_kw(pikett.datumStart)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!pikett.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    parts.add(
        'Fr ${_formatDate(pikett.datumStart)} / Sa ${_formatDate(pikett.datumEnde)}');
    if (pikett.pauschaleGesamt != null) {
      parts.add('${pikett.pauschaleGesamt!.toStringAsFixed(2)} CHF');
    } else if (pikett.pauschale != null) {
      parts.add('${pikett.pauschale!.toStringAsFixed(2)} CHF');
    }
    return parts.join(' · ');
  }
}
