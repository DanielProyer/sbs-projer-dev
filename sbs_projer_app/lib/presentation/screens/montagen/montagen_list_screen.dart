import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/montage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final _nf = NumberFormat('#,##0', 'de_CH');
String _chf(double v) => '${_nf.format(v.round())} CHF';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

class MontagenListScreen extends ConsumerStatefulWidget {
  const MontagenListScreen({super.key});

  @override
  ConsumerState<MontagenListScreen> createState() =>
      _MontagenListScreenState();
}

class _MontagenListScreenState extends ConsumerState<MontagenListScreen> {
  String _searchQuery = '';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final montagen = ref.watch(montagenProvider);
    final betriebNames = ref.watch(betriebNameMapProvider);
    final betriebOrte = ref.watch(betriebOrtMapProvider);

    // Verfügbare Jahre
    final jahreSet = <int>{};
    for (final m in montagen) {
      jahreSet.add(m.datum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<MontageLocal>.from(montagen)
      ..sort((a, b) => b.datum.compareTo(a.datum));

    final filtered = sorted.where((m) {
      if (m.datum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && m.datum.month != _selectedMonth) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName = betriebNames[m.betriebId]?.toLowerCase() ?? '';
        final betriebOrt = betriebOrte[m.betriebId]?.toLowerCase() ?? '';
        return betriebName.contains(query) ||
            betriebOrt.contains(query) ||
            _montageTypLabel(m.montageTyp).toLowerCase().contains(query) ||
            m.beschreibung.toLowerCase().contains(query) ||
            (m.notizen?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Monats- und Tagesgruppierung
    final groups = <_MonatsGruppe>[];
    for (final m in filtered) {
      final mo = m.datum.month;
      final d = DateTime(m.datum.year, m.datum.month, m.datum.day);
      if (groups.isEmpty || groups.last.monat != mo) {
        groups.add(_MonatsGruppe(jahr: m.datum.year, monat: mo));
      }
      final g = groups.last;
      if (g.tage.isEmpty || g.tage.last.datum != d) {
        g.tage.add(_TagesGruppe(datum: d));
      }
      g.tage.last.eintraege.add(m);
    }

    final jahrSumme =
        filtered.fold(0.0, (sum, m) => sum + (m.kostenArbeit ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Montagen'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Montage suchen...',
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
                      : '${filtered.length} Montagen',
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
                      final entry = item as MontageLocal;
                      return _MontageListItem(
                        montage: entry,
                        betriebName: betriebNames[entry.betriebId],
                        betriebOrt: betriebOrte[entry.betriebId],
                        onTap: () =>
                            context.push('/montagen/${entry.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: SupabaseService.isGuest
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/montagen/neu'),
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
            t.eintraege.fold(0.0, (s, m) => s + (m.kostenArbeit ?? 0)));
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
        .fold(0.0, (sum, m) => sum + (m.kostenArbeit ?? 0));
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
          Icon(Icons.build,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Keine Ergebnisse'
                : 'Noch keine Montagen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedMonth != 0
                ? 'Versuche einen anderen Suchbegriff oder Filter'
                : 'Tippe auf + um eine Montage zu erfassen',
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
  final List<MontageLocal> eintraege = [];
  _TagesGruppe({required this.datum});
}

String _montageTypLabel(String typ) {
  switch (typ) {
    case 'neumontage':
      return 'Neumontage';
    case 'demontage':
      return 'Demontage';
    case 'abaenderung':
      return 'Abänderung';
    case 'heigenie_service':
      return 'HeiGenie Service';
    case 'anlass':
      return 'Anlass';
    case 'spesen':
      return 'Spesen';
    case 'aufwandsentschaedigung':
      return 'Aufwandsentsch.';
    // Legacy
    case 'neu_installation': case 'montage': return 'Neumontage';
    case 'umbau': case 'erweiterung': return 'Abänderung';
    case 'abbau': return 'Demontage';
    case 'anlass_mitarbeit': return 'Anlass';
    default:
      return typ;
  }
}

IconData _montageTypIcon(String typ) {
  switch (typ) {
    case 'neumontage': case 'neu_installation': case 'montage':
      return Icons.add_circle_outline;
    case 'demontage': case 'abbau':
      return Icons.remove_circle_outline;
    case 'abaenderung': case 'umbau': case 'erweiterung':
      return Icons.tune;
    case 'heigenie_service':
      return Icons.cleaning_services;
    case 'anlass': case 'anlass_mitarbeit':
      return Icons.celebration;
    case 'spesen':
      return Icons.receipt_long;
    case 'aufwandsentschaedigung':
      return Icons.account_balance_wallet;
    default:
      return Icons.build;
  }
}

Color _montageTypColor(String typ) {
  switch (typ) {
    case 'neumontage': case 'neu_installation': case 'montage':
      return const Color(0xFF16A34A); // Grün
    case 'demontage': case 'abbau':
      return const Color(0xFFDC2626); // Rot
    case 'abaenderung': case 'umbau': case 'erweiterung':
      return const Color(0xFF2563EB); // Blau
    case 'heigenie_service':
      return const Color(0xFF0D9488); // Teal
    case 'anlass': case 'anlass_mitarbeit':
      return const Color(0xFF7C3AED); // Violett
    case 'spesen':
      return const Color(0xFFD97706); // Amber
    case 'aufwandsentschaedigung':
      return const Color(0xFF64748B); // Grau
    default:
      return const Color(0xFF6B7280);
  }
}

class _MontageListItem extends StatelessWidget {
  final MontageLocal montage;
  final String? betriebName;
  final String? betriebOrt;
  final VoidCallback onTap;

  const _MontageListItem({
    required this.montage,
    this.betriebName,
    this.betriebOrt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _montageTypColor(montage.montageTyp).withAlpha(25),
          child: Icon(_montageTypIcon(montage.montageTyp),
              color: _montageTypColor(montage.montageTyp), size: 20),
        ),
        title: Text(
          betriebOrt != null
              ? '$betriebOrt – ${betriebName ?? 'Unbekannt'}'
              : betriebName ?? _montageTypLabel(montage.montageTyp),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!montage.isSynced)
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
    parts.add(_montageTypLabel(montage.montageTyp));
    if (montage.dauerStunden != null) {
      parts.add('${montage.dauerStunden!.toStringAsFixed(1)} h');
    }
    if (montage.kostenArbeit != null) {
      parts.add(_chf(montage.kostenArbeit!));
    }
    return parts.join(' · ');
  }
}
