import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/kontakt.dart';
import 'package:sbs_projer_app/data/repositories/kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/anruf_log_repository.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';

class KontakteListScreen extends ConsumerStatefulWidget {
  final String? kategorie;
  final String? betriebId;

  const KontakteListScreen({super.key, this.kategorie, this.betriebId});

  @override
  ConsumerState<KontakteListScreen> createState() => _KontakteListScreenState();
}

class _KontakteListScreenState extends ConsumerState<KontakteListScreen> {
  String _suchText = '';
  String _filterKategorie = 'alle';

  @override
  void initState() {
    super.initState();
    if (widget.kategorie != null) {
      _filterKategorie = widget.kategorie!;
    }
  }

  String _appBarTitle() {
    if (widget.betriebId != null) return 'Betrieb-Kontakte';
    return switch (_filterKategorie) {
      'heineken' => 'Heineken Kontakte',
      'event' => 'Event-Kontakte',
      'betrieb' => 'Betrieb-Kontakte',
      _ => 'Kontakte',
    };
  }

  Future<void> _anrufen(KontaktLocal kontakt) async {
    final telefon = kontakt.telefon;
    if (telefon == null || telefon.isEmpty) return;

    try {
      final serverId = kontakt.serverId;
      if (serverId != null) {
        await AnrufLogRepository.log(serverId);
      }
    } catch (_) {}

    final uri = Uri.parse('tel:${telefon.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _loeschen(KontaktLocal kontakt) async {
    final name = [kontakt.vorname, kontakt.nachname]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kontakt löschen'),
        content: Text('«$name» wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final id = kontakt.serverId ?? kontakt.id.toString();
      await KontaktRepository.delete(id);
      ref.invalidate(kontakteProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name gelöscht')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  List<KontaktLocal> _filterAndSearch(
      List<KontaktLocal> alle, Map<String, String> betriebNamen) {
    var result = alle;

    // Kategorie-Filter
    if (_filterKategorie != 'alle') {
      result = result.where((k) => k.kategorie == _filterKategorie).toList();
    }

    // Betrieb-Filter
    if (widget.betriebId != null) {
      result = result.where((k) => k.betriebId == widget.betriebId).toList();
    }

    // Suche
    if (_suchText.isNotEmpty) {
      final q = _suchText.toLowerCase();
      result = result.where((k) {
        final name = '${k.vorname} ${k.nachname ?? ''}'.toLowerCase();
        final tel = (k.telefon ?? '').toLowerCase();
        final mail = (k.email ?? '').toLowerCase();
        final betrieb =
            (betriebNamen[k.betriebId] ?? '').toLowerCase();
        return name.contains(q) ||
            tel.contains(q) ||
            mail.contains(q) ||
            betrieb.contains(q);
      }).toList();
    }

    // Sortierung: Kategorie → Betrieb → Rolle → Name
    result.sort((a, b) {
      final katCmp = a.kategorie.compareTo(b.kategorie);
      if (katCmp != 0) return katCmp;
      final betriebA = betriebNamen[a.betriebId] ?? '';
      final betriebB = betriebNamen[b.betriebId] ?? '';
      final betriebCmp = betriebA.compareTo(betriebB);
      if (betriebCmp != 0) return betriebCmp;
      final rolleA = a.rolle ?? 'zzz';
      final rolleB = b.rolle ?? 'zzz';
      final rolleCmp = rolleA.compareTo(rolleB);
      if (rolleCmp != 0) return rolleCmp;
      return a.vorname.compareTo(b.vorname);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final kontakteAsync = ref.watch(kontakteProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle())),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final params = <String, String>{};
          if (_filterKategorie != 'alle') params['kategorie'] = _filterKategorie;
          if (widget.betriebId != null) params['betriebId'] = widget.betriebId!;
          final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
          context.push('/kontakte/neu${query.isNotEmpty ? '?$query' : ''}');
        },
        child: const Icon(Icons.add),
      ),
      body: kontakteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (alleKontakte) {
          final betriebNamen = ref.watch(betriebNameMapProvider);

          final kontakte = _filterAndSearch(alleKontakte, betriebNamen);

          return Column(
            children: [
              // Suchfeld
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Suche nach Betrieb, Name, Telefon, E-Mail...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _suchText = v),
                ),
              ),

              // Filter-Chips (nur wenn kein betriebId-Filter)
              if (widget.betriebId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Alle',
                        selected: _filterKategorie == 'alle',
                        onTap: () => setState(() => _filterKategorie = 'alle'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Betrieb',
                        selected: _filterKategorie == 'betrieb',
                        onTap: () => setState(() => _filterKategorie = 'betrieb'),
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Heineken',
                        selected: _filterKategorie == 'heineken',
                        onTap: () => setState(() => _filterKategorie = 'heineken'),
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Event',
                        selected: _filterKategorie == 'event',
                        onTap: () => setState(() => _filterKategorie = 'event'),
                        color: Colors.orange.shade700,
                      ),
                    ],
                  ),
                ),

              // Liste
              Expanded(
                child: kontakte.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.contacts,
                                size: 64,
                                color: AppColors.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            const Text('Keine Kontakte gefunden.',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: kontakte.length,
                        itemBuilder: (ctx, i) {
                          final k = kontakte[i];
                          // Kategorie-Header einfügen
                          final showHeader = i == 0 ||
                              kontakte[i - 1].kategorie != k.kategorie;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeader && _filterKategorie == 'alle')
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: i == 0 ? 4 : 16,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    _kategorieHeader(k.kategorie),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              _KontaktCard(
                                kontakt: k,
                                betriebName: betriebNamen[k.betriebId],
                                onTap: () {
                                  final id = k.serverId ?? k.id.toString();
                                  context.push('/kontakte/$id/bearbeiten');
                                },
                                onCall: k.telefon != null && k.telefon!.isNotEmpty
                                    ? () => _anrufen(k)
                                    : null,
                                onDelete: () => _loeschen(k),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _kategorieHeader(String kategorie) => switch (kategorie) {
    'betrieb' => 'BETRIEB-KONTAKTE',
    'heineken' => 'HEINEKEN-KONTAKTE',
    'event' => 'EVENT-KONTAKTE',
    _ => kategorie.toUpperCase(),
  };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _KontaktCard extends StatelessWidget {
  final KontaktLocal kontakt;
  final String? betriebName;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback onDelete;

  const _KontaktCard({
    required this.kontakt,
    this.betriebName,
    required this.onTap,
    this.onCall,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = [kontakt.vorname, kontakt.nachname]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final hasBetrieb = betriebName != null && betriebName!.isNotEmpty;

    return Dismissible(
      key: ValueKey(kontakt.serverId ?? kontakt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.error,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          title: Row(
            children: [
              Flexible(
                child: Text(hasBetrieb ? betriebName! : name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              if (kontakt.rolle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _kategorieColor(kontakt.kategorie).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    Kontakt.rolleLabelStatic(kontakt.rolle!),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _kategorieColor(kontakt.kategorie),
                    ),
                  ),
                ),
              if (kontakt.istHauptkontakt) ...[
                const SizedBox(width: 4),
                Icon(Icons.star, size: 14, color: Colors.amber.shade700),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Du/Sie Badge
              Row(
                children: [
                  if (hasBetrieb)
                    Flexible(
                      child: Text(name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  if (kontakt.istDuAnrede) ...[
                    if (hasBetrieb) const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('Du',
                          style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                    ),
                  ],
                ],
              ),
              if (kontakt.telefon != null && kontakt.telefon!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(kontakt.telefon!,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              if (kontakt.email != null && kontakt.email!.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.email, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(kontakt.email!,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
            ],
          ),
          trailing: onCall != null
              ? IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.success),
                  tooltip: 'Anrufen',
                  onPressed: onCall,
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }

  Color _kategorieColor(String kategorie) => switch (kategorie) {
    'betrieb' => AppColors.primary,
    'heineken' => Colors.blue.shade700,
    'event' => Colors.orange.shade700,
    _ => AppColors.textSecondary,
  };
}
