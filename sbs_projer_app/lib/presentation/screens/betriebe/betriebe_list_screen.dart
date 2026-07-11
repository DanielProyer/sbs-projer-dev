import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/betrieb_faelligkeit.dart';
import 'package:sbs_projer_app/core/util/google_maps_route.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/presentation/providers/anlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betriebe_map.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ein Betrieb ist "operativ", wenn er betreut wird: aktiv oder in Saisonpause
/// (aktiv, aber Pause). Inaktiv/geschlossen erscheinen nur bei explizitem Filter.
bool istBetriebOperativ(String status) =>
    status == 'aktiv' || status == 'saisonpause';

class BetriebeListScreen extends ConsumerStatefulWidget {
  const BetriebeListScreen({super.key});

  @override
  ConsumerState<BetriebeListScreen> createState() => _BetriebeListScreenState();
}

class _BetriebeListScreenState extends ConsumerState<BetriebeListScreen> {
  String _searchQuery = '';
  // 'operativ' (aktiv+saisonpause, Default) | aktiv | saisonpause | inaktiv |
  // geschlossen | alle — nur Liste
  String _statusFilter = 'operativ';
  String _kundenFilter = 'alle'; // 'alle', 'meine', 'fremde' — beide Ansichten
  Set<String> _selectedZapfsysteme = {}; // nur Liste
  // Region gilt für Liste UND Karte (gemeinsamer State).
  Set<String> _selectedRegionIds = {};

  // Karten-Ansicht
  bool _karteAktiv = false;
  bool _karteNurFaellig = false; // nur Karte

  @override
  Widget build(BuildContext context) {
    final betriebe = ref.watch(betriebeProvider);
    final regionen = ref.watch(regionenProvider);

    // Zombie-Schutz: nur nach Regionen filtern, die aktuell als Option
    // existieren. Fällt eine gewählte Region weg (gelöscht/kurz nicht geladen),
    // greift sie nicht mehr stumm und blendet nicht alles aus.
    final regionOptionIds = {
      for (final r in regionen)
        if (r.serverId != null) r.serverId!,
    };
    final aktiveRegionIds = _selectedRegionIds.intersection(regionOptionIds);

    // Fälligkeit je Betrieb aus allen Anlagen aggregieren
    final anlagen = ref.watch(anlagenProvider);
    final anlagenNachBetrieb = <String, List<AnlageLocal>>{};
    for (final a in anlagen) {
      (anlagenNachBetrieb[a.betriebId] ??= []).add(a);
    }
    final jetzt = DateTime.now();
    FaelligkeitsStatus statusFuer(BetriebLocal b) {
      // Inaktive/geschlossene Betriebe werden nicht mehr serviciert -> nie fällig.
      if (b.status != 'aktiv') return FaelligkeitsStatus.nichtFaellig;
      final sid = b.serverId;
      final list = sid == null
          ? const <AnlageLocal>[]
          : (anlagenNachBetrieb[sid] ?? const []);
      return betriebFaelligkeit(
        // Nur aktive Anlagen zählen (analog Touren-Logik).
        list
            .where((a) => a.status == 'aktiv')
            .map((a) => getFaelligkeit(a, jetzt, betrieb: b))
            .toList(),
      );
    }

    // Filter anwenden
    final filtered = betriebe.where((b) {
      if (_kundenFilter == 'meine' && !b.istMeinKunde) return false;
      if (_kundenFilter == 'fremde' && b.istMeinKunde) return false;
      if (!_statusPasst(b.status)) return false;
      if (_selectedZapfsysteme.isNotEmpty &&
          !_selectedZapfsysteme.any((z) => b.zapfsysteme.contains(z))) {
        return false;
      }
      if (aktiveRegionIds.isNotEmpty &&
          (b.regionId == null || !aktiveRegionIds.contains(b.regionId))) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return b.name.toLowerCase().contains(query) ||
            (b.ort?.toLowerCase().contains(query) ?? false) ||
            (b.betriebNr?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Betriebe'),
      ),
      body: Column(
        children: [
          // Umschalter Liste ↔ Karte
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.list),
                    label: Text('Liste')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.map),
                    label: Text('Karte')),
              ],
              selected: {_karteAktiv},
              onSelectionChanged: (s) =>
                  setState(() => _karteAktiv = s.first),
            ),
          ),

          // Suchleiste
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Betrieb suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Einheitliche Filter-Leiste (kontextabhängig: Liste vs. Karte)
          AppFilterBar(
            items: [
              // Kunden — beide Ansichten
              AppFilterDropdown<String>(
                hint: 'Alle Kunden',
                value: _kundenFilter == 'alle' ? null : _kundenFilter,
                options: const [
                  ('meine', 'Meine Kunden'),
                  ('fremde', 'Fremde Kunden'),
                ],
                onChanged: (v) => setState(() => _kundenFilter = v ?? 'alle'),
              ),
              // Status — nur Liste
              if (!_karteAktiv)
                AppFilterDropdown<String>(
                  hint: 'Status',
                  nullable: false,
                  value: _statusFilter,
                  options: const [
                    ('operativ', 'Aktiv + Pause'),
                    ('aktiv', 'Nur aktiv'),
                    ('saisonpause', 'Saisonpause'),
                    ('inaktiv', 'Inaktiv'),
                    ('geschlossen', 'Geschlossen'),
                    ('alle', 'Alle'),
                  ],
                  onChanged: (v) =>
                      setState(() => _statusFilter = v ?? 'operativ'),
                ),
              // Zapfsysteme — nur Liste
              if (!_karteAktiv)
                AppFilterMultiDropdown<String>(
                  label: 'Zapfsysteme',
                  options: const [
                    ('David', 'David'),
                    ('Konventionell', 'Konventionell'),
                    ('Higenie', 'Higenie'),
                    ('Orion', 'Orion'),
                    ('Veranstaltungen', 'Veranstaltungen'),
                  ],
                  selected: _selectedZapfsysteme,
                  onChanged: (s) => setState(() => _selectedZapfsysteme = s),
                ),
              // Region — beide Ansichten (gemeinsamer State)
              if (regionen.isNotEmpty)
                AppFilterMultiDropdown<String>(
                  label: 'Regionen',
                  options: [
                    for (final r in regionen)
                      if (r.serverId != null) (r.serverId!, r.name),
                  ],
                  selected: aktiveRegionIds,
                  onChanged: (s) => setState(() => _selectedRegionIds = s),
                ),
              // Nur fällige — nur Karte
              if (_karteAktiv)
                AppFilterToggle(
                  label: 'Nur fällige',
                  value: _karteNurFaellig,
                  onChanged: (v) => setState(() => _karteNurFaellig = v),
                ),
            ],
          ),

          // Anzahl (nur Liste)
          if (!_karteAktiv)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} Betriebe',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ),

          // Liste bzw. Karte
          Expanded(
            child: _karteAktiv
                ? _buildKarte(statusFuer, aktiveRegionIds)
                : (filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _BetriebListItem(
                            betrieb: filtered[index],
                            onTap: () => context.push(
                              '/betriebe/${filtered[index].routeId}',
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/betriebe/neu'),
        tooltip: 'Neuer Betrieb',
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _statusPasst(String status) {
    switch (_statusFilter) {
      case 'operativ':
        return istBetriebOperativ(status);
      case 'alle':
        return true;
      default:
        return status == _statusFilter;
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'Keine Ergebnisse' : 'Noch keine Betriebe',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Erstelle deinen ersten Betrieb mit +',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  // ─── Karten-Ansicht ───

  Widget _buildKarte(
    FaelligkeitsStatus Function(BetriebLocal) statusFuer,
    Set<String> aktiveRegionIds,
  ) {
    final alle = ref.read(betriebeProvider);

    bool istFaellig(FaelligkeitsStatus s) =>
        s == FaelligkeitsStatus.ueberfaellig ||
        s == FaelligkeitsStatus.faellig ||
        s == FaelligkeitsStatus.baldFaellig;

    // Filter: Kunden + Region + Suche gemeinsam mit der Liste (Filter-Leiste
    // oben), "Nur fällige" ist karten-spezifisch.
    final query = _searchQuery.toLowerCase();
    final gefiltert = alle.where((b) {
      // Nur operative Betriebe (aktiv + Saisonpause). Inaktiv/geschlossen
      // erscheinen auf der Karte nicht.
      if (!istBetriebOperativ(b.status)) return false;
      if (_kundenFilter == 'meine' && !b.istMeinKunde) return false;
      if (_kundenFilter == 'fremde' && b.istMeinKunde) return false;
      if (aktiveRegionIds.isNotEmpty &&
          (b.regionId == null || !aktiveRegionIds.contains(b.regionId))) {
        return false;
      }
      if (_karteNurFaellig && !istFaellig(statusFuer(b))) return false;
      if (query.isNotEmpty &&
          !(b.name.toLowerCase().contains(query) ||
              (b.ort?.toLowerCase().contains(query) ?? false) ||
              (b.betriebNr?.toLowerCase().contains(query) ?? false))) {
        return false;
      }
      return true;
    }).toList();

    final mitKoord = gefiltert
        .where((b) => b.latitude != null && b.longitude != null)
        .map((b) => BetriebMarkerData(b, statusFuer(b)))
        .toList();
    final ohneKoord = gefiltert
        .where((b) => b.latitude == null || b.longitude == null)
        .toList();

    return Column(
      children: [
        Expanded(
          child: BetriebeMap(
            eintraege: mitKoord,
            onOeffnen: (b) => context.push('/betriebe/${b.routeId}'),
            onRoute: (b) => _oeffneRoute(b),
          ),
        ),
        if (ohneKoord.isNotEmpty)
          TextButton.icon(
            onPressed: () => _zeigeOhneStandort(ohneKoord),
            icon: const Icon(Icons.wrong_location_outlined, size: 18),
            label: Text('${ohneKoord.length} Betriebe ohne Standort'),
          ),
      ],
    );
  }

  void _zeigeOhneStandort(List<BetriebLocal> ohne) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Betriebe ohne Standort',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final b in ohne)
              ListTile(
                title: Text(b.name),
                subtitle: b.ort != null ? Text(b.ort!) : null,
                trailing: const Icon(Icons.edit_location_alt),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/betriebe/${b.routeId}/bearbeiten');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _oeffneRoute(BetriebLocal b) async {
    final url = googleMapsRouteUrl(
      latitude: b.latitude,
      longitude: b.longitude,
      adresse: [b.strasse, b.nr, b.plz, b.ort]
          .where((s) => s != null && s.isNotEmpty)
          .join(' '),
    );
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Adresse/Koordinaten für Route.')),
        );
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _BetriebListItem extends StatelessWidget {
  final BetriebLocal betrieb;
  final VoidCallback onTap;

  const _BetriebListItem({required this.betrieb, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _zapfSystemColor.withAlpha(25),
          child: Icon(Icons.store, color: _zapfSystemColor, size: 20),
        ),
        title: Text(
          betrieb.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _buildSubtitle(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!betrieb.isSynced)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
            if (betrieb.istBergkunde)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.terrain, size: 16, color: AppColors.info),
              ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget? _buildSubtitle() {
    if (betrieb.ort == null) return null;
    return Text(betrieb.ort!);
  }

  Color get _zapfSystemColor {
    final sys = betrieb.zapfsysteme.isNotEmpty
        ? betrieb.zapfsysteme.first.toLowerCase()
        : '';
    switch (sys) {
      case 'konventionell':
      case 'orion':
        return AppColors.success;
      case 'higenie':
        return AppColors.info;
      case 'david':
        return AppColors.textSecondary;
      case 'veranstaltungen':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
