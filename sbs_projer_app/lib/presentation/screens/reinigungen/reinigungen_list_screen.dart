import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final _nf = NumberFormat('#,##0', 'de_CH');
String _chf(double v) => '${_nf.format(v.round())} CHF';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class ReinigungenListScreen extends ConsumerStatefulWidget {
  const ReinigungenListScreen({super.key});

  @override
  ConsumerState<ReinigungenListScreen> createState() =>
      _ReinigungenListScreenState();
}

class _ReinigungenListScreenState
    extends ConsumerState<ReinigungenListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final reinigungen = ref.watch(reinigungenProvider);
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
    for (final r in reinigungen) {
      jahreSet.add(r.datum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<ReinigungLocal>.from(reinigungen)
      ..sort((a, b) {
        final cmp = b.datum.compareTo(a.datum);
        if (cmp != 0) return cmp;
        final za = a.uhrzeitStart ?? '';
        final zb = b.uhrzeitStart ?? '';
        return zb.compareTo(za);
      });

    final filtered = sorted.where((r) {
      if (r.datum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && r.datum.month != _selectedMonth) return false;
      if (_statusFilter != 'alle' && r.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName = betriebNames[r.betriebId]?.toLowerCase() ?? '';
        final betriebOrt = betriebOrte[r.betriebId]?.toLowerCase() ?? '';
        return betriebName.contains(query) ||
            betriebOrt.contains(query) ||
            (r.notizen?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Monats- und Tagesgruppierung
    final groups = <_MonatsGruppe>[];
    for (final r in filtered) {
      final m = r.datum.month;
      final d = DateTime(r.datum.year, r.datum.month, r.datum.day);
      if (groups.isEmpty || groups.last.monat != m) {
        groups.add(_MonatsGruppe(jahr: r.datum.year, monat: m));
      }
      final g = groups.last;
      if (g.tage.isEmpty || g.tage.last.datum != d) {
        g.tage.add(_TagesGruppe(datum: d));
      }
      g.tage.last.eintraege.add(r);
    }

    final jahrSumme =
        filtered.fold(0.0, (sum, r) => sum + (r.preisBrutto ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reinigungen'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              _filterItem('alle', 'Alle'),
              _filterItem('offen', 'Offen'),
              _filterItem('abgeschlossen', 'Abgeschlossen'),
              _filterItem('abgebrochen', 'Abgebrochen'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Reinigung suchen...',
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
                      : '${filtered.length} Reinigungen',
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
                      final entry = item as ReinigungLocal;
                      return _ReinigungListItem(
                        reinigung: entry,
                        betriebName: betriebNames[entry.betriebId],
                        betriebOrt: betriebOrte[entry.betriebId],
                        onTap: () =>
                            context.push('/reinigungen/${entry.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/reinigungen/neu'),
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
            t.eintraege.fold(0.0, (s, r) => s + (r.preisBrutto ?? 0)));
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
        .fold(0.0, (sum, r) => sum + (r.preisBrutto ?? 0));
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
          Icon(Icons.cleaning_services,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Reinigungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Starte eine Reinigung über die Anlage-Detailseite',
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
  final List<ReinigungLocal> eintraege = [];
  _TagesGruppe({required this.datum});
}

class _ReinigungListItem extends StatelessWidget {
  final ReinigungLocal reinigung;
  final String? betriebName;
  final String? betriebOrt;
  final VoidCallback onTap;

  const _ReinigungListItem({
    required this.reinigung,
    this.betriebName,
    this.betriebOrt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _iconColor.withAlpha(25),
          child:
              Icon(Icons.cleaning_services, color: _iconColor, size: 20),
        ),
        title: Text(
          betriebOrt != null
              ? '$betriebOrt – ${betriebName ?? 'Unbekannt'}'
              : betriebName ?? 'Unbekannter Betrieb',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!reinigung.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            if (reinigung.status == 'abgeschlossen')
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
    parts.add(_formatDate(reinigung.datum));
    if (reinigung.uhrzeitStart != null) {
      final zeit = reinigung.uhrzeitStart!;
      parts.add(zeit.length >= 5 ? zeit.substring(0, 5) : zeit);
    }
    if (reinigung.preisBrutto != null) {
      parts.add(_chf(reinigung.preisBrutto!));
    }
    return parts.join(' · ');
  }

  int get _checkedCount {
    var count = 0;
    if (reinigung.begleitkuehlungKontrolliert) count++;
    if (reinigung.installationAllgemeinKontrolliert) count++;
    if (reinigung.aligalAnschluesseKontrolliert) count++;
    if (reinigung.durchlaufkuehlerAusgeblasen) count++;
    if (reinigung.wasserstandKontrolliert) count++;
    if (reinigung.wasserGewechselt) count++;
    if (reinigung.leitungWasserVorgespuelt) count++;
    if (reinigung.leitungsreinigungReinigungsmittel) count++;
    if (reinigung.foerderdruckKontrolliert) count++;
    if (reinigung.zapfhahnZerlegtGereinigt) count++;
    if (reinigung.zapfkopfZerlegtGereinigt) count++;
    if (reinigung.servicekarteAusgefuellt) count++;
    if (reinigung.hatDurchlaufkuehler) count++;
    if (reinigung.hatBuffetanstich) count++;
    if (reinigung.hatKuehlkeller) count++;
    if (reinigung.hatFasskuehler) count++;
    return count;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color get _iconColor {
    final art = reinigung.serviceArt;
    if (art == 'eroeffnungsservice' || art == 'endreinigung') {
      return Colors.orange;
    }
    switch (reinigung.status) {
      case 'offen':
        return AppColors.warning;
      case 'abgeschlossen':
        return AppColors.success;
      case 'abgebrochen':
        return AppColors.inaktiv;
      default:
        return AppColors.textSecondary;
    }
  }
}
