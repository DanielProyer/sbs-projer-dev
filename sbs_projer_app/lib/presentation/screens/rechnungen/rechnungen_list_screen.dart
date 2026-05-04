import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class RechnungenListScreen extends ConsumerStatefulWidget {
  const RechnungenListScreen({super.key});

  @override
  ConsumerState<RechnungenListScreen> createState() =>
      _RechnungenListScreenState();
}

class _RechnungenListScreenState extends ConsumerState<RechnungenListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final rechnungen = ref.watch(rechnungenProvider);
    final betriebe = ref.watch(betriebeProvider);

    final betriebNames = <String, String>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebNames[b.serverId!] = b.name;
      }
    }

    // Verfügbare Jahre
    final jahreSet = <int>{};
    for (final r in rechnungen) {
      jahreSet.add(r.rechnungsdatum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<Rechnung>.from(rechnungen)
      ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));

    final filtered = sorted.where((r) {
      if (r.rechnungsdatum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && r.rechnungsdatum.month != _selectedMonth) {
        return false;
      }
      if (_statusFilter != 'alle' && r.zahlungsstatus != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName =
            (r.betriebId != null ? betriebNames[r.betriebId] : null)
                    ?.toLowerCase() ??
                '';
        return betriebName.contains(query) ||
            (r.rechnungsnummer?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Monats- und Tagesgruppierung
    final groups = <_MonatsGruppe>[];
    for (final r in filtered) {
      final m = r.rechnungsdatum.month;
      final d = DateTime(
          r.rechnungsdatum.year, r.rechnungsdatum.month, r.rechnungsdatum.day);
      if (groups.isEmpty || groups.last.monat != m) {
        groups.add(_MonatsGruppe(jahr: r.rechnungsdatum.year, monat: m));
      }
      final g = groups.last;
      if (g.tage.isEmpty || g.tage.last.datum != d) {
        g.tage.add(_TagesGruppe(datum: d));
      }
      g.tage.last.eintraege.add(r);
    }

    final jahrSumme =
        filtered.fold(0.0, (sum, r) => sum + r.betragBrutto);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechnungen'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              _filterItem('alle', 'Alle'),
              _filterItem('offen', 'Offen'),
              _filterItem('bezahlt', 'Bezahlt'),
              _filterItem('ueberfaellig', 'Überfällig'),
              _filterItem('storniert', 'Storniert'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Rechnung suchen...',
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
                      : '${filtered.length} Rechnungen',
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
                    label: Text(_statusFilter == 'ueberfaellig'
                        ? 'Überfällig'
                        : _statusFilter),
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
                      final entry = item as Rechnung;
                      return _RechnungListItem(
                        rechnung: entry,
                        betriebName: entry.betriebId != null
                            ? betriebNames[entry.betriebId]
                            : null,
                        onTap: () =>
                            context.push('/rechnungen/${entry.id}'),
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
            sum + t.eintraege.fold(0.0, (s, r) => s + r.betragBrutto));
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

  Widget _buildTagesHeader(BuildContext context, _TagesGruppe gruppe) {
    final count = gruppe.eintraege.length;
    final summe =
        gruppe.eintraege.fold(0.0, (sum, r) => sum + r.betragBrutto);
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
            Text('${summe.toStringAsFixed(2)} CHF',
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
          Icon(Icons.receipt_long,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Rechnungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Rechnungen werden automatisch bei Reinigungsabschluss erstellt',
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
  final List<Rechnung> eintraege = [];
  _TagesGruppe({required this.datum});
}

class _RechnungListItem extends StatelessWidget {
  final Rechnung rechnung;
  final String? betriebName;
  final VoidCallback onTap;

  const _RechnungListItem({
    required this.rechnung,
    this.betriebName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child: Icon(Icons.receipt_long, color: _statusColor, size: 20),
        ),
        title: Text(
          rechnung.rechnungsnummer ?? 'Entwurf',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(status: rechnung.zahlungsstatus),
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
    if (betriebName != null) parts.add(betriebName!);
    parts.add(_formatDate(rechnung.rechnungsdatum));
    final brutto = (rechnung.betragBrutto * 20).roundToDouble() / 20;
    parts.add('CHF ${brutto.toStringAsFixed(2)}');
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color get _statusColor {
    switch (rechnung.zahlungsstatus) {
      case 'offen':
        return AppColors.warning;
      case 'bezahlt':
        return AppColors.success;
      case 'ueberfaellig':
        return AppColors.error;
      case 'storniert':
        return AppColors.inaktiv;
      case 'teilbezahlt':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case 'offen':
        return 'Offen';
      case 'bezahlt':
        return 'Bezahlt';
      case 'ueberfaellig':
        return 'Überfällig';
      case 'storniert':
        return 'Storniert';
      case 'teilbezahlt':
        return 'Teilbezahlt';
      case 'entwurf':
        return 'Entwurf';
      default:
        return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'offen':
        return AppColors.warning;
      case 'bezahlt':
        return AppColors.success;
      case 'ueberfaellig':
        return AppColors.error;
      case 'storniert':
        return AppColors.inaktiv;
      case 'teilbezahlt':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}
