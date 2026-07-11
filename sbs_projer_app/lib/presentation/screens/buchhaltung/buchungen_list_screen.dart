import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/filter_chrome.dart';

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
  int? _filterJahr; // null = alle Jahre
  int? _filterMonat; // null = ganzes Jahr
  String _seite = 'alle'; // alle | soll | haben (nur bei Konto-Ansicht)
  double? _betragVon; // exakter Betrag (wenn _betragBis leer) oder Bereichs-Untergrenze
  double? _betragBis; // Bereichs-Obergrenze (optional)

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
      // Konto-Filter (inkl. Soll/Haben-Seite)
      if (_filterKonto != null) {
        final istSoll = b.sollKonto == _filterKonto;
        final istHaben = b.habenKonto == _filterKonto;
        if (_seite == 'soll') {
          if (!istSoll) return false;
        } else if (_seite == 'haben') {
          if (!istHaben) return false;
        } else if (!istSoll && !istHaben) {
          return false;
        }
      }
      // Jahr-Filter (null = alle Jahre)
      if (_filterJahr != null && b.geschaeftsjahr != _filterJahr) return false;
      // Monat-Filter (null = ganzes Jahr)
      if (_filterMonat != null && b.monat != _filterMonat) return false;
      // Betrag-Filter: fixer Betrag (nur "von") oder Bereich ("von"–"bis")
      final betrag = b.betragBrutto;
      if (_betragVon != null && _betragBis == null) {
        if ((betrag - _betragVon!).abs() >= 0.005) return false;
      } else {
        if (_betragVon != null && betrag < _betragVon! - 0.005) return false;
        if (_betragBis != null && betrag > _betragBis! + 0.005) return false;
      }
      // Suche
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return b.beschreibung.toLowerCase().contains(q) ||
            (b.belegnummer?.toLowerCase().contains(q) ?? false) ||
            b.sollKonto.toString().contains(q) ||
            b.habenKonto.toString().contains(q);
      }
      return true;
    }).toList()
      // Sortieren nach Datum + Uhrzeit (neueste zuerst)
      ..sort((a, b) {
        final cmp = b.datum.compareTo(a.datum);
        if (cmp != 0) return cmp;
        // Bei gleichem Datum: createdAt als Uhrzeit-Proxy
        final catA = a.createdAt ?? a.datum;
        final catB = b.createdAt ?? b.datum;
        return catB.compareTo(catA);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(_filterKonto != null
            ? 'Konto $_filterKonto'
            : 'Journal'),
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

          // Filter (einheitlicher App-Stil): Dropdowns oben, Betrag in neuer Zeile
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zeile 1: Jahr / Monat / Soll-Haben
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChrome(
                      child: DropdownButton<int?>(
                        value: _filterJahr,
                        hint: const Text('Alle Jahre'),
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Alle Jahre')),
                          for (int y = DateTime.now().year; y >= 2019; y--)
                            DropdownMenuItem<int?>(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) => setState(() => _filterJahr = v),
                      ),
                    ),
                    FilterChrome(
                      child: DropdownButton<int?>(
                        value: _filterMonat,
                        hint: const Text('Ganzes Jahr'),
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('Ganzes Jahr')),
                          for (int m = 1; m <= 12; m++)
                            DropdownMenuItem<int?>(
                                value: m, child: Text(_monatName(m))),
                        ],
                        onChanged: (v) => setState(() => _filterMonat = v),
                      ),
                    ),
                    if (_filterKonto != null)
                      FilterChrome(
                        child: DropdownButton<String>(
                          value: _seite,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                                value: 'alle', child: Text('Alle Buchungen')),
                            DropdownMenuItem(value: 'soll', child: Text('Soll')),
                            DropdownMenuItem(
                                value: 'haben', child: Text('Haben')),
                          ],
                          onChanged: (v) => setState(() => _seite = v ?? 'alle'),
                        ),
                      ),
                  ],
                ),
                // Zeile 2: Betrag fix (nur "Betrag") oder Bereich ("Betrag"–"bis")
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Betrag', isDense: true),
                        onChanged: (v) => setState(() => _betragVon =
                            double.tryParse(v.replaceAll(',', '.'))),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'bis', isDense: true),
                        onChanged: (v) => setState(() => _betragBis =
                            double.tryParse(v.replaceAll(',', '.'))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

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

  static String _monatName(int m) {
    const namen = [
      '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
    ];
    return namen[m];
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
          '${_formatDateTime(buchung)} · ${buchung.sollKonto} → ${buchung.habenKonto}'
          '${buchung.belegnummer != null ? ' · ${buchung.belegnummer}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          buchung.betragBrutto.toStringAsFixed(2),
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

  static String _formatDateTime(Buchung b) {
    final d = b.datum;
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final c = b.createdAt;
    if (c != null) {
      final time = '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}';
      return '$date $time';
    }
    return date;
  }
}
