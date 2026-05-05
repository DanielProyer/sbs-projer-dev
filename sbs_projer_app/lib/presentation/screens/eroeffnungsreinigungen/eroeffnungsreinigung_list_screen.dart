import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/eroeffnungsreinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final _nf = NumberFormat('#,##0', 'de_CH');
String _chf(double v) => '${_nf.format(v.round())} CHF';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class EroeffnungsreinigungListScreen extends ConsumerStatefulWidget {
  const EroeffnungsreinigungListScreen({super.key});

  @override
  ConsumerState<EroeffnungsreinigungListScreen> createState() =>
      _EroeffnungsreinigungListScreenState();
}

class _EroeffnungsreinigungListScreenState
    extends ConsumerState<EroeffnungsreinigungListScreen> {
  String _searchQuery = '';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(eroeffnungsreinigungenProvider);
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
    for (final e in items) {
      jahreSet.add(e.datum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<EroeffnungsreinigungLocal>.from(items)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    final filtered = sorted.where((e) {
      if (e.datum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && e.datum.month != _selectedMonth) return false;
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
            e.stoerungsnummer.toLowerCase().contains(query);
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
        filtered.fold(0.0, (sum, e) => sum + (e.preis ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eröffnungsreinigungen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Suchen...',
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
                      : '${filtered.length} Einträge',
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
                      if (item is _TagesGruppe) {
                        return _buildTagesHeader(context, item);
                      }
                      final entry = item as EroeffnungsreinigungLocal;
                      return _ListItem(
                        item: entry,
                        betriebName: entry.betriebId != null
                            ? betriebNames[entry.betriebId!]
                            : null,
                        betriebOrt: entry.betriebId != null
                            ? betriebOrte[entry.betriebId!]
                            : null,
                        onTap: () => context.push(
                            '/eroeffnungsreinigungen/${entry.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  context.push('/eroeffnungsreinigungen/neu'),
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
            t.eintraege.fold(0.0, (s, e) => s + (e.preis ?? 0)));
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
        .fold(0.0, (sum, e) => sum + (e.preis ?? 0));
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
          Icon(Icons.cleaning_services_outlined,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Keine Ergebnisse'
                : 'Noch keine Eröffnungsreinigungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Versuche einen anderen Suchbegriff oder Filter'
                : 'Erfasse eine neue Eröffnungsreinigung mit dem + Button',
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
  final List<EroeffnungsreinigungLocal> eintraege = [];
  _TagesGruppe({required this.datum});
}

class _ListItem extends StatelessWidget {
  final EroeffnungsreinigungLocal item;
  final String? betriebName;
  final String? betriebOrt;
  final VoidCallback onTap;

  const _ListItem({
    required this.item,
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
          child: Text(
            item.stoerungsnummer.padLeft(3, '0'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(
          betriebOrt != null
              ? '$betriebOrt – ${betriebName ?? 'Unbekannt'}'
              : betriebName ?? item.stoerungsnummer,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.istBergkunde)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.terrain, size: 16, color: AppColors.warning),
              ),
            if (!item.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.cloud_upload_outlined,
                    size: 16, color: AppColors.warning),
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
    parts.add(item.stoerungsnummer);
    parts.add(_formatDate(item.datum));
    if (item.preis != null) {
      parts.add(_chf(item.preis!));
    }
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
