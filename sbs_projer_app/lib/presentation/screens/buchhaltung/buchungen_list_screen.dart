import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';

class BuchungenListScreen extends ConsumerStatefulWidget {
  final int? filterKontonummer;

  const BuchungenListScreen({super.key, this.filterKontonummer});

  @override
  ConsumerState<BuchungenListScreen> createState() =>
      _BuchungenListScreenState();
}

class _BuchungenListScreenState extends ConsumerState<BuchungenListScreen> {
  String _searchQuery = '';
  int? _filterKonto;
  int _filterJahr = DateTime.now().year;
  int? _filterMonat;

  @override
  void initState() {
    super.initState();
    _filterKonto = widget.filterKontonummer;
  }

  @override
  Widget build(BuildContext context) {
    final buchungen = ref.watch(buchungenProvider);

    // Filter anwenden
    final filtered = buchungen.where((b) {
      // Konto-Filter
      if (_filterKonto != null) {
        if (b.sollKonto != _filterKonto && b.habenKonto != _filterKonto) {
          return false;
        }
      }
      // Jahr-Filter
      if (b.geschaeftsjahr != _filterJahr) return false;
      // Monat-Filter
      if (_filterMonat != null && b.monat != _filterMonat) return false;
      // Suche
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return b.beschreibung.toLowerCase().contains(q) ||
            (b.belegnummer?.toLowerCase().contains(q) ?? false) ||
            b.sollKonto.toString().contains(q) ||
            b.habenKonto.toString().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_filterKonto != null
            ? 'Konto $_filterKonto'
            : 'Journal'),
        actions: [
          if (_filterKonto != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Konto-Filter entfernen',
              onPressed: () => setState(() => _filterKonto = null),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Buchung suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Filter-Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Jahr
                  _FilterChip(
                    label: '$_filterJahr',
                    onTap: () => _showJahrPicker(),
                  ),
                  const SizedBox(width: 8),
                  // Monat
                  _FilterChip(
                    label: _filterMonat != null
                        ? _monatName(_filterMonat!)
                        : 'Alle Monate',
                    onTap: () => _showMonatPicker(),
                    onDelete: _filterMonat != null
                        ? () => setState(() => _filterMonat = null)
                        : null,
                  ),
                  if (_filterKonto != null) ...[
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Konto $_filterKonto',
                      onTap: () {},
                      onDelete: () => setState(() => _filterKonto = null),
                    ),
                  ],
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Buchungen',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final b = filtered[index];
                      return _BuchungListItem(
                        buchung: b,
                        onTap: () =>
                            context.push('/buchhaltung/buchungen/${b.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/buchhaltung/buchungen/neu'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Keine Ergebnisse' : 'Keine Buchungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  void _showJahrPicker() {
    final currentYear = DateTime.now().year;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Jahr wählen'),
        children: [
          for (int y = currentYear; y >= currentYear - 3; y--)
            SimpleDialogOption(
              onPressed: () {
                setState(() => _filterJahr = y);
                Navigator.pop(ctx);
              },
              child: Text(
                '$y',
                style: TextStyle(
                  fontWeight: y == _filterJahr ? FontWeight.w700 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMonatPicker() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Monat wählen'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _filterMonat = null);
              Navigator.pop(ctx);
            },
            child: Text(
              'Alle Monate',
              style: TextStyle(
                fontWeight: _filterMonat == null ? FontWeight.w700 : null,
              ),
            ),
          ),
          for (int m = 1; m <= 12; m++)
            SimpleDialogOption(
              onPressed: () {
                setState(() => _filterMonat = m);
                Navigator.pop(ctx);
              },
              child: Text(
                _monatName(m),
                style: TextStyle(
                  fontWeight: m == _filterMonat ? FontWeight.w700 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _monatName(int m) {
    const namen = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return namen[m];
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FilterChip({
    required this.label,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (onDelete != null) {
      return InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
        onDeleted: onDelete,
        deleteIcon: const Icon(Icons.close, size: 14),
      );
    }
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}

class _BuchungListItem extends StatelessWidget {
  final Buchung buchung;
  final VoidCallback onTap;

  const _BuchungListItem({
    required this.buchung,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: buchung.istStorniert
              ? AppColors.error.withAlpha(25)
              : AppColors.primary.withAlpha(25),
          radius: 20,
          child: Icon(
            buchung.istStorniert ? Icons.cancel : Icons.swap_horiz,
            size: 18,
            color: buchung.istStorniert ? AppColors.error : AppColors.primary,
          ),
        ),
        title: Text(
          buchung.beschreibung,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            decoration:
                buchung.istStorniert ? TextDecoration.lineThrough : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatDate(buchung.datum)} · ${buchung.sollKonto} → ${buchung.habenKonto}'
          '${buchung.belegnummer != null ? ' · ${buchung.belegnummer}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${buchung.betragBrutto.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: buchung.istStorniert ? AppColors.error : null,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
