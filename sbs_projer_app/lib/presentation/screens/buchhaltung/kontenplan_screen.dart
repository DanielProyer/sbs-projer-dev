import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/konto.dart';
import 'package:sbs_projer_app/presentation/providers/konto_providers.dart';
import 'package:sbs_projer_app/services/rechnung/buchung_service.dart';

class KontenplanScreen extends ConsumerStatefulWidget {
  const KontenplanScreen({super.key});

  @override
  ConsumerState<KontenplanScreen> createState() => _KontenplanScreenState();
}

class _KontenplanScreenState extends ConsumerState<KontenplanScreen> {
  String _searchQuery = '';
  Map<int, double>? _saldi;
  bool _loadingSaldi = true;

  @override
  void initState() {
    super.initState();
    _loadSaldi();
  }

  Future<void> _loadSaldi() async {
    try {
      final saldi = await BuchungService.getAllSaldi();
      if (mounted) setState(() { _saldi = saldi; _loadingSaldi = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSaldi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final konten = ref.watch(kontenProvider);

    final filtered = konten.where((k) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return k.bezeichnung.toLowerCase().contains(q) ||
          k.kontonummer.toString().contains(q) ||
          (k.kategorie?.toLowerCase().contains(q) ?? false);
    }).toList();

    // Gruppieren nach Kategorie
    final grouped = <String, List<Konto>>{};
    for (final k in filtered) {
      final kat = k.kategorie ?? 'Sonstige';
      grouped.putIfAbsent(kat, () => []).add(k);
    }

    // Kategorien sortieren nach erster Kontonummer
    final sortedKategorien = grouped.keys.toList()
      ..sort((a, b) {
        final aMin = grouped[a]!.first.kontonummer;
        final bMin = grouped[b]!.first.kontonummer;
        return aMin.compareTo(bMin);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Kontenplan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Konto suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Konten',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Keine Konten gefunden',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: sortedKategorien.length,
                    itemBuilder: (context, index) {
                      final kat = sortedKategorien[index];
                      final kontenInKat = grouped[kat]!;
                      return _KategorieSection(
                        kategorie: kat,
                        konten: kontenInKat,
                        saldi: _saldi,
                        loadingSaldi: _loadingSaldi,
                        onKontoTap: (k) => context.push(
                          '/buchhaltung/buchungen',
                          extra: k.kontonummer,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KategorieSection extends StatelessWidget {
  final String kategorie;
  final List<Konto> konten;
  final Map<int, double>? saldi;
  final bool loadingSaldi;
  final void Function(Konto) onKontoTap;

  const _KategorieSection({
    required this.kategorie,
    required this.konten,
    this.saldi,
    this.loadingSaldi = true,
    required this.onKontoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            kategorie,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
          ),
        ),
        ...konten.map((k) {
          final saldo = saldi?[k.kontonummer] ?? 0;
          return Card(
            child: ListTile(
              leading: SizedBox(
                width: 48,
                child: Text(
                  k.kontonummer.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              title: Text(
                k.bezeichnung,
                style: const TextStyle(fontSize: 14),
              ),
              trailing: loadingSaldi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${saldo.toStringAsFixed(2)} CHF',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: saldo < 0 ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
              onTap: () => onKontoTap(k),
            ),
          );
        }),
      ],
    );
  }
}
