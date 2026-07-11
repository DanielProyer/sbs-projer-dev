import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anlage_pdf_util.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';

class AnlagenListScreen extends ConsumerStatefulWidget {
  const AnlagenListScreen({super.key});

  @override
  ConsumerState<AnlagenListScreen> createState() => _AnlagenListScreenState();
}

class _AnlagenListScreenState extends ConsumerState<AnlagenListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';

  @override
  Widget build(BuildContext context) {
    final anlagen = ref.watch(anlagenProvider);
    final betriebe = ref.watch(betriebeProvider);

    // Betrieb Lookup
    final betriebMap = <String, ({String name, String? ort})>{};
    for (final b in betriebe) {
      if (b.serverId != null) {
        betriebMap[b.serverId!] = (name: b.name, ort: b.ort);
      }
    }

    // Filter
    final filtered = anlagen.where((a) {
      if (_statusFilter != 'alle' && a.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName = betriebMap[a.betriebId]?.name.toLowerCase() ?? '';
        return (a.bezeichnung?.toLowerCase().contains(query) ?? false) ||
            a.typAnlage.toLowerCase().contains(query) ||
            betriebName.contains(query) ||
            (a.seriennummer?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Kennzahlen aus ALLEN Anlagen (nicht der gefilterten Liste)
    final kennzahlen = anlagenKennzahlen(anlagen, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anlagen'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _KennzahlChip('${kennzahlen.gesamt} aktiv', Icons.propane_tank_outlined),
                for (final e in kennzahlen.nachTyp.entries)
                  _KennzahlChip('${e.value}× ${e.key}', Icons.category_outlined),
                if (kennzahlen.ueberfaellig > 0)
                  _KennzahlChip('${kennzahlen.ueberfaellig} überfällig',
                      Icons.warning_amber, color: AppColors.error),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Anlage suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          AppFilterBar(
            items: [
              AppFilterDropdown<String>(
                hint: 'Alle Status',
                nullable: false,
                value: _statusFilter,
                options: const [
                  ('alle', 'Alle Status'),
                  ('aktiv', 'Aktiv'),
                  ('inaktiv', 'Inaktiv'),
                  ('stillgelegt', 'Stillgelegt'),
                  ('demontiert', 'Demontiert'),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'alle'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} Anlagen',
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
                      final anlage = filtered[index];
                      final betrieb = betriebMap[anlage.betriebId];
                      return _AnlageListItem(
                        anlage: anlage,
                        betriebName: betrieb?.name,
                        betriebOrt: betrieb?.ort,
                        onTap: () => context.push('/anlagen/${anlage.routeId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmpty() {
    // Such- oder Status-Filter aktiv? Dann kein "noch keine Anlagen".
    final gefiltert = _searchQuery.isNotEmpty || _statusFilter != 'alle';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.precision_manufacturing,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            gefiltert ? 'Keine Ergebnisse' : 'Noch keine Anlagen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            gefiltert
                ? 'Passe Suche oder Filter an'
                : 'Erstelle Anlagen über den jeweiligen Betrieb',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _AnlageListItem extends StatelessWidget {
  final AnlageLocal anlage;
  final String? betriebName;
  final String? betriebOrt;
  final VoidCallback onTap;

  const _AnlageListItem({
    required this.anlage,
    this.betriebName,
    this.betriebOrt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Titel: Betriebname, Ort
    final titleParts = <String>[];
    if (betriebName != null) titleParts.add(betriebName!);
    if (betriebOrt != null && betriebOrt!.isNotEmpty) titleParts.add(betriebOrt!);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child: anlage.status == 'demontiert'
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.precision_manufacturing,
                        color: _statusColor.withAlpha(80), size: 20),
                    Transform.rotate(
                      angle: -0.55,
                      child: Container(width: 26, height: 2.5,
                          decoration: BoxDecoration(
                            color: _statusColor,
                            borderRadius: BorderRadius.circular(2),
                          )),
                    ),
                  ],
                )
              : Icon(Icons.precision_manufacturing,
                  color: _statusColor, size: 20),
        ),
        title: Text(
          titleParts.isNotEmpty ? titleParts.join(', ') : (anlage.bezeichnung ?? anlage.typAnlage),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _buildSubtitle(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!anlage.isSynced)
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

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (anlage.bezeichnung != null) parts.add(anlage.bezeichnung!);
    parts.add(anlage.typAnlage);
    parts.add('${anlage.anzahlHaehne} Hähne');
    return Text(parts.join(' · '));
  }

  Color get _statusColor {
    switch (anlage.status) {
      case 'aktiv':
        return AppColors.aktiv;
      case 'inaktiv':
        return AppColors.warning;
      case 'stillgelegt':
        return AppColors.error;
      case 'demontiert':
        return AppColors.demontiert;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _KennzahlChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _KennzahlChip(this.label, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
